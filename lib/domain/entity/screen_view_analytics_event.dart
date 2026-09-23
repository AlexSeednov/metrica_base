import 'package:metrica_base/domain/entity/analytics_event_base.dart';
import 'package:metrica_base/domain/enum/screen_view_type_enum.dart';

/// A screen or a bottom sheet became visible.
///
/// Sent by `AnalyticsNavigatorObserver` on route changes. On the web it goes
/// out as a page view rather than a goal: page views feed Metrica's standard
/// content reports and its parsing of the UTM tags.
final class ScreenViewAnalyticsEvent extends AnalyticsEventBase {
  ///
  const ScreenViewAnalyticsEvent({
    required this.screenName,
    required this.type,
    required this.isModal,
    this.previousScreen,
  });

  /// Route name, e.g. `ProductRoute`.
  final String screenName;

  ///
  final ScreenViewTypeEnum type;

  /// A bottom sheet rather than a screen.
  final bool isModal;

  /// Route the user came from, for path analysis; left out of [parameters]
  /// when unknown.
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

/// The old name, kept for the applications that already use it.
@Deprecated('Use ScreenViewTypeEnum')
typedef ScreenViewType = ScreenViewTypeEnum;
