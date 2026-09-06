import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrica_base/domain/entity/analytics_event_base.dart';
import 'package:metrica_base/domain/entity/error_analytics_event.dart';
import 'package:metrica_base/domain/entity/screen_view_analytics_event.dart';

/// An application event with nothing but a name — the most common shape.
final class _PlainEvent extends AnalyticsEventBase {
  ///
  const _PlainEvent();

  ///
  @override
  String get name => 'plain';
}

/// An application event that counts as a key action.
final class _KeyActionEvent extends AnalyticsEventBase {
  ///
  const _KeyActionEvent();

  ///
  @override
  String get name => 'project_created';

  ///
  @override
  String? get keyActionCounter => 'projects_created_total';
}

void main() {
  ///
  group('AnalyticsEventBase', () {
    /// The defaults are what lets an application registry declare an event
    /// in two lines: no parameters, no key action.
    test('an event is an ordinary one by default', () {
      const _PlainEvent event = _PlainEvent();

      check(event.parameters).isEmpty();
      check(event.keyActionCounter).isNull();
    });

    ///
    test('an event declares its key action counter itself', () {
      check(
        const _KeyActionEvent().keyActionCounter,
      ).equals('projects_created_total');
    });
  });

  ///
  group('ScreenViewAnalyticsEvent', () {
    /// A missing previous screen must not turn into a `null` parameter: the
    /// reporting systems take the parameters as they come.
    test('the previous screen is omitted when unknown', () {
      const ScreenViewAnalyticsEvent event = ScreenViewAnalyticsEvent(
        screenName: 'MainRoute',
        type: ScreenViewType.push,
        isModal: false,
      );

      check(event.name).equals('screen_view');
      check(event.parameters).deepEquals({
        'screen_name': 'MainRoute',
        'type': 'push',
        'is_modal': false,
      });
    });

    ///
    test('the previous screen is reported when known', () {
      const ScreenViewAnalyticsEvent event = ScreenViewAnalyticsEvent(
        screenName: 'ProductRoute',
        type: ScreenViewType.pop,
        isModal: true,
        previousScreen: 'MainRoute',
      );

      check(event.parameters['previous_screen']).equals('MainRoute');
      check(event.parameters['type']).equals('pop');
    });
  });

  ///
  group('ErrorAnalyticsEvent', () {
    ///
    test('carries the group, the message and the fatality', () {
      const ErrorAnalyticsEvent event = ErrorAnalyticsEvent(
        group: 'Product # not found',
        message: 'Product 42 not found',
        isFatal: false,
      );

      check(event.name).equals('app_error');
      check(event.parameters).deepEquals({
        'group': 'Product # not found',
        'message': 'Product 42 not found',
        'is_fatal': false,
      });
    });
  });
}
