/// A household sharing one book. [role] is the caller's. Members are shown by name, never email.
class Family {
  const Family({
    required this.id,
    required this.name,
    required this.role,
    required this.members,
    this.inviteExpiresAt,
    this.createdBy,
    this.creatorIsMe = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String role; // 'owner' | 'member'
  final List<FamilyMember> members;

  /// Owner only: until when the current invite link works (null = no live link). The link itself is shown once.
  final DateTime? inviteExpiresAt;

  /// "Created by Ali": kept after Ali leaves (like WhatsApp). Null = that account was deleted, or unknown.
  final String? createdBy;
  final bool creatorIsMe;
  final DateTime? createdAt;

  bool get isOwner => role == 'owner';
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    required this.isMe,
  });

  final String id;
  final String? name;
  final String role;
  final bool isMe;

  bool get isOwner => role == 'owner';
}

/// What a join link shows before joining.
class InvitePreview {
  const InvitePreview({
    required this.familyName,
    required this.ownerName,
    required this.memberCount,
  });

  final String familyName;
  final String? ownerName;
  final int memberCount;
}
