/// The signed-in account. [id] is the public UUID; the API never sends internal ids.
class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.lang,
    required this.emailVerified,
    this.hasPassword = true,
    this.google = false,
    this.avatar,
    this.kcalTarget,
  });

  final String id;
  final String email;
  final String? name;
  final String role; // 'user' | 'owner'
  final String lang; // 'ms' | 'en'
  final bool emailVerified;

  /// false = Google-only: no password yet ("Set a password" sends the reset link; changing the email needs one).
  final bool hasPassword;

  /// Signed in with Google at least once (linked).
  final bool google;

  /// Profile picture id (AuthRepository.avatar); changes on every upload. null = none.
  final String? avatar;

  /// The daily calorie target the user set (Receipts); null = none.
  final int? kcalTarget;

  bool get isOwner => role == 'owner';
}
