import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:decimal/decimal.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:metrica_base/core/const/platform_environment.dart';
import 'package:metrica_base/domain/entity/analytics_event_base.dart';
import 'package:metrica_base/domain/entity/analytics_purchase.dart';
import 'package:metrica_base/domain/entity/metrica_config.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';

/// Analytics through Yandex AppMetrica, registered for
/// [PlatformEnvironment.mobile]; the web has a counter of its own.
@Environment(PlatformEnvironment.mobile)
@LazySingleton(as: AnalyticsService)
final class AppMetricaService with LoggingMixin implements AnalyticsService {
  ///
  @visibleForTesting
  AppMetricaService();

  // MARK: Const

  /// Amounts arrive as doubles: without rounding, Decimal would carry junk
  /// like 1499.9999999999998.
  static const int _amountFractionDigits = 2;

  /// Profile flag "did a key action", for audience segmentation.
  static const String _keyActionFlag = 'did_key_action';

  ///
  @override
  final String logName = 'AppMetrica';

  // MARK: Data

  /// Nothing reaches the SDK before a successful activation: without a key
  /// or after a failed activation analytics stays off, with the reason
  /// logged once by [init] instead of a failed call per report.
  bool _isActivated = false;

  // MARK: Base functions

  ///
  @override
  Future<void> init(MetricaConfig config) async {
    final String? apiKey = config.appMetricaApiKey;
    if (apiKey == null) {
      logNamedInfo(info: 'API key is not configured, skipped');
      return;
    }

    try {
      await AppMetrica.activate(
        AppMetricaConfig(
          apiKey,
          advIdentifiersTracking: config.advIdentifiersTracking,
          locationTracking: config.locationTracking,
          maxReportsInDatabaseCount: config.maxReportsInDatabaseCount,
          sessionTimeout: config.sessionTimeoutSeconds,
        ),
      );
      _isActivated = true;
      logNamedInfo(info: 'Activated');
    } catch (e) {
      logNamedError(error: 'Activation failed: $e');
    }
  }

  // MARK: Functions

  ///
  @override
  Future<void> setUser(String? userId) =>
      _guard(() => AppMetrica.setUserProfileID(userId));

  ///
  @override
  Future<void> logEvent(AnalyticsEventBase event) => _guard(() async {
    await AppMetrica.reportEventWithMap(event.name, event.parameters);

    /// A key action doubles as a cumulative profile attribute, so the
    /// audience can be segmented by how far a user has actually come
    final String? counter = event.keyActionCounter;
    if (counter == null) return;

    await AppMetrica.reportUserProfile(
      AppMetricaUserProfile([
        AppMetricaCounterAttribute.withDelta(counter, 1),
        AppMetricaBooleanAttribute.withValue(_keyActionFlag, true),
      ]),
    );
  });

  ///
  @override
  Future<void> reportCheckoutStarted(AnalyticsPurchase purchase) =>
      _guard(() async {
        /// A free order is not commerce: zero orders would distort the
        /// average check and the conversion of the E-commerce reports. The
        /// purchase event and the profile attributes still count it
        if (purchase.isFree) return;

        await AppMetrica.reportECommerce(
          AppMetricaECommerce.beginCheckoutEvent(_order(purchase)),
        );
      });

  ///
  @override
  Future<void> reportPurchase(AnalyticsPurchase purchase) => _guard(() async {
    final double amount = purchase.totalAmount;

    await AppMetrica.reportEventWithMap('purchase_success', {
      'product_id': purchase.productId,
      'product_name': purchase.productName,
      'amount': amount,
      'currency': purchase.currency,
      'quantity': purchase.quantity,
      'is_free': purchase.isFree,
    });

    /// An E-commerce order rather than Revenue: the payment goes through the
    /// application's own billing, while AppMetrica expects Revenue from the
    /// stores and validates it by the receipt
    // Future(AlexSeednov): once In-App Purchase is wired, send digital content
    // purchases through AppMetrica.reportRevenue(AppMetricaRevenue(...)) with
    // the store receipt (AppMetricaReceipt) — E-commerce does not fit those
    if (!purchase.isFree) {
      await AppMetrica.reportECommerce(
        AppMetricaECommerce.purchaseEvent(_order(purchase)),
      );
    }

    /// Cumulative profile attributes: count and amount of the purchases, over
    /// all of them and over the paid ones alone
    await AppMetrica.reportUserProfile(
      AppMetricaUserProfile([
        AppMetricaCounterAttribute.withDelta('purchases_count_total', 1),
        AppMetricaCounterAttribute.withDelta('purchases_amount_total', amount),
        if (!purchase.isFree)
          AppMetricaCounterAttribute.withDelta('purchases_count_paid', 1),
        if (!purchase.isFree)
          AppMetricaCounterAttribute.withDelta('purchases_amount_paid', amount),
      ]),
    );

    await _reportKeyAction();
  });

  ///
  @override
  Future<void> markKeyAction() => _guard(_reportKeyAction);

  /// A single-product order: there is no cart.
  AppMetricaECommerceOrder _order(AnalyticsPurchase purchase) =>
      AppMetricaECommerceOrder(
        identifier: purchase.orderId,
        items: [
          AppMetricaECommerceCartItem(
            product: AppMetricaECommerceProduct(
              sku: purchase.productId.toString(),
              name: purchase.productName,
              categoriesPath: [purchase.category],
              actualPrice: _price(purchase.unitAmount, purchase.currency),
            ),
            quantity: Decimal.fromInt(purchase.quantity),
            revenue: _price(purchase.totalAmount, purchase.currency),
          ),
        ],

        /// For matching the order against the payment on the backend
        payload: {'payment_id': ?purchase.paymentId?.toString()},
      );

  ///
  AppMetricaECommercePrice _price(double amount, String currency) =>
      AppMetricaECommercePrice(
        fiat: AppMetricaECommerceAmount(
          amount: Decimal.parse(amount.toStringAsFixed(_amountFractionDigits)),
          currency: currency,
        ),
      );

  ///
  Future<void> _reportKeyAction() => AppMetrica.reportUserProfile(
    AppMetricaUserProfile([
      AppMetricaBooleanAttribute.withValue(_keyActionFlag, true),
    ]),
  );

  /// Analytics must never affect the business flow: failures are only
  /// logged.
  Future<void> _guard(Future<void> Function() action) async {
    if (!_isActivated) return;

    try {
      await action();
    } catch (e) {
      logNamedError(error: 'Report failed: $e');
    }
  }
}
