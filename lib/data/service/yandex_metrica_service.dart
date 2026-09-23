import 'dart:async';

import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:injectable/injectable.dart';
import 'package:metrica_base/core/const/platform_environment.dart';
import 'package:metrica_base/data/service/yandex_metrica_bridge.dart'
    as metrica;
import 'package:metrica_base/data/utility/page_url_utility.dart';
import 'package:metrica_base/domain/entity/analytics_event_base.dart';
import 'package:metrica_base/domain/entity/analytics_purchase.dart';
import 'package:metrica_base/domain/entity/metrica_config.dart';
import 'package:metrica_base/domain/entity/screen_view_analytics_event.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';

/// Analytics through a Yandex Metrica counter, registered for
/// [PlatformEnvironment.web], where AppMetrica has no SDK.
///
/// Events go out as goals, screen views as page hits, purchases as
/// E-commerce records. A goal reaches the reports only when the Metrica
/// dashboard declares a JavaScript goal with the same identifier.
@Environment(PlatformEnvironment.web)
@LazySingleton(as: AnalyticsService)
final class YandexMetricaService with LoggingMixin implements AnalyticsService {
  ///
  @visibleForTesting
  YandexMetricaService();

  // MARK: Const

  /// How many reports wait for the counter to activate: the script loads over
  /// the network, and the first events of a launch must not be lost.
  static const int _pendingReportsLimit = 100;

  /// How long to wait for the counter script. A blocked load fails on its
  /// own; this only guards against a hung network.
  static const Duration _activationTimeout = Duration(seconds: 15);

  /// Profile flag "did a key action", for audience segmentation.
  static const String _keyActionFlag = 'did_key_action';

  ///
  @override
  final String logName = 'Yandex Metrica';

  // MARK: Data

  /// `0` until [init] hands a number over. Every report is gated by
  /// [_isActivated], which is only ever `true` with a real number.
  int _counterId = 0;

  /// Outcome of the activation; `null` while it is pending — the script is
  /// loading or the consent is not given yet.
  bool? _isActivated;

  /// Reports made before the activation, up to [_pendingReportsLimit].
  final List<void Function()> _pendingReports = [];

  /// Consent the activation is waiting for, if any.
  ValueListenable<bool>? _consent;

  // MARK: Base functions

  ///
  @override
  Future<void> init(MetricaConfig config) async {
    final int? counterId = config.yandexMetricaCounterId;
    if (counterId == null) {
      _isActivated = false;
      logNamedInfo(info: 'counter is not configured, skipped');
      return;
    }
    _counterId = counterId;

    /// No script before the consent, see [MetricaConfig.webConsent]; reports
    /// made meanwhile wait in [_pendingReports], so a visit that consents
    /// mid-session keeps its first events
    final ValueListenable<bool>? consent = config.webConsent;
    if (consent == null || consent.value) {
      unawaited(_activate());
      return;
    }

    _consent = consent;
    consent.addListener(_onConsentChanged);
  }

  /// Activates once, on the first `true`.
  void _onConsentChanged() {
    final ValueListenable<bool>? consent = _consent;
    if (consent == null || !consent.value) return;

    consent.removeListener(_onConsentChanged);
    _consent = null;
    unawaited(_activate());
  }

  ///
  Future<void> _activate() async {
    try {
      final bool isLoaded = await metrica
          .loadCounterScript(_counterId)
          .timeout(_activationTimeout, onTimeout: () => false);
      if (!isLoaded) {
        /// Ad blockers cut the counter off en masse: expected, not an
        /// application error
        _finishActivation(isActivated: false);
        logNamedInfo(info: 'script is blocked or unreachable, skipped');
        return;
      }

      metrica.activateCounter(_counterId);
      _finishActivation(isActivated: true);
      logNamedInfo(info: 'Activated');
    } catch (e) {
      _finishActivation(isActivated: false);
      logNamedError(error: 'Activation failed: $e');
    }
  }

  /// Sends the queued reports on success, drops them on failure.
  void _finishActivation({required bool isActivated}) {
    _isActivated = isActivated;
    if (isActivated) _pendingReports.forEach(_guard);
    _pendingReports.clear();
  }

  // MARK: Functions

  ///
  @override
  Future<void> setUser(String? userId) async {
    /// The counter cannot drop an identity: the current visit is already
    /// bound to the user, and the next visit without setUserID stays
    /// anonymous anyway
    if (userId == null) return;

    await _report(() => metrica.assignUserId(_counterId, userId));
  }

  ///
  @override
  Future<void> logEvent(AnalyticsEventBase event) async {
    /// A screen view goes out as a page hit, see [ScreenViewAnalyticsEvent];
    /// as a goal it would be noise
    if (event is ScreenViewAnalyticsEvent) {
      _reportScreenView(event);
      return;
    }

    await _report(() {
      metrica.reportGoal(_counterId, event.name, event.parameters);

      /// Metrica has no cumulative profile attributes: a key action sets the
      /// flag only
      if (event.keyActionCounter != null) _assignKeyAction();
    });
  }

  ///
  @override
  Future<void> reportCheckoutStarted(AnalyticsPurchase purchase) async {
    /// A free order is not commerce: zero orders would distort the average
    /// check and the conversion of the E-commerce reports
    if (purchase.isFree) return;

    /// Metrica's E-commerce has no "checkout started" step: the nearest one
    /// before a purchase is adding to the cart
    await _report(
      () => metrica.pushEcommerce({
        'ecommerce': {
          'currencyCode': purchase.currency,
          'add': {
            'products': [_product(purchase)],
          },
        },
      }),
    );
  }

  ///
  @override
  Future<void> reportPurchase(AnalyticsPurchase purchase) => _report(() {
    metrica.reportGoal(_counterId, 'purchase_success', {
      'product_id': purchase.productId,
      'product_name': purchase.productName,
      'amount': purchase.totalAmount,
      'currency': purchase.currency,
      'quantity': purchase.quantity,
      'is_free': purchase.isFree,
    });

    /// A free order stays out of E-commerce, see [reportCheckoutStarted]
    if (!purchase.isFree) {
      metrica.pushEcommerce({
        'ecommerce': {
          'currencyCode': purchase.currency,
          'purchase': {
            /// Metrica's E-commerce takes no custom order fields, so there is
            /// no room for the payment id: matching with the backend goes by
            /// the order id
            'actionField': {
              'id': purchase.orderId,
              'revenue': purchase.totalAmount,
            },
            'products': [_product(purchase)],
          },
        },
      });
    }

    /// Metrica has no cumulative profile attributes (the purchase count and
    /// amount AppMetrica keeps): only the key action flag
    _assignKeyAction();
  });

  ///
  @override
  Future<void> markKeyAction() => _report(_assignKeyAction);

  ///
  void _assignKeyAction() =>
      metrica.assignUserParameters(_counterId, {_keyActionFlag: true});

  /// The router updates the address bar after notifying the navigation
  /// observers, so the address is read after the frame — otherwise the hit
  /// would go out with the old URL.
  void _reportScreenView(ScreenViewAnalyticsEvent event) =>
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final String url = PageUrlUtility.pageUrl(metrica.currentPageUrl());
        unawaited(
          _report(
            () => metrica.reportPageView(
              _counterId,
              url: url,
              title: event.screenName,
              parameters: event.parameters,
            ),
          ),
        );
      });

  /// The single product of an order: there is no cart.
  Map<String, Object> _product(AnalyticsPurchase purchase) => {
    'id': purchase.productId.toString(),
    'name': purchase.productName,
    'category': purchase.category,
    'price': purchase.unitAmount,
    'quantity': purchase.quantity,
  };

  /// Sends [report] once the counter is active: queued while the activation
  /// is pending, dropped after it failed.
  Future<void> _report(void Function() report) async {
    switch (_isActivated) {
      case true:
        _guard(report);
      case null:
        if (_pendingReports.length < _pendingReportsLimit) {
          _pendingReports.add(report);
        }
      case false:
        break;
    }
  }

  /// Analytics must never affect the business flow: failures are only
  /// logged.
  void _guard(void Function() report) {
    try {
      report();
    } catch (e) {
      logNamedError(error: 'Report failed: $e');
    }
  }
}
