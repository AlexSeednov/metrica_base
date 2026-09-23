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

/// Crash and error reports through Yandex AppMetrica, registered for
/// [PlatformEnvironment.mobile].
///
/// The SDK intercepts native crashes and Flutter framework errors itself on
/// activation. Left for this service is what it cannot reach: asynchronous
/// errors outside the framework, the errors of the application logger, and
/// the breadcrumbs — the recent log lines.
@Environment(PlatformEnvironment.mobile)
@LazySingleton(as: CrashReportingService)
final class AppMetricaCrashService
    with LoggingMixin
    implements CrashReportingService {
  ///
  @visibleForTesting
  AppMetricaCrashService();

  // MARK: Const

  /// How many breadcrumbs a report carries.
  ///
  /// Each takes an error environment pair of its own, and AppMetrica allows
  /// 30 pairs per report: minus the user identity pair and a small reserve.
  static const int _breadcrumbsLimit = 25;

  /// A breadcrumb key is this prefix and a zero-padded number, which keeps the
  /// keys chronological under the dashboard's alphabetical sorting.
  static const String _breadcrumbKeyPrefix = 'log_';

  /// Error environment key of the user identity.
  static const String _userKey = 'user_id';

  /// Length cap of a breadcrumb. The error environment holds 4500 characters
  /// of keys and values in total and silently drops a pair that overflows
  /// it: [_breadcrumbsLimit] full breadcrumbs with their keys stay under it,
  /// with room left for the user id.
  static const int _crumbLimit = 160;

  /// AppMetrica's cap on the length of a group identifier.
  static const int _groupIdLimit = 100;

  /// How often at most the breadcrumbs are written into the error
  /// environment.
  ///
  /// A native crash never passes through Dart, so the environment is kept
  /// current in advance; writing on every log line would mean platform calls
  /// on every log line, hence the rate limit.
  static const Duration _flushInterval = Duration(seconds: 5);

  ///
  @override
  final String logName = 'AppMetrica Crashes';

  // MARK: Data

  /// Oldest first; the oldest drops out when the queue is full.
  final Queue<String> _breadcrumbs = Queue<String>();

  ///
  DateTime? _lastFlush;

  /// A write the rate limit held back, due at the end of the interval.
  Timer? _deferredFlush;

  // MARK: Base functions

  ///
  @override
  void prepare() {
    /// The application logger hands over what it writes, outside debug
    logInfoRemote = _logInfo;
    logErrorRemote = _logError;

    /// The SDK takes over `FlutterError.onError` on activation; asynchronous
    /// errors outside the framework are the one thing it leaves
    PlatformDispatcher.instance.onError = _onError;

    logNamedInfo(info: 'Prepared');
  }

  // MARK: Functions

  ///
  @override
  Future<void> setUser(String? userId) =>
      _guard(() => AppMetrica.putErrorEnvironmentValue(_userKey, userId));

  /// A breadcrumb: stored now, sent with the next report.
  void _logInfo({required String information}) {
    /// Cut from the end: the time and the gist come first
    final String crumb = '${_formatTime(DateTime.timestamp())} - $information';
    _breadcrumbs.addLast(
      crumb.length <= _crumbLimit
          ? crumb
          : '${crumb.substring(0, _crumbLimit - 1)}…',
    );
    if (_breadcrumbs.length > _breadcrumbsLimit) _breadcrumbs.removeFirst();

    _flushEnvironment();
  }

  /// A handled error from the application logger.
  Future<void> _logError({required String error, StackTrace? stack}) async {
    _flushEnvironment(isForced: true);

    /// Without an explicit group AppMetrica groups by stack, and every logger
    /// call has the same one: all the application's errors would land in one
    /// group
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

  /// An unhandled asynchronous error; `true` marks it handled.
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

  /// A failure of the sending itself stays out of the logger: the logger would
  /// hand it back here, and an inactive SDK would loop the reports. Debug is
  /// the exception — there the logger hands nothing over.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (isDebug) logNamedError(error: 'Report failed: $e');
    }
  }

  /// Writes the breadcrumbs into the error environment, at most once per
  /// [_flushInterval] unless [isForced].
  void _flushEnvironment({bool isForced = false}) {
    final DateTime now = DateTime.timestamp();
    final DateTime? last = _lastFlush;
    if (!isForced && last != null) {
      final Duration wait = _flushInterval - now.difference(last);

      /// Deferred, not dropped: the lines right before a native crash are the
      /// ones that explain it, and they are the ones a skipped write loses
      if (wait > Duration.zero) {
        _deferredFlush ??= Timer(wait, () {
          _deferredFlush = null;
          _flushEnvironment(isForced: true);
        });
        return;
      }
    }
    _deferredFlush?.cancel();
    _deferredFlush = null;
    _lastFlush = now;

    /// A copy: the writes are asynchronous, and a line logged between two of
    /// them would break the iteration over the live queue
    final List<String> crumbs = _breadcrumbs.toList();

    /// A pair per breadcrumb: as one text the dashboard would show them in a
    /// single line, the line breaks collapsed
    unawaited(
      _guard(() async {
        int index = 0;
        for (final String crumb in crumbs) {
          index++;
          await AppMetrica.putErrorEnvironmentValue(
            '$_breadcrumbKeyPrefix${index.toString().padLeft(2, '0')}',
            crumb,
          );
        }
      }),
    );
  }

  /// The grouping every platform shares.
  String _groupId(String error) =>
      ErrorGroupUtility.groupId(error, limit: _groupIdLimit);

  /// `HH:mm:ss` of a breadcrumb.
  static String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
