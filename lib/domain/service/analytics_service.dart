import 'package:meta/meta.dart';
import 'package:metrica_base/domain/entity/analytics_event_base.dart';
import 'package:metrica_base/domain/entity/analytics_purchase.dart';
import 'package:metrica_base/domain/entity/metrica_config.dart';

/// Usage analytics.
///
/// Bound per platform by the package's injectable module: AppMetrica on
/// mobile, the Yandex Metrica counter on the web. An application depends on
/// this contract alone, and its tests take a fake.
abstract interface class AnalyticsService {
  /// Activates the SDK with the keys of [config].
  ///
  /// Called by `MetricaBase.prepare`; never throws — a broken analytics setup
  /// must not block the launch.
  Future<void> init(MetricaConfig config);

  /// Attaches the user's identity; `null` drops it where the platform can.
  ///
  /// Needed to count unique users and to break the metrics down per user.
  @awaitNotRequired
  Future<void> setUser(String? userId);

  /// Sends an event of the application's registry.
  @awaitNotRequired
  Future<void> logEvent(AnalyticsEventBase event);

  /// Records the start of a checkout for the E-commerce reports; a free order
  /// stays out of them.
  ///
  /// Paired with [reportPurchase]: together they make the "checkout →
  /// payment" funnel.
  @awaitNotRequired
  Future<void> reportCheckoutStarted(AnalyticsPurchase purchase);

  /// Records a purchase: the `purchase_success` event, the E-commerce order
  /// (paid ones only), the key action flag and, on mobile, the cumulative
  /// profile attributes — count and amount, with and without the free
  /// purchases.
  ///
  /// Only for purchases through the application's own billing: store
  /// purchases (IAP) are counted differently, see the implementations.
  @awaitNotRequired
  Future<void> reportPurchase(AnalyticsPurchase purchase);

  /// Marks that the user did one of the platform's key actions.
  ///
  /// For an action that is an event of its own, prefer declaring
  /// [AnalyticsEventBase.keyActionCounter] on the event instead.
  @awaitNotRequired
  Future<void> markKeyAction();
}
