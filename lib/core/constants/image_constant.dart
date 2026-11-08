/// Every image asset the app draws, by what it is (folders are listed under `flutter: assets:` in pubspec.yaml).
abstract final class ImageConstant {
  /// The app icon (the website logo), on the sign-in cover.
  static const appIcon = 'assets/brand/icon.png';

  /// Google's "G", on the Continue with Google button.
  static const googleLogo = 'assets/brand/google_g.png';

  /// The cooking drawing for a recipe with no photo (book rows, home cards).
  static const recipePlaceholder = 'assets/images/recipe_placeholder.png';

  static const all = [appIcon, googleLogo, recipePlaceholder];
}
