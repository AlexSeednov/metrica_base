/// Error grouping for the external reporting systems — one rule for every
/// platform, so the same failure is glued together the same way in AppMetrica
/// and in Metrica.
abstract final class ErrorGroupUtility {
  /// Group identifier: the first line of the message with the numeric values
  /// stripped — otherwise the same failure with different identifiers in its
  /// text scatters into separate records.
  static String groupId(String error, {required int limit}) {
    final String source = error
        .split('\n')
        .first
        .replaceAll(RegExp(r'\d+'), '#');

    return source.length <= limit ? source : source.substring(0, limit);
  }
}
