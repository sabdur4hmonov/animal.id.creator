import 'dart:convert';
import 'dart:io';

import 'package:biolivestock_capture/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'registry requests carry authentication, exact JSON and stable key',
    () async {
      final api = ApiClient(
        token: 'synthetic',
        baseUrl: 'http://canonical/',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer synthetic');
          expect(
            request.url.toString(),
            'http://canonical/api/v1/registry/animals',
          );
          if (request.method == 'GET') return http.Response('[]', 200);
          expect(request.headers['Idempotency-Key'], 'a' * 32);
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {'species': 'cattle'});
          return http.Response('{"animal_id":"M00000001"}', 201);
        }),
      );
      expect(await api.registryGet('/api/v1/registry/animals'), isEmpty);
      expect(
        (await api.registryPost('/api/v1/registry/animals', {
          'species': 'cattle',
        }, 'a' * 32))['animal_id'],
        'M00000001',
      );
      api.close();
    },
  );
  test(
    'registry error exposes typed conflict and missing credential fails before sending',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('{"detail":"Version changed"}', 409);
      });
      final api = ApiClient(token: 'synthetic', client: client);
      await expectLater(
        api.registryPost('/api/v1/registry/animals', {}, 'b' * 32),
        throwsA(isA<RegistryApiError>().having((e) => e.status, 'status', 409)),
      );
      final unconfigured = ApiClient(token: '', client: client);
      await expectLater(
        unconfigured.registryGet('/api/v1/registry/animals'),
        throwsException,
      );
      expect(calls, 1);
      api.close();
    },
  );
  test('legacy backend is rejected before sending any queued image', () async {
    final calls = <String>[];
    final api = ApiClient(
      token: 'synthetic',
      client: MockClient((request) async {
        calls.add(request.method);
        return http.Response('{"status":"ok","database":"ok"}', 200);
      }),
    );
    await expectLater(
      api.upload('does-not-exist.jpg', {}, 'a'.padRight(32, 'a')),
      throwsException,
    );
    expect(calls, ['GET']);
    api.close();
  });

  test(
    'supported backend receives stable key and capture metadata on retry',
    () async {
      final root = await Directory.systemTemp.createTemp('capture_api_test');
      try {
        final image = File('${root.path}/original.jpg');
        await image.writeAsBytes([1, 2, 3]);
        final keys = <String>[];
        final api = ApiClient(
          token: 'synthetic',
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                '{"capabilities":{"idempotent_capture_uploads":true}}',
                200,
              );
            }
            keys.add(request.headers['Idempotency-Key']!);
            expect(request.body.contains('"animal_id":"F01-C001"'), isTrue);
            expect(request.headers['Authorization'], 'Bearer synthetic');
            return http.Response(jsonEncode({'id': 'same-capture'}), 201);
          }),
        );
        final key = 'b'.padRight(32, 'b');
        for (var attempt = 0; attempt < 2; attempt++) {
          expect(await api.upload(image.path, {'animal_id': 'F01-C001'}, key), {
            'id': 'same-capture',
          });
        }
        expect(keys, [key, key]);
        api.close();
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
