import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/family.dart';
import '../domain/family_repository.dart';

class FamilyRepositoryImpl implements FamilyRepository {
  FamilyRepositoryImpl(this._dio);

  final Dio _dio;

  Future<Family> _family(Future<Response<Map<String, dynamic>>> req) async =>
      familyFromJson((await req).data!['family'] as Map<String, dynamic>);

  @override
  Future<Family?> get() => apiCall(() async {
    final f = (await _dio.get<Map<String, dynamic>>('/family')).data!['family'];
    return f == null ? null : familyFromJson(f as Map<String, dynamic>);
  });

  @override
  Future<Family> create(String name) => apiCall(
    () => _family(
      _dio.post<Map<String, dynamic>>('/family', data: {'name': name}),
    ),
  );

  @override
  Future<Family> rename(String name) => apiCall(
    () => _family(
      _dio.patch<Map<String, dynamic>>('/family', data: {'name': name}),
    ),
  );

  @override
  Future<({String url, DateTime expiresAt})> invite() => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>('/family/invite')).data!;
    return (
      url: j['url'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (j['expiresAt'] as num).toInt(),
      ),
    );
  });

  @override
  Future<void> stopInvite() =>
      apiCall(() => _dio.delete<void>('/family/invite'));

  @override
  Future<InvitePreview> preview(String token) => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>(
      '/family/invites/${Uri.encodeComponent(token)}',
    )).data!;
    return InvitePreview(
      familyName: j['familyName'] as String,
      ownerName: j['ownerName'] as String?,
      memberCount: (j['memberCount'] as num).toInt(),
      maxMembers: (j['maxMembers'] as num?)?.toInt() ?? familyMaxFallback,
    );
  });

  @override
  Future<Family> join(String token) => apiCall(
    () => _family(
      _dio.post<Map<String, dynamic>>('/family/join', data: {'token': token}),
    ),
  );

  @override
  Future<void> leave() => apiCall(() => _dio.post<void>('/family/leave'));

  @override
  Future<void> removeMember(String userId) =>
      apiCall(() => _dio.delete<void>('/family/members/$userId'));

  @override
  Future<Family> handOver(String userId) => apiCall(
    () => _family(
      _dio.post<Map<String, dynamic>>(
        '/family/owner',
        data: {'userId': userId},
      ),
    ),
  );
}

Family familyFromJson(Map<String, dynamic> j) {
  final invite = j['invite'] as Map<String, dynamic>?;
  final creator = j['createdBy'] as Map<String, dynamic>?;
  final created = j['createdAt'] as String?;

  return Family(
    id: j['id'] as String,
    name: j['name'] as String,
    role: j['role'] as String,
    createdBy: creator?['name'] as String?,
    creatorIsMe: creator?['isMe'] == true,
    maxMembers: (j['maxMembers'] as num?)?.toInt() ?? familyMaxFallback,
    // D1 datetime ("2026-11-05 10:00:00") is UTC with no zone mark.
    createdAt: created == null
        ? null
        : DateTime.tryParse('${created.replaceFirst(' ', 'T')}Z')?.toLocal(),
    members: [
      for (final m in (j['members'] as List).cast<Map<String, dynamic>>())
        FamilyMember(
          id: m['id'] as String,
          name: m['name'] as String?,
          role: m['role'] as String,
          isMe: m['isMe'] as bool,
          avatar: m['avatar'] as String?,
        ),
    ],
    inviteExpiresAt: invite == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (invite['expiresAt'] as num).toInt(),
          ),
  );
}
