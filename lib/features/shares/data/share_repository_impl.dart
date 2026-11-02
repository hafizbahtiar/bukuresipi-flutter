import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/share.dart';
import '../domain/share_repository.dart';

class ShareRepositoryImpl implements ShareRepository {
  ShareRepositoryImpl(this._dio);

  final Dio _dio;

  /// What the API accepts (bukuresipi-hono shares/service.ts IMAGE_TYPES, MAX_IMAGE_BYTES).
  static const _types = {
    'jpg': 'jpeg',
    'jpeg': 'jpeg',
    'png': 'png',
    'webp': 'webp',
  };
  static const maxImageBytes = 5 * 1024 * 1024;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<String> submitLink(String url, {String? caption}) => _call(() async {
    final body = {
      'url': url,
      if (caption != null && caption.trim().isNotEmpty)
        'caption': caption.trim().length > 4000
            ? caption.trim().substring(0, 4000)
            : caption.trim(),
    };
    return (await _dio.post<Map<String, dynamic>>(
          '/shares',
          data: body,
        )).data!['id']
        as String;
  });

  @override
  Future<String> submitImage(String path) async {
    final subtype = _types[path.split('.').last.toLowerCase()];
    if (subtype == null) throw const ApiException('invalid_image');
    final file = File(path);
    if (await file.length() > maxImageBytes) {
      throw const ApiException('invalid_image');
    }
    return _call(() async {
      final form = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          path,
          contentType: DioMediaType('image', subtype),
        ),
      });
      return (await _dio.post<Map<String, dynamic>>(
            '/shares',
            data: form,
          )).data!['id']
          as String;
    });
  }

  @override
  Future<Share> get(String id) => _call(
    () async =>
        _share((await _dio.get<Map<String, dynamic>>('/shares/$id')).data!),
  );

  @override
  Future<List<Share>> recent() => _call(() async {
    final j = (await _dio.get<Map<String, dynamic>>('/shares')).data!;
    return [
      for (final s in j['shares'] as List) _share(s as Map<String, dynamic>),
    ];
  });

  static Share _share(Map<String, dynamic> j) => Share(
    id: j['id'] as String,
    status: j['status'] as String,
    kind: j['kind'] as String,
    restaurantId: j['restaurantId'] as String?,
    gaps: [...(j['gaps'] as List? ?? const []).cast<String>()],
    error: j['error'] as String?,
  );
}
