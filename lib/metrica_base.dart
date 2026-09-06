import 'package:application_base/core/service/service_locator.dart';
import 'package:metrica_base/domain/entity/metrica_config.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';
import 'package:metrica_base/domain/service/crash_reporting_service.dart';

/// Entry point of the package's start-up: analytics and crash reporting of
/// the platform the application runs on.
abstract final class MetricaBase {
  /// Post-DI start-up: activates the analytics SDK of the platform with the
  /// keys of [config] and hooks crash reporting onto the global error
  /// handlers and the application logger.
  ///
  /// The services are registered by the injectable module
  /// `MetricaBasePackageModule` (wired via `externalPackageModulesBefore` in
  /// the consumer's `@InjectableInit`, with `PlatformEnvironment.current` as
  /// the environment), so this method must be called AFTER the consumer's
  /// `getIt.init()` — and as early as possible after it: sessions are counted
  /// from here, and everything that starts later already has a reporter to
  /// land in.
  ///
  /// Nothing here throws: a broken analytics setup degrades the application
  /// instead of blocking its launch.
  static Future<void> prepare(MetricaConfig config) async {
    await getIt<AnalyticsService>().init(config);

    /// Strictly after the analytics: the handlers attach to an already
    /// activated SDK, otherwise the first reports go nowhere
    getIt<CrashReportingService>().prepare();
  }
}
