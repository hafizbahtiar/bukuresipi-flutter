import 'family.dart';

/// /api/v1/family. Every method throws ApiException (core/network) on failure; codes the app handles:
/// name_required, already_in_family, family_full, invite_expired (410), not_owner.
abstract interface class FamilyRepository {
  /// null = not in a family.
  Future<Family?> get();
  Future<Family> create(String name);
  Future<Family> rename(String name);

  /// A new link (the old one stops working). The URL is only in this answer.
  Future<({String url, DateTime expiresAt})> invite();
  Future<void> stopInvite();
  Future<InvitePreview> preview(String token);
  Future<Family> join(String token);
  Future<void> leave();
  Future<void> removeMember(String userId);
  Future<Family> handOver(String userId);
}
