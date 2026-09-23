import 'package:injectable/injectable.dart';

/// Injectable micro-package module.
///
/// build_runner collects the package's services into
/// `service_locator_metrica.module.dart` (`MetricaBasePackageModule`), and an
/// application wires it through `externalPackageModulesBefore` of its
/// `@InjectableInit`. Pass `PlatformEnvironment.current` as the environment of
/// `getIt.init`: every service is registered for one platform, and without an
/// environment none of them lands in getIt.
@InjectableInit.microPackage()
void initMetricaBasePackage() {}
