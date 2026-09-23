**English** | [Русский](README.ru.md)

Unified Yandex analytics and crash reporting for Flutter applications based on
the [application_base package](https://github.com/AlexSeednov/application_base)
with a [special architecture](https://miro.com/app/board/uXjVNJVBM3o=/?share_link_id=771428578014):
[AppMetrica](https://appmetrica.yandex.ru) on mobile,
[Yandex Metrica](https://metrika.yandex.ru) on the web, one contract for both.

It is the counterpart of
[firebase_base](https://github.com/AlexSeednov/firebase_base): an application
reporting to Firebase takes that package, an application reporting to Yandex
takes this one.

## Features

For now includes:
* [Analytics](#analytics) — usage events, user identity, key actions
* [Events registry](#events-registry) — the application's own event family
  on a shared base
* [Screen views](#screen-views) — a router observer reporting every route
  change
* [Crash reporting](#crash-reporting) — errors, unhandled exceptions and the
  journal of recent events
* [Purchases](#purchases) — E-commerce reports for an application with its
  own billing
* [Web specifics](#web-specifics) — cookie consent, ad blockers, page
  addresses
* [Documentation](#documentation) — the counter setup, the dashboards guide
  and the cookie-consent notes

## Supported platforms

* Android — AppMetrica SDK
* iOS — AppMetrica SDK
* Web — Yandex Metrica counter

The services are split by the kind of platform: the web gets the Metrica
counter, everything else AppMetrica. On Linux, macOS and Windows that means no
analytics in effect: `appmetrica_plugin` has no implementation there. The
AppMetrica services are registered and resolve, but every call fails, is
logged as an error and never reaches a report. Nothing throws, so an
application runs there, just without analytics.

## Requirements

The minimum requirements are those of the
[application_base package](https://github.com/AlexSeednov/application_base)
and [appmetrica_plugin](https://pub.dev/packages/appmetrica_plugin).

## Changelog

Refer to the
[Changelog](https://github.com/AlexSeednov/metrica_base/blob/main/CHANGELOG.md)
for all release notes.

## Usage

1. Add an entry like this to the application's `pubspec.yaml` (and run
   `flutter pub get`):

```yaml
  # Not supported: Linux | macOS | Windows
  metrica_base:
    git:
      url: https://github.com/AlexSeednov/metrica_base
      tag_pattern: v{{version}}
    version: 0.0.3
```

2. Wire the package's injectable module and pass the platform environment to
   `getIt.init`. The two implementations are split by DI **environment**:
   AppMetrica lives in `mobile`, the Metrica counter in `web`, and
   `PlatformEnvironment.current` picks the right one:

```dart
import 'package:metrica_base/core/const/platform_environment.dart';
import 'package:metrica_base/core/service/service_locator_metrica.module.dart';

@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(ApplicationBasePackageModule),
    ExternalModule(MetricaBasePackageModule),
  ],
)
Future<void> configureDependencies() =>
    getIt.init(environment: PlatformEnvironment.current);
```

3. On launch await the DI init and start the analytics with the keys of the
   application:

```dart
await configureDependencies();

await MetricaBase.prepare(
  const MetricaConfig(
    appMetricaApiKey: '<AppMetrica API key>',   // mobile; null — off
    yandexMetricaCounterId: 12345678,           // web;    null — off
  ),
);
```

The order matters. `getIt.init()` is asynchronous when external package
modules are wired, so **await** it. `MetricaBase.prepare` takes the services
from getIt, so it must run **after** `getIt.init()` has completed. Call
`prepare` itself **as early as possible**: sessions are counted from here, and
everything that starts later already has a reporter to land in.

The keys usually depend on the flavor. The application keeps them in a
constant of its own and builds the config once the flavor is known; nothing in
the package reads a flavor. The other fields of `MetricaConfig`:

* `sessionTimeoutSeconds` (60) and `maxReportsInDatabaseCount` (10000) — the
  mobile SDK buffering. The doc comments explain why the defaults differ from
  the SDK's own.
* `advIdentifiersTracking`, `locationTracking` — `null` keeps the SDK
  defaults. Set them to `false` when the privacy policy promises the
  identifiers and the location are not collected.
* `webConsent` — the cookie-consent gate of the web counter, see
  [Web specifics](#web-specifics).

There are two services: `AnalyticsService` and `CrashReportingService`. They
are contracts, and depend on them alone: the implementations are the package's
business, and a test hands a fake. Both are singletons owned by getIt. Take
them via `getIt<T>()` or through a constructor.

## Analytics

The methods of `AnalyticsService`:

* `logEvent(event)` — an event of the application's registry, see
  [Events registry](#events-registry). It goes out as an AppMetrica event with
  parameters on mobile and as a goal of the counter on the web. For every
  event that matters on the web, create a goal with the same identifier in
  the Metrica dashboard: a `reachGoal` without a goal lands nowhere, see
  [`docs/metrica_counter.md`](docs/metrica_counter.md).
* `setUser(userId)` — the user identity, a `String?`. `null` drops it on
  mobile. The web counter cannot drop one: the current visit is already bound,
  and the next visit stays anonymous anyway. An application with numeric
  identifiers converts at the call.
* `markKeyAction()` — raises the `did_key_action` profile flag used for
  audience segmentation. For an action that is an event of its own, declare
  `keyActionCounter` on the event instead.

Analytics never affects the business flow: every call is guarded, a failure
is only logged.

## Events registry

The registry of events belongs to the application. It declares its own family
on top of `AnalyticsEventBase`, usually `sealed`. The package never sees a
fixed list of events, and two applications on the same package share nothing
but the shape:

```dart
sealed class AnalyticsEvent extends AnalyticsEventBase {
  const AnalyticsEvent();
}

final class ProjectCreatedAnalyticsEvent extends AnalyticsEvent {
  const ProjectCreatedAnalyticsEvent({required this.source});

  final String source;

  @override
  String get name => 'project_created';

  @override
  Map<String, Object> get parameters => {'source': source};

  /// A key action of the platform: bumps the lifetime counter of the profile
  @override
  String? get keyActionCounter => 'projects_created_total';
}
```

An implementation reads only what an event says about itself:

* `name` and `parameters` — what goes out;
* `keyActionCounter` — for the events that are key actions of the platform.
  On mobile the counter attribute grows by one and the `did_key_action` flag
  is raised. The web counter has no cumulative attributes, so only the flag is
  set there.

`sealed` stays in the application on purpose: a sealed class cannot be
extended from another library, and the exhaustive `switch`es over the
registry, if any, are the application's own.

## Screen views

`AnalyticsNavigatorObserver` is an `AutoRouterObserver` that sends a
`ScreenViewAnalyticsEvent` on every route change: push, replace, pop, tab
switch and bottom sheet. Only named routes are reported, so anonymous windows
— dialogs, menus, pickers — stay out. Closing one is not a view either: the
screen under it stayed the current one all along. Add the observer to the
router:

```dart
navigatorObservers: () => [AnalyticsNavigatorObserver()],
```

A tab counts from its first visit. A lazily built tab (the `AutoTabsRouter`
default) reports that visit apart from the later switches, and the observer
takes both. The tab a tabs router opens with gets no view of its own: the view
of the route that hosts the tabs covers it, and on the web a second one would
count the same page twice.

On mobile a view is an ordinary event named `screen_view`. On the web it goes
out as a page **hit** of the SPA rather than a goal: that is what gives
Metrica its standard content reports and lets it parse the ad tags. The route
is reported as the page path even under the hash URL strategy, see
[Web specifics](#web-specifics).

## Crash reporting

`CrashReportingService.prepare()` is called from `MetricaBase.prepare` and
hooks the reporting onto the global error handlers and onto the remote sinks
of the `application_base` logger. As a result everything the application logs
as an error becomes a report, without a single extra call at the sites.

On **mobile** the AppMetrica SDK intercepts native crashes and unhandled
Flutter errors itself on activation. The service adds what the SDK cannot
reach:

* asynchronous errors outside the Flutter zone (`PlatformDispatcher.onError`);
* handled errors from the application logger. They are reported with an
  explicit **group**: without one AppMetrica glues errors by their stack, and
  every logger call has the same one;
* a **journal** of the last 25 info messages of the logger, so a report shows
  what the user was doing. It is kept in the error environment ahead of time,
  because a native crash never passes through Dart. The environment is
  written at most every 5 seconds; a write the limit holds back is deferred to
  the end of the interval, not skipped.

On the **web** Metrica has no crash reporting, so errors go out as the service
event `app_error`: without stacks and journal, but with the same grouping. At
most 30 per visit, so a looping error cannot spam the counter.

The grouping is one rule for every platform (`ErrorGroupUtility`): the first
line of the message with the numbers replaced by `#`. So the same failure with
different identifiers in its text lands in one record.

`setUser(userId)` binds the reports to the user. It is a separate call from
the one in analytics: a native crash report has to carry the identity
beforehand.

## Purchases

For an application with its own billing (a payment provider rather than the
stores) `AnalyticsService` reports the purchase funnel:

* `reportCheckoutStarted(purchase)` — the checkout start;
* `reportPurchase(purchase)` — the `purchase_success` event, the E-commerce
  order and, on mobile, the cumulative profile attributes
  `purchases_count_total` / `purchases_amount_total` (over all purchases) and
  `purchases_count_paid` / `purchases_amount_paid` (over the paid ones).

Both take the same `AnalyticsPurchase`. It is one object because the two steps
have to go out with identical contents, otherwise the funnel does not link up.
Free acquisitions stay out of E-commerce, because zero orders would distort
the average check. They are counted by the event and the attributes alone.

Purchases through the stores (IAP) are not covered yet: AppMetrica expects
those as Revenue validated by receipt, which is a different matter.

## Web specifics

**Cookie consent.** The counter sets cookies, so where the law asks for a
consent the script must not load until the user gives it. Pass the consent as
`MetricaConfig.webConsent`, a `ValueListenable<bool>`. The counter activates
as soon as it reports `true`: at once, when a stored consent is read on
start-up, or later, when the banner is accepted mid-session. Reports made
before the activation are queued (up to 100), so the visit does not lose its
first events. `null` means there is no gate and the counter loads on init.

**Ad blockers.** They cut the counter off en masse. A script that fails to
load is an expected environment, not an error: the activation is marked failed
with an info log, and every report is silently dropped from then on.

**Page addresses.** With Flutter's default URL strategy the route lives in the
hash (`https://host/#/product/1`), and Metrica does not parse the hash: every
view would collapse into the single address of the site. The route is moved
into the path (`https://host/product/1`) before the hit. So the reports do not
depend on the counter settings and survive a switch to the path strategy.

**The counter script is attached from Dart**, not from `index.html`: the
counter number depends on the flavor, while `index.html` is one for every
build. Nothing has to be added to the page. Pasting the snippet of the
dashboard on top of it raises a second counter without `defer`, which doubles
the first view, past the consent gate.

**The counter itself**, that is creating it, the settings that matter for a
Flutter SPA and the goals the events of the registry need, is described in
[`docs/metrica_counter.md`](docs/metrica_counter.md).

## Documentation

Longer guides live in `docs/`, in Russian. Their audience is the product side
of the applications on this stack:

* [`docs/metrica_counter.md`](docs/metrica_counter.md) — the Yandex Metrica
  counter of the web version: how to create it, what to set in its settings,
  which goals the events of the registry need (a `reachGoal` without a goal
  declared beforehand lands nowhere), and how to check that the data flows.
* [`docs/appmetrica_dashboards.md`](docs/appmetrica_dashboards.md) — the two
  AppMetrica workspaces («Продукт», «Стабильность») every application on the
  package starts from: what the package reports, the widget form, the base
  widgets, funnels, segments, crash alerts, and what the dashboard cannot do.
  A project documents only its own events and widgets on top of it.
* [`docs/cookie_consent.md`](docs/cookie_consent.md) — the cookie-consent
  gate of the web counter: why the law asks for it, how the gate works, and
  what the application has to build around it (banner, storage, consent
  version).
