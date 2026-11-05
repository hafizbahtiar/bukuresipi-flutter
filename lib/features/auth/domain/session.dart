/// One signed-in device of this account (GET /auth/sessions). [id] is the session id, used to sign it out.
/// Every label is what that phone said at sign-in (or the API saw on its last refresh): null when unknown.
class Session {
  const Session({
    required this.id,
    required this.current,
    required this.createdAt,
    required this.lastUsedAt,
    this.deviceName,
    this.deviceModel,
    this.osVersion,
    this.appVersion,
    this.location,
    this.platform,
  });

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    id: j['id'] as String,
    current: j['current'] == true,
    createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
    lastUsedAt: DateTime.parse(j['lastUsedAt'] as String).toLocal(),
    deviceName: j['deviceName'] as String?,
    deviceModel: j['deviceModel'] as String?,
    osVersion: j['osVersion'] as String?,
    appVersion: j['appVersion'] as String?,
    location:
        j['location']
            as String?, // Cloudflare's city, country for the IP: approximate
    platform: j['platform'] as String?, // 'android' | 'ios' | 'web'
  );

  final String id;
  final bool current;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final String? deviceName;
  final String? deviceModel;
  final String? osVersion;
  final String? appVersion;
  final String? location;
  final String? platform;
}
