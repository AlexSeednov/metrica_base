import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrica_base/data/service/appmetrica_service.dart';
import 'package:metrica_base/domain/entity/analytics_event_base.dart';
import 'package:metrica_base/domain/entity/analytics_purchase.dart';
import 'package:metrica_base/domain/entity/metrica_config.dart';

/// An event with nothing but a name.
final class _Event extends AnalyticsEventBase {
  ///
  const _Event();

  ///
  @override
  String get name => 'plain';
}

///
const AnalyticsPurchase _purchase = AnalyticsPurchase(
  orderId: 'order',
  productId: 1,
  productName: 'Product',
  category: 'course',
  totalAmount: 100,
  quantity: 1,
  isFree: false,
  currency: 'RUB',
);

/// The platform answer of a successful call.
final ByteData? _success = const StandardMessageCodec().encodeMessage(<Object?>[
  null,
]);

/// The platform answer of a failed call.
final ByteData? _failure = const StandardMessageCodec().encodeMessage(<Object?>[
  'error',
  'activation failed',
  null,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Methods called on the plugin, in order.
  final List<String> calls = [];

  /// Whether the SDK accepts the activation.
  bool isActivationAccepted = true;

  setUp(() {
    calls.clear();
    isActivationAccepted = true;

    /// The plugin installs its own framework error handler on activation
    final FlutterExceptionHandler? onError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = onError);

    messenger.allMessagesHandler = (channel, handler, message) {
      final String method = channel.split('.').last;
      calls.add(method);
      final bool isFailure = method == 'activate' && !isActivationAccepted;
      return Future.value(isFailure ? _failure : _success);
    };
  });

  tearDown(() => messenger.allMessagesHandler = null);

  ///
  Future<void> reportEverything(AppMetricaService service) async {
    await service.logEvent(const _Event());
    await service.setUser('42');
    await service.reportCheckoutStarted(_purchase);
    await service.reportPurchase(_purchase);
    await service.markKeyAction();
  }

  ///
  group('AppMetricaService', () {
    /// Without a key the SDK is never activated, and a call to it would only
    /// fail and log an error per report.
    test('without an API key nothing reaches the SDK', () async {
      final service = AppMetricaService();
      await service.init(const MetricaConfig());
      await reportEverything(service);

      check(calls).isEmpty();
    });

    ///
    test('after a failed activation nothing reaches the SDK', () async {
      isActivationAccepted = false;
      final service = AppMetricaService();
      await service.init(const MetricaConfig(appMetricaApiKey: 'key'));
      await reportEverything(service);

      check(calls).deepEquals(['activate']);
    });

    ///
    test('after the activation the reports reach the SDK', () async {
      final service = AppMetricaService();
      await service.init(const MetricaConfig(appMetricaApiKey: 'key'));
      calls.clear();
      await service.logEvent(const _Event());

      check(calls).contains('reportEventWithJson');
    });
  });
}
