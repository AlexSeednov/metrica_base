/// Stub of the Metrica bridge outside the web.
///
/// The Metrica services are registered for the web alone, so nothing here is
/// ever called. Should it be, the script load answers `false` — a service
/// registered by mistake degrades like a blocked counter — and the rest
/// throws.
library;

/// There is no counter script outside the web
Future<bool> loadCounterScript(int counterId) async => false;

///
String currentPageUrl() => _unsupported();

///
void activateCounter(int counterId) => _unsupported();

///
void reportGoal(int counterId, String goal, Map<String, Object> parameters) =>
    _unsupported();

///
void reportPageView(
  int counterId, {
  required String url,
  required String title,
  required Map<String, Object> parameters,
}) => _unsupported();

///
void assignUserId(int counterId, String userId) => _unsupported();

///
void assignUserParameters(int counterId, Map<String, Object> parameters) =>
    _unsupported();

///
void pushEcommerce(Map<String, Object?> record) => _unsupported();

///
Never _unsupported() =>
    throw UnsupportedError('Yandex Metrica counter is web-only');
