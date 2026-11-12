import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/log.dart';
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

  @override
  Future<String> submitLink(String url, {String? caption}) => apiCall(() async {
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
    return apiCall(() async {
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
  Future<Share> get(String id) => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>('/shares/$id')).data!;
    try {
      return _share(j);
    } catch (e) {
      log('shares: cannot read $id: $e; row=${logJson(j)}');
      rethrow;
    }
  });

  @override
  Future<void> retry(String id) =>
      apiCall(() => _dio.post<void>('/shares/$id/retry'));

  // A list scrolls rows out and back, and the detail page shows the same image: fetch each once per session.
  final _images = <String, Future<Uint8List?>>{};
  static const _imageCacheSize = 80;

  @override
  Future<Uint8List?> image(String id) {
    final cached = _images.remove(id);
    if (cached != null) {
      return _images[id] = cached; // re-insert = most recently used
    }
    if (_images.length >= _imageCacheSize) {
      _images.remove(_images.keys.first);
    }
    final f = _fetchImage(id);
    _images[id] = f;
    f.catchError((Object _) {
      _images.remove(id); // a failed fetch is tried again next time
      return null;
    });
    return f;
  }

  Future<Uint8List?> _fetchImage(String id) => apiCall(() async {
    // Through Dio, not Image.network: the request needs the token (and its refresh); R2 is private.
    final res = await _dio.get<List<int>>(
      '/shares/$id/image',
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (s) => s == 200 || s == 404,
      ),
    );
    return res.statusCode == 200 ? Uint8List.fromList(res.data!) : null;
  });

  @override
  Future<void> dismiss(String id) =>
      apiCall(() => _dio.delete<void>('/shares/$id'));

  @override
  Future<List<Share>> recent() => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>('/shares')).data!;
    final rows = j['shares'] as List;
    final shares = <Share>[];
    for (final s in rows) {
      try {
        shares.add(_share(s as Map<String, dynamic>));
      } catch (e) {
        log('shares: skipped row: $e; row=${logJson(s)}');
      }
    }
    log('shares: ${shares.length}/${rows.length} recent rows loaded');
    return shares;
  });

  static Share _share(Map<String, dynamic> j) => Share(
    id: j['id'] as String,
    status: j['status'] as String,
    kind: j['kind'] as String,
    placeId: j['placeId'] as String?,
    recipeId: j['recipeId'] as String?,
    gaps: [...(j['gaps'] as List? ?? const []).cast<String>()],
    error: j['error'] as String?,
    platform: j['platform'] as String?,
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
  );
}
