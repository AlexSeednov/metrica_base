import 'package:meta/meta.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';

/// Crash and error reporting.
///
/// Bound per platform by the package's injectable module: AppMetrica's crash
/// reporting on mobile, error events of the Yandex Metrica counter on the
/// web.
abstract interface class CrashReportingService {
  /// Hooks the reporting onto the global error handlers and the application
  /// logger.
  ///
  /// Called by `MetricaBase.prepare`, **after** [AnalyticsService.init]: the
  /// handlers need an activated SDK, or the first reports go nowhere.
  void prepare();

  /// Attaches the reports to the user; `null` detaches them.
  ///
  /// Separate from [AnalyticsService.setUser]: a native crash never passes
  /// through Dart, so the identity has to be in place beforehand rather than
  /// added at send time.
  @awaitNotRequired
  Future<void> setUser(String? userId);
}
