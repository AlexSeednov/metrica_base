import 'package:application_base/core/service/service_locator.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:metrica_base/domain/entity/screen_view_analytics_event.dart';
import 'package:metrica_base/domain/enum/screen_view_type_enum.dart';
import 'package:metrica_base/domain/service/analytics_service.dart';

/// Sends a screen view event to analytics on every route change — opening,
/// replacement, return, tab switch and bottom sheet.
///
/// Add it to the `navigatorObservers` of the application's router.
final class AnalyticsNavigatorObserver extends AutoRouterObserver {
  ///
  AnalyticsNavigatorObserver();

  /// Resolved lazily: the router, and the observer with it, may be built
  /// before the analytics service.
  AnalyticsService get _analyticsService => getIt<AnalyticsService>();

  ///
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _report(
    current: route,
    previous: previousRoute,
    type: ScreenViewTypeEnum.push,
  );

  ///
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _report(
        current: newRoute,
        previous: oldRoute,
        type: ScreenViewTypeEnum.replace,
      );

  /// On a return it is [previousRoute] that becomes visible, while the
  /// closing [route] is the screen the user left.
  ///
  /// Closing an anonymous window — a dialog, a menu, a picker — is not a
  /// view: its opening was not reported either, and the screen under it
  /// stayed the current one all along.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name?.isEmpty ?? true) return;

    _report(
      current: previousRoute,
      previous: route,
      type: ScreenViewTypeEnum.pop,
    );
  }

  ///
  @override
  void didChangeTabRoute(TabPageRoute route, TabPageRoute previousRoute) =>
      _analyticsService.logEvent(
        ScreenViewAnalyticsEvent(
          screenName: route.name,
          type: ScreenViewTypeEnum.tab,
          isModal: false,
          previousScreen: previousRoute.name,
        ),
      );

  /// A tab built lazily — the default of `AutoTabsRouter` — reports its first
  /// visit here rather than in [didChangeTabRoute].
  ///
  /// Without [previousRoute] this is the setup of the tabs router itself: its
  /// initial tab, or every tab at once with `lazyLoad: false`. That view is
  /// already reported as the route that hosts the tabs, and on the web a
  /// second one would count the same page twice.
  @override
  void didInitTabRoute(TabPageRoute route, TabPageRoute? previousRoute) {
    if (previousRoute == null) return;

    didChangeTabRoute(route, previousRoute);
  }

  /// Only named routes — screens and bottom sheets — are reported: anonymous
  /// windows such as dialogs and menus would only add noise.
  void _report({
    required Route<dynamic>? current,
    required Route<dynamic>? previous,
    required ScreenViewTypeEnum type,
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
