import 'package:flutter/foundation.dart';

/// Keys and settings of the analytics: which counters the application reports
/// to and how the SDK buffers.
///
/// The keys usually depend on the flavor, so the application builds the
/// config once the flavor is known and hands it to `MetricaBase.prepare`.
final class MetricaConfig {
  ///
  const MetricaConfig({
    this.appMetricaApiKey,
    this.yandexMetricaCounterId,
    this.sessionTimeoutSeconds = 60,
    this.maxReportsInDatabaseCount = 10000,
    this.advIdentifiersTracking,
    this.locationTracking,
    this.webConsent,
  });

  /// API key of the AppMetrica application (mobile platforms).
  ///
  /// `null` — mobile analytics stays off: the SDK is not activated, an info
  /// log says so once, and every report is dropped without reaching it.
  final String? appMetricaApiKey;

  /// Number of the Yandex Metrica counter (web).
  ///
  /// `null` — web analytics stays off: the counter script is not loaded.
  final int? yandexMetricaCounterId;

  /// Inactivity in seconds after which a mobile session ends; the SDK's
  /// minimum is 10.
  ///
  /// The default is above the SDK's own: a minute of stillness in a long
  /// working session is not a new visit.
  final int sessionTimeoutSeconds;

  /// How many events the mobile SDK keeps on the device until delivery; the
  /// allowed range is 100–10000, the SDK default is 1000.
  ///
  /// The default is the top of the range: the buffer fills fastest exactly
  /// when there is no network — every failed request and every backend
  /// reachability check becomes an error report — and on the SDK default a
  /// long offline stretch would evict the very events the buffer is for.
  final int maxReportsInDatabaseCount;

  /// Whether the mobile reports carry the advertising identifiers
  /// (Advertising ID / IDFA). `null` — the SDK default, which sends them on
  /// Android. Turn off when the privacy policy promises not to collect them.
  final bool? advIdentifiersTracking;

  /// Whether the mobile SDK requests and sends the device location. `null` —
  /// the SDK default.
  final bool? locationTracking;

  /// Consent the web counter waits for before loading its script.
  ///
  /// The counter sets cookies, and where the law requires consent the script
  /// must not load before the user gives it. The counter activates once the
  /// value is `true` — at once, if a stored consent is already read, or
  /// later, when the user accepts the banner; the first 100 reports made
  /// meanwhile are queued. `null` — no gate, the counter loads on init.
  final ValueListenable<bool>? webConsent;
}
