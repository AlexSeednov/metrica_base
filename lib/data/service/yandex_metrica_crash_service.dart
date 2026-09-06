import 'dart:async';

import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:metrica_base/core/const/platform_environment.dart';
import 'package:metrica_base/core/utility/error_group_utility.dart';
import 'package:metrica_base/domain/entity/error_analytics_event.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';
import 'package:metrica_base/domain/service/crash_reporting_service.dart';

/// Error reports for the web — on top of the Yandex Metrica counter.
///
/// Metrica has no crash reporting of its own, so errors go out as the
/// service analytics event [ErrorAnalyticsEvent] — without stacks and the
/// journal of recent events, but with the same grouping as the mobile reports.
// Future(AlexSeednov): full crash reporting for the web (stacks, journal of
// events) is a separate system; wire it once one is chosen.
@Environment(PlatformEnvironment.web)
@LazySingleton(as: CrashReportingService)
final class YandexMetricaCrashService
    with LoggingMixin
    implements CrashReportingService {
  ///
  @visibleForTesting
  YandexMetricaCrashService(this._analyticsService);

  // MARK: Const

  /// Length cap of an error message: the parameters of an event are no place
  /// for the full text with a stack
  static const int _messageLimit = 200;

  /// Cap on the length of a group identifier — as in the mobile reports, so
  /// the same error groups the same way on every platform
  static const int _groupIdLimit = 100;

  /// How many errors per session go into analytics: a looping frame build
  /// error would otherwise spam the visit with hundreds of events
  static const int _reportsLimit = 30;

  ///
  @override
  final String logName = 'Yandex Metrica Crashes';

  // MARK: References

  /// Errors go through the shared analytics service: the queue before the
  /// counter activation and the guard against sending failures live in one
  /// place
  final AnalyticsService _analyticsService;

  // MARK: Data

  /// A report is in flight: a failure of the sending itself the logger would
  /// hand back here and loop the reports — nested calls are dropped
  bool _isReporting = false;

  /// How many errors went out this session
  int _reportsCount = 0;

  // MARK: Base functions

  ///
  @override
  void prepare() {
    /// The application logger hands handled errors over here. The journal of
    /// events ([logInfoRemote]) is not subscribed: Metrica has no error
    /// environment the mobile reports attach the journal to
    logErrorRemote = _logError;

    /// Framework errors on the web nobody intercepts (on mobile the AppMetrica
    /// SDK does on activation) — the report goes out on top of the regular
    /// handling, not instead of it
    final FlutterExceptionHandler? previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(
        _reportError(message: details.exceptionAsString(), isFatal: true),
      );
      previousOnError?.call(details);
    };

    /// Asynchronous errors outside the Flutter zone
    PlatformDispatcher.instance.onError = _onError;

    logNamedInfo(info: 'Prepared');
  }

  // MARK: Functions

  ///
  @override
  Future<void> setUser(String? userId) async {
    /// No separate binding needed: the error events belong to the visit,
    /// which is already bound to the user through [AnalyticsService.setUser]
  }

  /// A handled error from the application logger
  Future<void> _logError({required String error, StackTrace? stack}) =>
      _reportError(message: error, isFatal: false);

  /// An unhandled asynchronous error: counted as handled, otherwise Flutter
  /// would bring the application down instead of letting the report out
  bool _onError(Object error, StackTrace stack) {
    /// Returning `true` mutes the regular `Unhandled exception` print in the
    /// console, so in debug the error is duplicated into the log by hand.
    /// In debug only: outside it the logger would send the error a second
    /// time — as handled, on top of the unhandled report
    if (isDebug) logNamedError(error: 'Unhandled: $error', stack: stack);

    unawaited(_reportError(message: 'Unhandled: $error', isFatal: true));

    return true;
  }

  /// Send an error as the service analytics event
  Future<void> _reportError({
    required String message,
    required bool isFatal,
  }) async {
    if (_isReporting || _reportsCount >= _reportsLimit) return;
    _isReporting = true;
    _reportsCount++;

    try {
      await _analyticsService.logEvent(
        ErrorAnalyticsEvent(
          group: ErrorGroupUtility.groupId(message, limit: _groupIdLimit),
          message: message.length <= _messageLimit
              ? message
              : '${message.substring(0, _messageLimit - 1)}…',
          isFatal: isFatal,
        ),
      );
    } finally {
      _isReporting = false;
    }
  }
}
