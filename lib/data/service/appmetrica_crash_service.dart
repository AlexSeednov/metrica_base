import 'dart:async';
import 'dart:collection';

import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:metrica_base/core/const/platform_environment.dart';
import 'package:metrica_base/core/utility/error_group_utility.dart';
import 'package:metrica_base/domain/service/crash_reporting_service.dart';

/// Crash and error reports on top of Yandex AppMetrica — mobile platforms
/// only; the web has reports of its own, see the registration under
/// [PlatformEnvironment.web].
///
/// Native crashes and unhandled Flutter errors the SDK intercepts itself on
/// activation, so what is left here is what it cannot reach: asynchronous
/// errors outside the Flutter zone, errors from the application logger, and
/// the journal of recent events.
@Environment(PlatformEnvironment.mobile)
@LazySingleton(as: CrashReportingService)
final class AppMetricaCrashService
    with LoggingMixin
    implements CrashReportingService {
  ///
  @visibleForTesting
  AppMetricaCrashService();

  // MARK: Const

  /// How many recent journal messages are attached to a report.
  ///
  /// Every message takes an environment pair of its own, and AppMetrica
  /// allows no more than 30 pairs per report — minus the user identity pair
  /// and a small reserve.
  static const int _breadcrumbsLimit = 25;

  /// Journal key prefix: a zero-padded number keeps the chronological order
  /// under the alphabetical key sorting of the dashboard
  static const String _breadcrumbKeyPrefix = 'log_';

  /// Error environment key of the user identity
  static const String _userKey = 'user_id';

  /// Length cap of one journal entry: the total environment budget of
  /// AppMetrica is 4500 characters for keys and values together, and a pair
  /// over the budget is silently dropped by the service as a whole
  static const int _crumbLimit = 160;

  /// AppMetrica's cap on the length of a group identifier
  static const int _groupIdLimit = 100;

  /// How often the journal is pushed into the error environment.
  ///
  /// A native crash never passes through Dart, so the environment is kept
  /// fresh in advance — but every journal entry would mean a platform call,
  /// hence the rate limit.
  static const Duration _flushInterval = Duration(seconds: 5);

  ///
  @override
  final String logName = 'AppMetrica Crashes';

  // MARK: Data

  /// Journal of recent events: the tail is dropped as it fills up
  final Queue<String> _breadcrumbs = Queue<String>();

  /// Moment the journal last went into the error environment
  DateTime? _lastFlush;

  // MARK: Base functions

  ///
  @override
  void prepare() {
    /// The application logger hands over everything it writes to the console
    logInfoRemote = _logInfo;
    logErrorRemote = _logError;

    /// Asynchronous errors outside the Flutter zone are the only thing the
    /// SDK does not intercept itself: `FlutterError.onError` it takes over on
    /// activation
    PlatformDispatcher.instance.onError = _onError;

    logNamedInfo(info: 'Prepared');
  }

  // MARK: Functions

  ///
  @override
  Future<void> setUser(String? userId) =>
      _guard(() => AppMetrica.putErrorEnvironmentValue(_userKey, userId));

  /// Journal entry: goes out not at once but with the nearest report
  void _logInfo({required String information}) {
    /// The head of an entry is worth more than its tail: the time and the
    /// gist of the event come first
    final String crumb = '${_formatTime(DateTime.timestamp())} - $information';
    _breadcrumbs.addLast(
      crumb.length <= _crumbLimit
          ? crumb
          : '${crumb.substring(0, _crumbLimit - 1)}…',
    );
    if (_breadcrumbs.length > _breadcrumbsLimit) _breadcrumbs.removeFirst();

    _flushEnvironment();
  }

  /// A handled error from the application logger
  Future<void> _logError({required String error, StackTrace? stack}) async {
    _flushEnvironment(isForced: true);

    /// Without an explicit group AppMetrica glues errors by their stack, and
    /// every logger call has the same one — the whole diagnostics of the
    /// application would end up in a single record
    await _guard(
      () => AppMetrica.reportErrorWithGroup(
        _groupId(error),
        errorDescription: AppMetricaErrorDescription(
          stack ?? StackTrace.current,
          message: error,
        ),
        message: error,
      ),
    );
  }

  /// An unhandled asynchronous error: counted as handled, otherwise Flutter
  /// would bring the application down instead of letting the report out
  bool _onError(Object error, StackTrace stack) {
    /// Returning `true` mutes the regular `Unhandled exception` print in the
    /// console, so in debug the error is duplicated into the log by hand.
    /// In debug only: outside it the logger would send the error to
    /// AppMetrica a second time — as handled, on top of the unhandled report
    if (isDebug) logNamedError(error: 'Unhandled: $error', stack: stack);

    _flushEnvironment(isForced: true);

    unawaited(
      _guard(
        () => AppMetrica.reportUnhandledException(
          AppMetricaErrorDescription.fromObjectAndStackTrace(error, stack),
        ),
      ),
    );

    return true;
  }

  /// A failure of the sending itself cannot go to the logger: the logger
  /// hands errors back here, and an inactive SDK would turn into an endless
  /// loop of reports
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (isDebug) logNamedError(error: '$logName report failed: $e');
    }
  }

  /// Push of the journal into the error environment
  void _flushEnvironment({bool isForced = false}) {
    final DateTime now = DateTime.timestamp();
    final DateTime? last = _lastFlush;
    if (!isForced && last != null && now.difference(last) < _flushInterval) {
      return;
    }
    _lastFlush = now;

    /// Every entry is a pair of its own: as one text the dashboard shows the
    /// journal in a single line, collapsing the line breaks
    unawaited(
      _guard(() async {
        int index = 0;
        for (final String crumb in _breadcrumbs) {
          index++;
          await AppMetrica.putErrorEnvironmentValue(
            '$_breadcrumbKeyPrefix${index.toString().padLeft(2, '0')}',
            crumb,
          );
        }
      }),
    );
  }

  /// Group identifier — the grouping shared by every platform
  String _groupId(String error) =>
      ErrorGroupUtility.groupId(error, limit: _groupIdLimit);

  /// Time stamp of a journal entry, `HH:mm:ss`
  static String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
