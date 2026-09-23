/// Base of an analytics event.
///
/// The event registry belongs to the application: it declares its own
/// (usually `sealed`) family on top of this class. The package never sees a
/// fixed list of events — an implementation reads only what an event says
/// about itself.
abstract base class AnalyticsEventBase {
  ///
  const AnalyticsEventBase();

  /// Event name in the analytics system (snake_case).
  String get name;

  ///
  Map<String, Object> get parameters => const {};

  /// Lifetime profile counter the event increments when it is one of the
  /// platform's key actions, e.g. `projects_created_total`; `null` for an
  /// ordinary event.
  ///
  /// On mobile the counter grows by one and the "did a key action" flag is
  /// raised for segmentation. The web counter has no cumulative attributes,
  /// so there only the flag is set.
  String? get keyActionCounter => null;
}
