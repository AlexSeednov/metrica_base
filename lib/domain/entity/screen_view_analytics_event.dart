import 'package:metrica_base/domain/entity/analytics_event_base.dart';

/// A screen or a modal (bottom sheet) became visible.
///
/// Sent by `AnalyticsNavigatorObserver` on every route change. On the web it
/// goes out as a page view of the SPA rather than a goal — that is what gives
/// Metrica its standard content reports and lets it parse the ad tags.
final class ScreenViewAnalyticsEvent extends AnalyticsEventBase {
  ///
  const ScreenViewAnalyticsEvent({
    required this.screenName,
    required this.type,
    required this.isModal,
    this.previousScreen,
  });

  /// Name of the route — screen or sheet — that became visible
  final String screenName;

  /// How exactly the screen became visible
  final ScreenViewType type;

  /// Whether the route is a modal window (bottom sheet)
  final bool isModal;

  /// Name of the screen the user came from (for path analysis)
  final String? previousScreen;

  ///
  @override
  String get name => 'screen_view';

  ///
  @override
  Map<String, Object> get parameters => {
    'screen_name': screenName,
    'type': type.value,
    'is_modal': isModal,
    'previous_screen': ?previousScreen,
  };
}

/// Kind of transition that made a screen visible
enum ScreenViewType {
  /// Forward navigation onto a new screen
  push('push'),

  /// Return to the previous screen
  pop('pop'),

  /// Replacement of the current screen
  replace('replace'),

  /// Switch of a bottom navigation tab
  tab('tab');

  ///
  const ScreenViewType(this.value);

  /// Value for analytics (snake_case)
  final String value;
}
