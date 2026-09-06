import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrica_base/core/utility/error_group_utility.dart';

void main() {
  ///
  group('ErrorGroupUtility.groupId', () {
    /// The whole point of the grouping: the same failure with different
    /// identifiers in its text must land in one record.
    test('numbers are replaced, so identifiers do not split a group', () {
      check(
        ErrorGroupUtility.groupId('Product 42 not found', limit: 100),
      ).equals('Product # not found');

      check(
        ErrorGroupUtility.groupId('Product 42 not found', limit: 100),
      ).equals(ErrorGroupUtility.groupId('Product 7 not found', limit: 100));
    });

    ///
    test('only the first line of the message is taken', () {
      check(
        ErrorGroupUtility.groupId('Request failed\nbody: {…}', limit: 100),
      ).equals('Request failed');
    });

    /// The reporting systems cap the identifier length; a longer one would be
    /// rejected or silently truncated by them, so it is cut here.
    test('the identifier is cut to the limit', () {
      check(ErrorGroupUtility.groupId('abcdefghij', limit: 4)).equals('abcd');
    });

    ///
    test('a message within the limit stays untouched', () {
      check(ErrorGroupUtility.groupId('short', limit: 5)).equals('short');
    });
  });
}
