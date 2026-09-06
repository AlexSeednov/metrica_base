/// Platform bridge to the JavaScript counter of Yandex Metrica.
///
/// The real implementation exists in the web build alone (`dart:js_interop`),
/// every other platform gets a stub — so the services on top of the bridge
/// compile everywhere and the platform branching lives in one place.
library;

export 'yandex_metrica_bridge_stub.dart'
    if (dart.library.js_interop) 'yandex_metrica_bridge_web.dart';
