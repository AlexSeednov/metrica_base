/// Page address for the web page view reports.
abstract final class PageUrlUtility {
  /// [href] with the route moved from the hash into the path:
  /// `https://host/#/product/1` becomes `https://host/product/1`.
  ///
  /// Flutter's default URL strategy keeps the route in the hash, which the
  /// reports ignore: every view would collapse into the single address of the
  /// site. Moving it here keeps the reports independent of the counter
  /// settings, and a hash-free address passes through unchanged.
  static String pageUrl(String href) {
    final Uri current = Uri.parse(href);
    final Uri route = Uri.parse(current.fragment);
    if (!route.path.startsWith('/')) return current.removeFragment().toString();

    return Uri(
      scheme: current.scheme,
      host: current.host,
      port: current.hasPort ? current.port : null,
      path: route.path,
      query: route.hasQuery ? route.query : null,
    ).toString();
  }
}
