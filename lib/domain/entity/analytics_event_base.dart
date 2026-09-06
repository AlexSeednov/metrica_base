/// Base of an analytics event.
///
/// The registry of events belongs to the application: it declares its own
/// (usually `sealed`) family on top of this class, so the package never sees
/// a fixed list of events — an implementation reads only what an event says
/// about itself, and two applications on the same package share nothing but
/// this shape.
abstract base class AnalyticsEventBase {
  ///
  const AnalyticsEventBase();

  /// Event name in the analytics system (snake_case).
  String get name;

  /// Event parameters.
  Map<String, Object> get parameters => const {};

  /// Lifetime profile counter this event bumps, when the event is one of the
  /// platform's key actions — `projects_created_total`, say.
  ///
  /// On mobile the counter grows by one and the «did a key action» flag is
  /// raised for segmentation; the web counter has no cumulative attributes,
  /// so only the flag is set there. `null` — an ordinary event.
  String? get keyActionCounter => null;
}
