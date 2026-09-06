import 'package:meta/meta.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';

/// Sending application crashes and errors to the external reporting system.
///
/// Bound per platform by the package's injectable module: the crash
/// reporting of the AppMetrica SDK on mobile, error events of the Yandex
/// Metrica counter on the web.
abstract interface class CrashReportingService {
  /// Hook the reporting system onto the global error handlers and the
  /// application logger.
  ///
  /// Called through `MetricaBase.prepare`, **after** [AnalyticsService.init]:
  /// the handlers attach to an already activated SDK, otherwise the first
  /// reports go nowhere.
  void prepare();

  /// Attach the reports to the user (or detach with [userId] == null).
  ///
  /// Separate from [AnalyticsService.setUser]: a native crash never passes
  /// through Dart, so the identity has to sit in the report beforehand rather
  /// than be added at send time.
  @awaitNotRequired
  Future<void> setUser(String? userId);
}
