import 'package:application_base/core/service/platform_service.dart';

/// DI environments that split registrations by the kind of platform.
///
/// An implementation that exists on one platform only — AppMetrica lives in
/// the mobile SDKs, Yandex Metrica in the web counter — is marked with
/// `@Environment` under one of these names and gets registered in its own
/// environment alone. The environment is chosen once, when DI is initialized:
/// pass [current] to `getIt.init(environment: …)` of the application.
abstract final class PlatformEnvironment {
  /// Everything but the web. Named after Android and iOS, where AppMetrica
  /// works; the desktop platforms land here too, and there the plugin has no
  /// implementation — every call fails and is logged, nothing throws.
  static const String mobile = 'mobile';

  /// Web
  static const String web = 'web';

  /// The environment of the platform the application is running on.
  static String get current => isWeb ? web : mobile;
}
