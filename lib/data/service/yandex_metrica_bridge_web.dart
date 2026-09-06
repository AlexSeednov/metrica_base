/// Web implementation of the Metrica bridge: the official counter tag,
/// reproduced through `dart:js_interop`.
///
/// The script is attached from Dart rather than from `index.html`: the
/// counter number depends on the flavor, while `index.html` is one for every
/// build.
library;

import 'dart:async';
import 'dart:js_interop';

/// Address of the counter script: the counter number in the request — as in
/// the official snippet, Metrica serves the build with the settings of that
/// counter by it
String _tagScriptUrl(int counterId) =>
    'https://mc.yandex.ru/metrika/tag.js?id=$counterId';

/// The `ym` stub of the official snippet — piles the calls up in the `ym.a`
/// queue.
///
/// Has to exist **before** `tag.js` runs: the counter script does not create
/// the `ym` function itself — it only picks up an existing one and works off
/// its queue (by intercepting `push`). Without the stub the counter accepts
/// not a single call after loading, and `ym(...)` fails on undefined — the
/// activation is marked failed and the analytics silently go empty.
const String _counterStubSource =
    'window.ym=window.ym||function(){(window.ym.a=window.ym.a||[])'
    '.push(arguments)};window.ym.l=1*new Date();';

/// `ym` calls with a different number of arguments: the JavaScript function
/// is variadic, so it is declared through several signatures
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

/// Queue of E-commerce events the counter reads
@JS('dataLayer')
external _DataLayer? get _dataLayer;

///
@JS('dataLayer')
external set _dataLayer(_DataLayer? value);

/// Minimal DOM bindings — exactly what is needed to insert the counter
/// script; the full `web` package is not pulled in for this
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

/// Attach the counter script; `false` — the script did not load (an ad
/// blocker or the network)
Future<bool> loadCounterScript(int counterId) {
  final _Element? head = _document.head;
  if (head == null) return Future<bool>.value(false);

  /// The `ym` stub — strictly before `tag.js` is inserted, see
  /// [_counterStubSource]. An inline script runs synchronously on insertion
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

/// Current page address
String currentPageUrl() => _location.href;

/// Activate the counter — strictly after the script has loaded.
///
/// `defer` turns the automatic view on activation off: in a SPA the views
/// are sent by hand on every route change, an automatic one would double the
/// first screen. E-commerce events the counter reads from the `dataLayer`
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

/// Report a reached goal
void reportGoal(int counterId, String goal, Map<String, Object> parameters) =>
    _ym4(counterId.toJS, 'reachGoal'.toJS, goal.toJS, parameters.jsify());

/// Report a page view
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

/// Bind the user identifier to the visit
void assignUserId(int counterId, String userId) =>
    _ym3(counterId.toJS, 'setUserID'.toJS, userId.toJS);

/// Pass the user attributes
void assignUserParameters(int counterId, Map<String, Object> parameters) =>
    _ym3(counterId.toJS, 'userParams'.toJS, parameters.jsify());

/// Push an E-commerce record
void pushEcommerce(Map<String, Object?> record) =>
    _dataLayer?.push(record.jsify());
