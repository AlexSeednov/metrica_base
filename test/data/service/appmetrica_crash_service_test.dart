import 'dart:ui';

import 'package:application_base/core/service/logger_service.dart';
import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrica_base/data/service/appmetrica_crash_service.dart';

/// The platform answer of a successful call.
final ByteData? _success = const StandardMessageCodec().encodeMessage(<Object?>[
  null,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// The error environment as the SDK received it: key to the last value.
  final Map<String, String?> environment = {};

  setUp(() {
    environment.clear();
    messenger.allMessagesHandler = (channel, handler, message) {
      if (channel.endsWith('.putErrorEnvironmentValue')) {
        final List<Object?> arguments =
            const StandardMessageCodec().decodeMessage(message)
                as List<Object?>;
        environment[arguments[0]! as String] = arguments[1] as String?;
      }
      return Future.value(_success);
    };

    /// `prepare` rebinds the logger sinks and the global error handler
    final ErrorCallback? onError = PlatformDispatcher.instance.onError;
    addTearDown(() {
      PlatformDispatcher.instance.onError = onError;
      logInfoRemote = null;
      logErrorRemote = null;
      messenger.allMessagesHandler = null;
    });

    AppMetricaCrashService().prepare();
  });

  ///
  group('AppMetricaCrashService breadcrumbs', () {
    /// The lines right before a native crash explain it: a write held back
    /// by the rate limit must happen later, not never.
    testWidgets('a line held back by the rate limit is written later', (
      tester,
    ) async {
      logInfoRemote!(information: 'first');
      await tester.pump();
      check(environment['log_01']).isNotNull().endsWith('first');

      logInfoRemote!(information: 'second');
      await tester.pump();
      check(environment).not((it) => it.containsKey('log_02'));

      await tester.pump(const Duration(seconds: 5));
      check(environment['log_02']).isNotNull().endsWith('second');
    });

    /// The writes are asynchronous: a line logged between two of them used
    /// to break the iteration and cut the write short.
    testWidgets('a line logged during a write does not cut it short', (
      tester,
    ) async {
      logInfoRemote!(information: 'first');
      logInfoRemote!(information: 'second');

      /// An error forces a write of both lines; the third one arrives while
      /// the first of them is still on its way
      logErrorRemote!(error: 'failure');
      logInfoRemote!(information: 'third');
      await tester.pump();
      check(environment['log_02']).isNotNull().endsWith('second');

      await tester.pump(const Duration(seconds: 5));
      check(environment['log_03']).isNotNull().endsWith('third');
    });
  });
}
