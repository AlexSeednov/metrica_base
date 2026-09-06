// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:metrica_base/data/service/appmetrica_crash_service.dart'
    as _i956;
import 'package:metrica_base/data/service/appmetrica_service.dart' as _i90;
import 'package:metrica_base/data/service/yandex_metrica_crash_service.dart'
    as _i534;
import 'package:metrica_base/data/service/yandex_metrica_service.dart' as _i893;
import 'package:metrica_base/domain/service/analytics_service.dart' as _i326;
import 'package:metrica_base/domain/service/crash_reporting_service.dart'
    as _i542;

const String _mobile = 'mobile';
const String _web = 'web';

class MetricaBasePackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i542.CrashReportingService>(
      () => _i956.AppMetricaCrashService(),
      registerFor: {_mobile},
    );
    gh.lazySingleton<_i326.AnalyticsService>(
      () => _i90.AppMetricaService(),
      registerFor: {_mobile},
    );
    gh.lazySingleton<_i326.AnalyticsService>(
      () => _i893.YandexMetricaService(),
      registerFor: {_web},
    );
    gh.lazySingleton<_i542.CrashReportingService>(
      () => _i534.YandexMetricaCrashService(gh<_i326.AnalyticsService>()),
      registerFor: {_web},
    );
  }
}
