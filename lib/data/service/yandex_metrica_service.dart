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

/// Analytics on top of a Yandex Metrica counter — for the web, where
/// AppMetrica has no SDK.
///
/// Events go out as goals of the counter (JavaScript goals with the same
/// identifiers are created in the Metrica dashboard for the events that
/// matter), screen views — as page hits, purchases — as E-commerce records.
@Environment(PlatformEnvironment.web)
@LazySingleton(as: AnalyticsService)
final class YandexMetricaService with LoggingMixin implements AnalyticsService {
  ///
  @visibleForTesting
  YandexMetricaService();

  // MARK: Const

  /// How many reports pile up before the counter activates: the script loads
  /// from the network, and the first events of the launch must not be lost
  static const int _pendingReportsLimit = 100;

  /// Wait limit for the counter script: a blocked load the browser aborts
  /// itself, the timeout only insures against a hung network
  static const Duration _activationTimeout = Duration(seconds: 15);

  /// Profile flag «did a key action» — for audience segmentation
  static const String _keyActionFlag = 'did_key_action';

  ///
  @override
  final String logName = 'Yandex Metrica';

  // MARK: Data

  /// Number of the counter; `0` until [init] hands one over. Every report is
  /// gated by [_isActivated], which is only ever `true` with a real number
  int _counterId = 0;

  /// Outcome of the counter activation; `null` — the script is still loading
  bool? _isActivated;

  /// Reports piled up before the activation
  final List<void Function()> _pendingReports = [];

  /// Consent gate the activation is waiting for, if any
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

    /// The counter sets cookies, so where a consent is required the script
    /// is not loaded until the user gives it. The gate may flip at once —
    /// a stored consent read on start-up — or later, from the banner; reports
    /// made before the activation pile up in [_pendingReports], so a visit
    /// that consents mid-session does not lose its first events
    final ValueListenable<bool>? consent = config.webConsent;
    if (consent == null || consent.value) {
      unawaited(_activate());
      return;
    }

    _consent = consent;
    consent.addListener(_onConsentChanged);
  }

  /// One-shot transition on consent: drop the subscription and activate
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
        /// Ad blockers cut the counter off en masse — an expected
        /// environment, not an application error
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

  /// Record the outcome of the activation and work off the queue
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
    /// A screen view is a page view of the SPA: hits give Metrica its
    /// standard content reports and the parsing of ad tags, a goal here would
    /// be noise
    if (event is ScreenViewAnalyticsEvent) {
      _reportScreenView(event);
      return;
    }

    await _report(() {
      metrica.reportGoal(_counterId, event.name, event.parameters);

      /// Cumulative profile attributes, as in AppMetrica, Metrica has none —
      /// a key action leaves only the flag
      if (event.keyActionCounter != null) _assignKeyAction();
    });
  }

  ///
  @override
  Future<void> reportCheckoutStarted(AnalyticsPurchase purchase) async {
    /// A free acquisition is no commerce: zero orders would distort the
    /// average check and the conversion of the E-commerce reports
    if (purchase.isFree) return;

    /// Metrica's E-commerce has no «checkout started» step of its own — the
    /// nearest funnel step before a purchase is adding to the cart
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

    /// A free acquisition stays out of E-commerce — see
    /// [reportCheckoutStarted]
    if (!purchase.isFree) {
      metrica.pushEcommerce({
        'ecommerce': {
          'currencyCode': purchase.currency,
          'purchase': {
            /// There is nowhere to put the payment identifier for matching
            /// against the backend — Metrica's E-commerce accepts no custom
            /// order fields, the matching stays by the order identifier
            'actionField': {
              'id': purchase.orderId,
              'revenue': purchase.totalAmount,
            },
            'products': [_product(purchase)],
          },
        },
      });
    }

    /// Cumulative profile attributes (count and amount of purchases), as in
    /// AppMetrica, Metrica has none — only the key action flag is left
    _assignKeyAction();
  });

  ///
  @override
  Future<void> markKeyAction() => _report(_assignKeyAction);

  /// The «did a key action» flag — for audience segmentation
  void _assignKeyAction() =>
      metrica.assignUserParameters(_counterId, {_keyActionFlag: true});

  /// The router updates the address bar after notifying the navigation
  /// observers, so the address is read after the frame — otherwise the hit
  /// would go out with the old URL
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

  /// Product of the order: there is no cart, a purchase is made straight
  /// from the product card
  Map<String, Object> _product(AnalyticsPurchase purchase) => {
    'id': purchase.productId.toString(),
    'name': purchase.productName,
    'category': purchase.category,
    'price': purchase.unitAmount,
    'quantity': purchase.quantity,
  };

  /// Run a report with the state of the counter in mind: before the
  /// activation — into the queue, after a failed activation — silently drop
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

  /// Analytics must never affect the business flow — failures are only
  /// logged
  void _guard(void Function() report) {
    try {
      report();
    } catch (e) {
      logNamedError(error: 'Report failed: $e');
    }
  }
}
