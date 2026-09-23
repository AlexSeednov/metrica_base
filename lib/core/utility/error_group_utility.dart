/// Error grouping shared by every platform, so the same failure groups the
/// same way in AppMetrica and in Metrica.
abstract final class ErrorGroupUtility {
  /// The first line of [error] with every number replaced by `#`, cut to
  /// [limit]: the same failure with different ids in its text must not
  /// scatter into separate groups.
  static String groupId(String error, {required int limit}) {
    final String source = error
        .split('\n')
        .first
        .replaceAll(RegExp(r'\d+'), '#');

    return source.length <= limit ? source : source.substring(0, limit);
  }
}
