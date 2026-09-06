import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrica_base/data/utility/page_url_utility.dart';

void main() {
  ///
  group('PageUrlUtility.pageUrl', () {
    /// Flutter's default URL strategy keeps the route in the hash, and the
    /// hash is invisible to the page reports — the route has to move into
    /// the path.
    test('a hash route becomes the path', () {
      check(
        PageUrlUtility.pageUrl('https://host.ru/#/product/1'),
      ).equals('https://host.ru/product/1');
    });

    ///
    test('the query of the route is kept', () {
      check(
        PageUrlUtility.pageUrl('https://host.ru/#/list?kind=category'),
      ).equals('https://host.ru/list?kind=category');
    });

    ///
    test('the port is kept', () {
      check(
        PageUrlUtility.pageUrl('http://localhost:8080/#/product/1'),
      ).equals('http://localhost:8080/product/1');
    });

    /// Hash-free addresses (the path URL strategy) must pass through as they
    /// are, so the reports survive a switch of the strategy.
    test('an address without a route in the hash stays as it is', () {
      check(
        PageUrlUtility.pageUrl('https://host.ru/product/1'),
      ).equals('https://host.ru/product/1');
    });

    ///
    test('a hash that is not a route is dropped', () {
      check(
        PageUrlUtility.pageUrl('https://host.ru/product/1#details'),
      ).equals('https://host.ru/product/1');
    });
  });
}
