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

/// Error reports through the Yandex Metrica counter, registered for
/// [PlatformEnvironment.web].
///
/// Metrica has no crash reporting, so errors go out as [ErrorAnalyticsEvent]:
/// no stacks and no breadcrumbs, but the same grouping as on mobile.
// Future(AlexSeednov): full crash reporting for the web (stacks, breadcrumbs)
// is a separate system; wire it once one is chosen.
@Environment(PlatformEnvironment.web)
@LazySingleton(as: CrashReportingService)
final class YandexMetricaCrashService
    with LoggingMixin
    implements CrashReportingService {
  ///
  @visibleForTesting
  YandexMetricaCrashService(this._analyticsService);

  // MARK: Const

  /// Length cap of a message: event parameters are no place for a full text
  /// with a stack.
  static const int _messageLimit = 200;

  /// As on mobile, so the same error groups the same way on every platform.
  static const int _groupIdLimit = 100;

  /// Errors sent per page load at most: an error thrown on every frame would
  /// otherwise flood the visit with hundreds of events.
  static const int _reportsLimit = 30;

  ///
  @override
  final String logName = 'Yandex Metrica Crashes';

  // MARK: References

  /// Errors go through the shared analytics service, so the queue before the
  /// activation and the guard against sending failures live in one place.
  final AnalyticsService _analyticsService;

  // MARK: Data

  /// Set while a report is being sent. A failure of the sending goes to the
  /// logger, which hands it back here: dropping nested calls breaks the loop.
  bool _isReporting = false;

  ///
  int _reportsCount = 0;

  // MARK: Base functions

  ///
  @override
  void prepare() {
    /// The errors of the application logger only: Metrica has no error
    /// environment to keep the breadcrumbs of [logInfoRemote] in
    logErrorRemote = _logError;

    /// Nothing intercepts framework errors on the web (on mobile the SDK
    /// does), so they are hooked here — on top of the regular handler, not
    /// instead of it
    final FlutterExceptionHandler? previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(
        _reportError(message: details.exceptionAsString(), isFatal: true),
      );
      previousOnError?.call(details);
    };

    /// Asynchronous errors outside the framework
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

  /// A handled error from the application logger.
  Future<void> _logError({required String error, StackTrace? stack}) =>
      _reportError(message: error, isFatal: false);

  /// An unhandled asynchronous error; `true` marks it handled.
  bool _onError(Object error, StackTrace stack) {
    /// Returning `true` mutes the regular `Unhandled exception` print in the
    /// console, so in debug the error is duplicated into the log by hand.
    /// In debug only: outside it the logger would send the error a second
    /// time — as handled, on top of the unhandled report
    if (isDebug) logNamedError(error: 'Unhandled: $error', stack: stack);

    unawaited(_reportError(message: 'Unhandled: $error', isFatal: true));

    return true;
  }

  ///
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
