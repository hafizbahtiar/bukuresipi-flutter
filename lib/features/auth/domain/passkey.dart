/// One passkey of this account (GET /auth/passkeys). [name] is the phone's name when it was made; the key itself
/// stays in that phone's password manager, the API holds only its public half.
class Passkey {
  const Passkey({
    required this.id,
    required this.createdAt,
    this.name,
    this.lastUsedAt,
  });

  factory Passkey.fromJson(Map<String, dynamic> j) => Passkey(
    id: j['id'] as String,
    name: j['name'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
    lastUsedAt: switch (j['lastUsedAt']) {
      final String s => DateTime.parse(s).toLocal(),
      _ => null,
    },
  );

  final String id;
  final String? name;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
}
