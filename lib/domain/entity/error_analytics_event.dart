import 'package:metrica_base/domain/entity/analytics_event_base.dart';

/// An application error, as an analytics event.
///
/// Web only: Metrica has no error API, so errors go out as an ordinary event.
/// On mobile the SDK's crash reporting takes them.
final class ErrorAnalyticsEvent extends AnalyticsEventBase {
  ///
  const ErrorAnalyticsEvent({
    required this.group,
    required this.message,
    required this.isFatal,
  });

  /// Groups the repeats of one error, see `ErrorGroupUtility`.
  final String group;

  /// Error text, truncated: the parameters of an event have a size budget.
  final String message;

  /// An unhandled error, as opposed to one the application logged.
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
