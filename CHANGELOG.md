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
