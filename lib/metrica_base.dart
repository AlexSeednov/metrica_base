import 'package:application_base/core/service/service_locator.dart';
import 'package:metrica_base/domain/entity/metrica_config.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';
import 'package:metrica_base/domain/service/crash_reporting_service.dart';

/// Start-up of the package: analytics and crash reporting of the platform the
/// application runs on.
abstract final class MetricaBase {
  /// Activates the analytics SDK of the platform with the keys of [config],
  /// then hooks crash reporting onto the global error handlers and the
  /// application logger.
  ///
  /// Call right after the application's `getIt.init()`: the services are
  /// registered by the injectable module `MetricaBasePackageModule`, wired
  /// through `externalPackageModulesBefore` of the application's
  /// `@InjectableInit` with `PlatformEnvironment.current` as the environment.
  /// The sooner the better: sessions are counted from here, and whatever
  /// starts later already has a reporter.
  ///
  /// Nothing here throws: a broken analytics setup degrades the application
  /// instead of blocking its launch.
  static Future<void> prepare(MetricaConfig config) async {
    await getIt<AnalyticsService>().init(config);

    /// Strictly after the analytics: the handlers need an activated SDK, or
    /// the first reports go nowhere
    getIt<CrashReportingService>().prepare();
  }
}
