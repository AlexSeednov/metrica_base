## 0.0.3

* **The first visit to a tab is reported.** A lazily built tab — the
  `AutoTabsRouter` default — announces its first visit through
  `didInitTabRoute`, not `didChangeTabRoute`, and the observer listened to the
  latter only. The first visit to every tab went unreported, on mobile and on
  the web alike; only a return to a tab already visited was counted. The tab a
  tabs router opens with stays unreported on purpose: the view of the route
  hosting the tabs covers it, and on the web a second one would count the same
  page twice.

* **Closing an anonymous window is no longer a screen view.** Closing a
  dialog, a menu or a picker reported the screen under it as viewed again
  (`pop`), and on the web as one more page view — although the window's
  opening was never reported, and the screen had stayed the current one. A pop
  is reported now only when the closed route is named.

* **Breadcrumbs the rate limit holds back are written later, not skipped.**
  The error environment is written at most every 5 seconds, and a line logged
  in between waited for the next line or error. So the lines right before a
  native crash — the ones that explain it — were the likeliest to be missing.
  A write the limit holds back now happens at the end of the interval. Also
  fixed: a line logged while the environment was being written broke the
  iteration over the live queue and cut the write short.

* **AppMetrica is not called before a successful activation.** Without an API
  key, or after a failed activation, every report still went to the SDK,
  although `MetricaConfig.appMetricaApiKey` promised the reports are dropped.
  Now nothing reaches the SDK until it is activated, and `init` logs the reason
  once.

* **`ScreenViewType` is renamed `ScreenViewTypeEnum`** and moved to
  `domain/enum/`, after the suffix and the folder every enum of the stack
  follows. The old name stays as a deprecated alias.

* A failed report of the crash service no longer names the service twice in
  the debug log.

* **README in Russian** — `README.ru.md`, a full translation of `README.md`,
  with a language switcher at the top of both. The English file stays the
  source of truth, and every README change is made in both files at once; the
  guides in `docs/` were written in Russian and stay single.

* **README corrected on the desktop platforms.** It said the services are
  not registered there; in fact everything that is not the web falls into the
  `mobile` environment, so Linux, macOS and Windows get the AppMetrica
  services, whose every call fails without a plugin implementation and is
  logged as an error. The doc comment of `PlatformEnvironment.mobile` says the
  same now.

* **README edited for readability, in both languages.** *Usage* goes in the
  order an application follows (dependency, module and environment, `prepare`)
  and names the two contracts; the long sentences of *Analytics*, *Crash
  reporting*, *Purchases* and *Web specifics* are split so that each states
  one thing, with the reasoning after the fact rather than inside it. The
  Russian text is rewritten the same way, without the calques it had picked
  up in translation.

* **Every comment in the package reviewed** — `lib/`, `pubspec.yaml` and
  `analysis_options.yaml`. Comments that retold the code are gone, wordy ones
  are cut down to the reason they carry, and the English no longer follows
  the Russian it was drafted from: the "journal of recent events" is
  breadcrumbs now, and the «» quotes are gone. Comments that contradicted the
  code are corrected — an unhandled error the handler does not claim is only
  printed by the engine, not fatal to the application, and without a network
  the SDK's buffer fills rather than drains. No code changes.

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
