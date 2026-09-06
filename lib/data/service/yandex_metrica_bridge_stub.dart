/// Stub of the Metrica bridge for the non-web platforms.
///
/// The Metrica services are registered in the web DI environment alone, so
/// the stub is never reached — except for the script load, which honestly
/// reports the counter as unavailable.
library;

/// There is no counter script outside the web
Future<bool> loadCounterScript(int counterId) async => false;

/// Current page address
String currentPageUrl() => _unsupported();

/// Activate the counter
void activateCounter(int counterId) => _unsupported();

/// Report a reached goal
void reportGoal(int counterId, String goal, Map<String, Object> parameters) =>
    _unsupported();

/// Report a page view
void reportPageView(
  int counterId, {
  required String url,
  required String title,
  required Map<String, Object> parameters,
}) => _unsupported();

/// Bind the user identifier to the visit
void assignUserId(int counterId, String userId) => _unsupported();

/// Pass the user attributes
void assignUserParameters(int counterId, Map<String, Object> parameters) =>
    _unsupported();

/// Push an E-commerce record
void pushEcommerce(Map<String, Object?> record) => _unsupported();

///
Never _unsupported() =>
    throw UnsupportedError('Yandex Metrica counter is web-only');
