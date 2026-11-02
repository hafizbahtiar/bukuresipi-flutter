/// The signed-in account. [id] is the public UUID; the API never sends internal ids.
class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.lang,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final String? name;
  final String role; // 'user' | 'owner'
  final String lang; // 'ms' | 'en'
  final bool emailVerified;

  bool get isOwner => role == 'owner';
}
