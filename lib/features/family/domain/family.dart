/// shortcut: the cap before the API has told us (no family yet), kept equal to hono FAMILY_MAX; once plans exist,
/// read it from an endpoint instead.
const familyMaxFallback = 3;

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
    this.maxMembers = familyMaxFallback,
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

  /// How many people the family can hold (the API's FAMILY_MAX now, a plan later), the caller included.
  final int maxMembers;

  bool get isFull => members.length >= maxMembers;
  bool get isOwner => role == 'owner';
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    required this.isMe,
    this.avatar,
  });

  final String id;
  final String? name;

  /// Profile picture id (AuthController.avatar), null = none.
  final String? avatar;
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
    this.maxMembers = familyMaxFallback,
  });

  final String familyName;
  final String? ownerName;
  final int memberCount;
  final int maxMembers;

  bool get isFull => memberCount >= maxMembers;
}
