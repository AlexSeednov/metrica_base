/// Kind of transition that made a screen visible.
enum ScreenViewTypeEnum {
  /// Forward navigation onto a new screen
  push('push'),

  /// Return to the previous screen
  pop('pop'),

  /// Replacement of the current screen
  replace('replace'),

  /// Switch of a tab
  tab('tab');

  ///
  const ScreenViewTypeEnum(this.value);

  /// Value for analytics (snake_case)
  final String value;
}
