import 'package:dio/dio.dart';

import '../domain/achievement.dart';

class AchievementsApi {
  AchievementsApi(this._dio);

  final Dio _dio;

  /// The caller's badges: GET /achievements (a tier reached now comes back `fresh` once).
  Future<List<Achievement>> list() async {
    final j = (await _dio.get<Map<String, dynamic>>('/achievements')).data!;
    return [
      for (final a in (j['achievements'] as List).cast<Map<String, dynamic>>())
        ?Achievement.fromJson(a),
    ];
  }
}
