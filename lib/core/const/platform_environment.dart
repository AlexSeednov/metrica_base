import 'package:application_base/core/service/platform_service.dart';

/// DI environments that split the registrations by platform.
///
/// An implementation that exists on one platform only — AppMetrica in the
/// mobile SDKs, Yandex Metrica in the web counter — carries `@Environment`
/// with one of these names and is registered there alone. The environment is
/// picked once, on DI init: pass [current] to the application's
/// `getIt.init(environment: …)`.
abstract final class PlatformEnvironment {
  /// Everything but the web. Named after Android and iOS, where AppMetrica
  /// works; the desktop platforms land here too, and there the plugin has no
  /// implementation — every call fails and is logged, nothing throws.
  static const String mobile = 'mobile';

  ///
  static const String web = 'web';

  ///
  static String get current => isWeb ? web : mobile;
}
