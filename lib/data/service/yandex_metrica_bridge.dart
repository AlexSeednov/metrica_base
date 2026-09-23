/// Bridge to the JavaScript counter of Yandex Metrica.
///
/// The real implementation is web-only (`dart:js_interop`), elsewhere a stub
/// stands in: the services on top compile on every platform, and the
/// platform branch lives in this one place.
library;

export 'yandex_metrica_bridge_stub.dart'
    if (dart.library.js_interop) 'yandex_metrica_bridge_web.dart';
