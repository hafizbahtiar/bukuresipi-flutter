import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/family/domain/family.dart';
import 'package:bukuresipi_flutter/features/family/domain/family_repository.dart';

const me = FamilyMember(id: 'u-1', name: 'Ali', role: 'owner', isMe: true);
const siti = FamilyMember(id: 'u-2', name: 'Siti', role: 'member', isMe: false);

Family aFamily({
  String name = 'Rumah Ali',
  List<FamilyMember> members = const [me, siti],
}) => Family(
  id: 'f-1',
  name: name,
  role: 'owner',
  members: members,
  createdBy: 'Hafiz',
  createdAt: DateTime(2026, 11, 5),
);

class FakeFamily implements FamilyRepository {
  Family? current;
  String? joinError; // an ApiException code join throws
  String? membership; // what preview says: 'this', 'other' or null
  final joined = <String>[];
  int invites = 0;

  @override
  Future<Family?> get() async => current;

  @override
  Future<Family> create(String name) async =>
      current = aFamily(name: name, members: const [me]);

  @override
  Future<Family> rename(String name) async => current = aFamily(name: name);

  @override
  Future<({String url, DateTime expiresAt})> invite() async {
    invites++;
    return (
      url: 'https://bukuresipi.com/family/join?t=abc',
      expiresAt: DateTime.utc(2026, 11, 12),
    );
  }

  @override
  Future<void> stopInvite() async {}

  @override
  Future<InvitePreview> preview(String token) async {
    if (token != 'abc' && token != 'full') {
      throw const ApiException('invite_expired', status: 410);
    }
    return InvitePreview(
      familyName: 'Rumah Ali',
      ownerName: 'Ali',
      memberCount: token == 'full' ? 3 : 2,
      maxMembers: 3,
      membership: membership,
    );
  }

  @override
  Future<Family> join(String token) async {
    if (joinError != null) throw ApiException(joinError!);
    joined.add(token);
    return current = aFamily();
  }

  @override
  Future<void> leave() async => current = null;

  @override
  Future<void> removeMember(String userId) async =>
      current = aFamily(members: const [me]);

  @override
  Future<Family> handOver(String userId) async => current = aFamily();
}
