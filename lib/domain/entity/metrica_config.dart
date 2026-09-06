import 'package:flutter/foundation.dart';

/// Keys and settings of the analytics integration, decided by the
/// application: which counters it reports to and how the SDK buffers.
///
/// The keys usually depend on the flavor, so the application builds the
/// config after the flavor is known and hands it to `MetricaBase.prepare`.
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
  /// `null` — mobile analytics stays off: the SDK is not activated and every
  /// report is dropped with an info log.
  final String? appMetricaApiKey;

  /// Number of the Yandex Metrica counter (web).
  ///
  /// `null` — web analytics stays off: the counter script is not loaded.
  final int? yandexMetricaCounterId;

  /// Session timeout in seconds: after this much inactivity the session is
  /// considered over (the minimum the SDK allows is 10).
  ///
  /// The default is above the SDK's own: a minute of stillness inside a long
  /// working session is not a new visit.
  final int sessionTimeoutSeconds;

  /// How many events the mobile SDK keeps on the device before delivery
  /// (the allowed range is 100–10000, the SDK default is 1000).
  ///
  /// The default is the top of the range: the buffer drains fastest exactly
  /// without a network — every failed request and every backend reachability
  /// check lands in the error reports — and a long offline stretch on the SDK
  /// default would evict the very events the buffer exists to keep.
  final int maxReportsInDatabaseCount;

  /// Whether advertising identifiers (Advertising ID / IDFA) go into the
  /// mobile reports. `null` — the SDK default, which includes them on
  /// Android. Turn off when the privacy policy promises they are not
  /// collected.
  final bool? advIdentifiersTracking;

  /// Whether the mobile SDK requests and sends the device location. `null` —
  /// the SDK default.
  final bool? locationTracking;

  /// Gate the web counter waits for before loading its script.
  ///
  /// The counter sets cookies, so where the law asks for a consent the script
  /// must not load until the user gives it. The counter activates as soon as
  /// the listenable reports `true` — at once, when the stored consent is
  /// already read, or later, when the user accepts the banner; reports made
  /// in the meantime are queued. `null` — no gate, the counter loads on init.
  final ValueListenable<bool>? webConsent;
}
