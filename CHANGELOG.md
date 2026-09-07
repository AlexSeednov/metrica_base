## 0.0.2

* **`application_base` constraint widened to `>=0.3.7 <0.5.0`.** The caret
  stopped at 0.4.0, so an application that had moved to the new minor line
  could not resolve this package at all. Nothing here uses anything past
  0.3.7, and both lines in use across the applications now resolve.

* **Docs**: `docs/metrica_counter.md` — setting up the Yandex Metrica counter
  of the web version: creating it, the settings that matter for a Flutter SPA
  (the address filter and the subdomains, the hash tracking off, the Webvisor
  off, the timezone and the currency matched with AppMetrica), the goals the
  events of the registry need — a `reachGoal` without a goal declared
  beforehand lands in no report, and goals are not counted retroactively —
  and how to check that the data flows.

## 0.0.1

* Initial release: the Yandex analytics and crash reporting integration
  extracted from the applications on this stack, unified across them.

* **`AnalyticsService`** and **`CrashReportingService`** contracts, bound per
  platform by the package's injectable micro-module
  (`MetricaBasePackageModule`): AppMetrica in the `mobile` DI environment,
  the Yandex Metrica counter in the `web` one — pass
  `PlatformEnvironment.current` to `getIt.init`.

* **`MetricaBase.prepare(MetricaConfig)`** — the post-DI start-up: SDK
  activation with the keys of the config, then the crash hooks. The keys,
  the buffer settings and the web cookie-consent gate are the application's
  to decide; nothing in the package knows a flavor.

* **`AnalyticsEventBase`** — the base every application registry extends.
  The package reads only what an event says about itself: `name`,
  `parameters`, and `keyActionCounter` for the events that are key actions
  of the platform — there is no fixed list of events. `ScreenViewAnalyticsEvent`
  (sent by `AnalyticsNavigatorObserver`) and the service `ErrorAnalyticsEvent`
  ship with the package.

* **`AnalyticsPurchase`** — E-commerce order contents for the applications
  with their own billing; the currency is a field of the order now, not a
  constant.

* User identity is a `String?` everywhere: the reporting systems take a
  string, and an application with numeric identifiers converts at the call.

* **`ErrorGroupUtility`** — one grouping rule for every platform, so the
  same failure lands in one record in AppMetrica and in Metrica alike.

* **Docs** (`docs/`, in Russian): the AppMetrica dashboards guide, unified
  across the applications on the package — the base widgets, funnels,
  segments and alerts a project builds its own on top of — and the
  cookie-consent notes for the web counter.
