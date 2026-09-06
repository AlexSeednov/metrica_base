import 'package:injectable/injectable.dart';

/// Injectable micro-package module.
///
/// build_runner collects every `@injectable` service of the package into
/// `service_locator_metrica.module.dart` (the `MetricaBasePackageModule`
/// class). Consumers wire it via `externalPackageModulesBefore` in their
/// `@InjectableInit` and pass `PlatformEnvironment.current` as the environment
/// of `getIt.init` — the services are registered per platform, so without an
/// environment none of them lands in getIt.
@InjectableInit.microPackage()
void initMetricaBasePackage() {}
