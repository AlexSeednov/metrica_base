/// Page address for the web page view reports.
abstract final class PageUrlUtility {
  /// Address of the page a view is reported for.
  ///
  /// The route lives in the hash (`https://host/#/product/1` — Flutter's
  /// default URL strategy), and the hash is not parsed in the reports: every
  /// view would collapse into the single address of the site. The route is
  /// moved from the hash into the path — this way the reports do not depend
  /// on the counter settings and survive a switch to hash-free addresses.
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
