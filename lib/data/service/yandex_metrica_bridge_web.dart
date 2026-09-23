/// Web implementation of the Metrica bridge: the official counter tag,
/// reproduced through `dart:js_interop`.
///
/// The script is attached from Dart rather than from `index.html`: the
/// counter number depends on the flavor, while `index.html` is shared by
/// every build.
library;

import 'dart:async';
import 'dart:js_interop';

/// The counter number goes into the query, as in the official snippet:
/// Metrica serves a script built with that counter's settings.
String _tagScriptUrl(int counterId) =>
    'https://mc.yandex.ru/metrika/tag.js?id=$counterId';

/// The `ym` stub of the official snippet: queues the calls in `ym.a`.
///
/// Must exist **before** `tag.js` runs: the script does not create `ym`, it
/// takes over an existing one and works off its queue. Without the stub
/// `ym(...)` fails as undefined, the activation is marked failed, and the
/// analytics silently stay empty.
const String _counterStubSource =
    'window.ym=window.ym||function(){(window.ym.a=window.ym.a||[])'
    '.push(arguments)};window.ym.l=1*new Date();';

/// `ym` is variadic in JavaScript, so it is bound once per argument count.
@JS('ym')
external void _ym3(JSAny? first, JSAny? second, JSAny? third);

///
@JS('ym')
external void _ym4(JSAny? first, JSAny? second, JSAny? third, JSAny? fourth);

///
@JS('document')
external _Document get _document;

///
@JS('location')
external _Location get _location;

/// Queue of E-commerce records the counter reads.
@JS('dataLayer')
external _DataLayer? get _dataLayer;

///
@JS('dataLayer')
external set _dataLayer(_DataLayer? value);

/// Just enough DOM to insert the counter script, instead of pulling in the
/// `web` package.
extension type _Document(JSObject _) implements JSObject {
  ///
  external _Element createElement(String tagName);

  ///
  external _Element? get head;
}

///
extension type _Element(JSObject _) implements JSObject {
  ///
  external void setAttribute(String name, String value);

  ///
  external set textContent(String? value);

  ///
  external _Element appendChild(_Element child);

  ///
  external set onload(JSFunction? handler);

  ///
  external set onerror(JSFunction? handler);
}

///
extension type _Location(JSObject _) implements JSObject {
  ///
  external String get href;
}

///
extension type _DataLayer(JSObject _) implements JSObject {
  ///
  external void push(JSAny? record);
}

/// Inserts the counter script; `false` when it did not load — an ad blocker
/// or the network.
Future<bool> loadCounterScript(int counterId) {
  final _Element? head = _document.head;
  if (head == null) return Future<bool>.value(false);

  /// The `ym` stub goes first, see [_counterStubSource]; an inline script
  /// runs synchronously on insertion
  head.appendChild(
    _document.createElement('script')..textContent = _counterStubSource,
  );

  final Completer<bool> completer = Completer<bool>();

  final _Element script = _document.createElement('script')
    ..setAttribute('src', _tagScriptUrl(counterId))
    ..setAttribute('async', 'true')
    ..onload = ((JSAny? event) {
      if (!completer.isCompleted) completer.complete(true);
    }).toJS
    ..onerror = ((JSAny? event) {
      if (!completer.isCompleted) completer.complete(false);
    }).toJS;
  head.appendChild(script);

  return completer.future;
}

///
String currentPageUrl() => _location.href;

/// Call only after the script has loaded.
///
/// `defer` turns off the automatic page view on activation: the views are
/// sent by hand on every route change, and an automatic one would count the
/// first screen twice. E-commerce records are read from the `dataLayer`
/// queue.
void activateCounter(int counterId) {
  _dataLayer ??= _DataLayer(<JSAny?>[].toJS);

  _ym3(
    counterId.toJS,
    'init'.toJS,
    {
      'clickmap': true,
      'trackLinks': true,
      'accurateTrackBounce': true,
      'defer': true,
      'ecommerce': 'dataLayer',
    }.jsify(),
  );
}

///
void reportGoal(int counterId, String goal, Map<String, Object> parameters) =>
    _ym4(counterId.toJS, 'reachGoal'.toJS, goal.toJS, parameters.jsify());

///
void reportPageView(
  int counterId, {
  required String url,
  required String title,
  required Map<String, Object> parameters,
}) => _ym4(
  counterId.toJS,
  'hit'.toJS,
  url.toJS,
  {'title': title, 'params': parameters}.jsify(),
);

/// Binds the user id to the visit.
void assignUserId(int counterId, String userId) =>
    _ym3(counterId.toJS, 'setUserID'.toJS, userId.toJS);

///
void assignUserParameters(int counterId, Map<String, Object> parameters) =>
    _ym3(counterId.toJS, 'userParams'.toJS, parameters.jsify());

///
void pushEcommerce(Map<String, Object?> record) =>
    _dataLayer?.push(record.jsify());
