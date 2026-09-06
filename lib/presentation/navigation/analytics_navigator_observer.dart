import 'package:application_base/core/service/service_locator.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:metrica_base/domain/entity/screen_view_analytics_event.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';

/// Sends a screen view event to analytics on every route change — opening,
/// replacement, return, tab switch and bottom sheet.
///
/// Add it to the `navigatorObservers` of the application's router.
final class AnalyticsNavigatorObserver extends AutoRouterObserver {
  ///
  AnalyticsNavigatorObserver();

  /// Resolved lazily: the router — and the observer with it — may be built
  /// before the analytics service is
  AnalyticsService get _analyticsService => getIt<AnalyticsService>();

  ///
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _report(
    current: route,
    previous: previousRoute,
    type: ScreenViewType.push,
  );

  ///
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _report(
        current: newRoute,
        previous: oldRoute,
        type: ScreenViewType.replace,
      );

  /// On a return it is [previousRoute] that becomes visible, while the
  /// closing [route] is the screen the user left.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _report(
    current: previousRoute,
    previous: route,
    type: ScreenViewType.pop,
  );

  ///
  @override
  void didChangeTabRoute(TabPageRoute route, TabPageRoute previousRoute) =>
      _analyticsService.logEvent(
        ScreenViewAnalyticsEvent(
          screenName: route.name,
          type: ScreenViewType.tab,
          isModal: false,
          previousScreen: previousRoute.name,
        ),
      );

  /// Only named routes (screens and bottom sheets) are reported, so the
  /// analytics is not littered with anonymous system windows.
  void _report({
    required Route<dynamic>? current,
    required Route<dynamic>? previous,
    required ScreenViewType type,
  }) {
    final String? screenName = current?.settings.name;
    if (screenName == null || screenName.isEmpty) return;

    _analyticsService.logEvent(
      ScreenViewAnalyticsEvent(
        screenName: screenName,
        type: type,
        isModal: current is ModalBottomSheetRoute,
        previousScreen: previous?.settings.name,
      ),
    );
  }
}
