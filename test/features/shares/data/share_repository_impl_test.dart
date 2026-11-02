import 'dart:io';

import 'package:bukuresipi_flutter/core/network/api_client.dart';
import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/core/storage/token_store.dart';
import 'package:bukuresipi_flutter/features/shares/data/share_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes.dart';

void main() {
  late FakeAdapter adapter;
  ShareRepositoryImpl make((int, Object?) Function(RequestOptions) answer) {
    adapter = FakeAdapter(answer);
    final api = ApiClient(
      baseUrl: 'https://api.test',
      tokens: MemoryTokenStore(const Tokens(access: 'a', refresh: 'r')),
      appVersion: '1.0.0',
      adapter: adapter,
    );
    return ShareRepositoryImpl(api.dio);
  }

  test('a link is posted as JSON and the share id comes back', () async {
    final repo = make((_) => (202, {'id': 's-1', 'status': 'pending'}));
    expect(await repo.submitLink('https://www.tiktok.com/@a/video/1'), 's-1');
    expect(adapter.requests.single.path, '/shares');
    expect(adapter.requests.single.data, {
      'url': 'https://www.tiktok.com/@a/video/1',
    });
  });

  test(
    'the caption read on the phone goes along, capped at 4000 characters',
    () async {
      final repo = make((_) => (202, {'id': 's-1', 'status': 'pending'}));
      await repo.submitLink('https://vt.tiktok.com/ZS1/', caption: 'a' * 5000);
      expect((adapter.requests.single.data as Map)['caption'], hasLength(4000));
    },
  );

  test('an image is posted as multipart field "image" with its type', () async {
    final file = File('${Directory.systemTemp.createTempSync().path}/shot.PNG')
      ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47]);
    final repo = make((_) => (202, {'id': 's-2', 'status': 'pending'}));
    expect(await repo.submitImage(file.path), 's-2');
    final form = adapter.requests.single.data as FormData;
    expect(form.files.single.key, 'image');
    expect(form.files.single.value.contentType.toString(), 'image/png');
  });

  test('HEIC or other formats are refused before uploading', () async {
    final repo = make((_) => (202, {}));
    await expectLater(
      repo.submitImage('/tmp/photo.heic'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_image'),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('status is read into a Share', () async {
    final repo = make(
      (_) => (
        200,
        {
          'id': 's-1',
          'status': 'done',
          'kind': 'restaurant',
          'restaurantId': 'r-1',
          'gaps': <String>[],
          'error': null,
        },
      ),
    );
    final s = await repo.get('s-1');
    expect(
      [s.status, s.kind, s.restaurantId, s.isFinished],
      ['done', 'restaurant', 'r-1', true],
    );
  });

  test('recent: the last day of shares, as the book shows them', () async {
    final repo = make(
      (_) => (
        200,
        {
          'shares': [
            {
              'id': 's-2',
              'status': 'processing',
              'kind': 'unknown',
              'restaurantId': null,
              'gaps': [],
              'error': null,
              'platform': 'tiktok',
            },
            {
              'id': 's-1',
              'status': 'done',
              'kind': 'other',
              'restaurantId': null,
              'gaps': ['unreadable'],
              'error': null,
              'platform': 'tiktok',
            },
          ],
        },
      ),
    );
    final list = await repo.recent();
    expect(adapter.requests.single.path, '/shares');
    expect(
      [for (final s in list) (s.id, s.isFinished, s.couldNotRead)],
      [('s-2', false, false), ('s-1', true, true)],
    );
  });
}
