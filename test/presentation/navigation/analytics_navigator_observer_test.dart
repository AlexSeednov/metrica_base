import 'package:application_base/core/service/service_locator.dart';
import 'package:auto_route/auto_route.dart';
import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrica_base/domain/entity/analytics_event_base.dart';
import 'package:metrica_base/domain/entity/analytics_purchase.dart';
import 'package:metrica_base/domain/entity/metrica_config.dart';
import 'package:metrica_base/domain/entity/screen_view_analytics_event.dart';
import 'package:metrica_base/domain/enum/screen_view_type_enum.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';
import 'package:metrica_base/presentation/navigation/analytics_navigator_observer.dart';

/// Keeps the events instead of sending them.
final class _FakeAnalyticsService implements AnalyticsService {
  ///
  final List<AnalyticsEventBase> events = [];

  ///
  @override
  Future<void> init(MetricaConfig config) async {}

  ///
  @override
  Future<void> setUser(String? userId) async {}

  ///
  @override
  Future<void> logEvent(AnalyticsEventBase event) async => events.add(event);

  ///
  @override
  Future<void> reportCheckoutStarted(AnalyticsPurchase purchase) async {}

  ///
  @override
  Future<void> reportPurchase(AnalyticsPurchase purchase) async {}

  ///
  @override
  Future<void> markKeyAction() async {}
}

/// A route; `null` [name] makes an anonymous one, like a dialog or a menu.
Route<void> _route(String? name) => MaterialPageRoute<void>(
  builder: (_) => const SizedBox(),
  settings: RouteSettings(name: name),
);

///
TabPageRoute _tab(String name, int index) => TabPageRoute(
  routeInfo: RouteMatch(
    config: AutoRoute(page: PageInfo.emptyShell(name)),
    segments: const [],
    stringMatch: '',
    key: ValueKey(name),
  ),
  index: index,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAnalyticsService analytics;
  late AnalyticsNavigatorObserver observer;

  setUp(() {
    analytics = _FakeAnalyticsService();
    getIt.registerSingleton<AnalyticsService>(analytics);
    observer = AnalyticsNavigatorObserver();
  });

  tearDown(getIt.reset);

  ///
  List<ScreenViewAnalyticsEvent> views() =>
      analytics.events.cast<ScreenViewAnalyticsEvent>();

  ///
  group('AnalyticsNavigatorObserver', () {
    ///
    test('a named screen is reported on push', () {
      observer.didPush(_route('ProductRoute'), _route('CatalogRoute'));

      check(views()).length.equals(1);
      check(views().single)
        ..has((e) => e.screenName, 'screenName').equals('ProductRoute')
        ..has((e) => e.type, 'type').equals(ScreenViewTypeEnum.push)
        ..has((e) => e.previousScreen, 'previousScreen').equals('CatalogRoute');
    });

    /// The screen under a dialog never stopped being the current one, and
    /// the dialog itself was not reported on its way in.
    test('closing an anonymous window is not a view', () {
      observer
        ..didPush(_route(null), _route('ChatRoute'))
        ..didPop(_route(null), _route('ChatRoute'));

      check(analytics.events).isEmpty();
    });

    ///
    test('closing a named route reports the screen under it', () {
      observer.didPop(_route('ShareSheet'), _route('ChatRoute'));

      check(views().single)
        ..has((e) => e.screenName, 'screenName').equals('ChatRoute')
        ..has((e) => e.type, 'type').equals(ScreenViewTypeEnum.pop)
        ..has((e) => e.previousScreen, 'previousScreen').equals('ShareSheet');
    });

    /// A lazily built tab reports its first visit as an init, not a change:
    /// without this the first visit to every tab went unreported.
    test('the first visit to a tab is reported', () {
      observer.didInitTabRoute(_tab('ReviewsRoute', 1), _tab('AboutRoute', 0));

      check(views().single)
        ..has((e) => e.screenName, 'screenName').equals('ReviewsRoute')
        ..has((e) => e.type, 'type').equals(ScreenViewTypeEnum.tab)
        ..has((e) => e.previousScreen, 'previousScreen').equals('AboutRoute');
    });

    /// The initial tab is covered by the view of the route hosting the tabs;
    /// a second view would count the same web page twice.
    test('the setup of a tabs router is not a view', () {
      observer
        ..didInitTabRoute(_tab('AboutRoute', 0), null)
        ..didInitTabRoute(_tab('ReviewsRoute', 1), null);

      check(analytics.events).isEmpty();
    });

    ///
    test('a switch to a visited tab is reported', () {
      observer.didChangeTabRoute(
        _tab('AboutRoute', 0),
        _tab('ReviewsRoute', 1),
      );

      check(views().single)
        ..has((e) => e.screenName, 'screenName').equals('AboutRoute')
        ..has((e) => e.type, 'type').equals(ScreenViewTypeEnum.tab);
    });
  });
}
