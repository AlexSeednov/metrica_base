import 'package:meta/meta.dart';
import 'package:metrica_base/domain/entity/analytics_event_base.dart';
import 'package:metrica_base/domain/entity/analytics_purchase.dart';
import 'package:metrica_base/domain/entity/metrica_config.dart';

/// Sending usage events to the external analytics system.
///
/// Bound per platform by the package's injectable module: AppMetrica in the
/// mobile environment, the Yandex Metrica counter on the web. An application
/// depends on this contract alone and hands a fake to its tests.
abstract interface class AnalyticsService {
  /// SDK activation at the application launch, with the keys of [config].
  ///
  /// Called through `MetricaBase.prepare`; never throws — a broken analytics
  /// setup must not block the launch.
  Future<void> init(MetricaConfig config);

  /// Attach the user's identity (or drop it with [userId] == null).
  ///
  /// Needed for counting unique users and for per-user breakdowns of the
  /// metrics.
  @awaitNotRequired
  Future<void> setUser(String? userId);

  /// Send an event of the application's registry.
  @awaitNotRequired
  Future<void> logEvent(AnalyticsEventBase event);

  /// Record the start of a checkout for the E-commerce reports.
  ///
  /// Paired with [reportPurchase]: together they make the «checkout →
  /// payment» funnel.
  @awaitNotRequired
  Future<void> reportCheckoutStarted(AnalyticsPurchase purchase);

  /// Record a purchase: the event, the E-commerce order and the cumulative
  /// profile attributes (count and amount of purchases — separately with and
  /// without the free ones).
  ///
  /// Only for purchases through the application's own billing. Purchases
  /// through the stores (IAP) are counted differently — see the
  /// implementations.
  @awaitNotRequired
  Future<void> reportPurchase(AnalyticsPurchase purchase);

  /// Mark that the user did one of the platform's key actions.
  ///
  /// For an action that is an event of its own, prefer declaring
  /// [AnalyticsEventBase.keyActionCounter] on the event instead.
  @awaitNotRequired
  Future<void> markKeyAction();
}
