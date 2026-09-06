import 'package:metrica_base/domain/entity/analytics_event_base.dart';

/// An application error.
///
/// Service event of the web reporting: Metrica has no API of its own for
/// errors, so they go out as an ordinary analytics event. Not used on mobile —
/// there the crash reporting of the SDK takes the errors.
final class ErrorAnalyticsEvent extends AnalyticsEventBase {
  ///
  const ErrorAnalyticsEvent({
    required this.group,
    required this.message,
    required this.isFatal,
  });

  /// Group identifier that glues the repeats of one error together
  final String group;

  /// Error text — truncated, the parameter budget of an event is limited
  final String message;

  /// Unhandled error, as opposed to one caught in the regular way
  final bool isFatal;

  ///
  @override
  String get name => 'app_error';

  ///
  @override
  Map<String, Object> get parameters => {
    'group': group,
    'message': message,
    'is_fatal': isFatal,
  };
}
