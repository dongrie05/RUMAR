import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/agent_service.dart';
import 'package:mobile/services/route_service.dart';

void main() {
  test(
    'Google Routes envia as paragens ao gateway e interpreta a resposta',
    () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://example.test/routes');
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer user-token');
        expect(request.headers['apikey'], 'publishable-key');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect((body['stops'] as List).length, 2);
        return http.Response(
          jsonEncode({
            'durationSeconds': 840,
            'distanceMeters': 6200,
            'encodedPolyline': 'abc',
          }),
          200,
        );
      });
      final service = GoogleRoutesService(
        client: client,
        endpoint: 'https://example.test/routes',
        accessToken: 'user-token',
        anonKey: 'publishable-key',
      );
      final result = await service.calculate(const [
        RouteStop(id: 'a', latitude: 38.72, longitude: -9.14),
        RouteStop(id: 'b', latitude: 38.74, longitude: -9.16),
      ]);

      expect(result?.durationSeconds, 840);
      expect(result?.distanceMeters, 6200);
      expect(result?.encodedPolyline, 'abc');
    },
  );

  test('Google Routes falha de forma segura sem configuração', () async {
    final service = GoogleRoutesService(endpoint: '');
    expect(
      await service.calculate(const [
        RouteStop(id: 'a', latitude: 0, longitude: 0),
        RouteStop(id: 'b', latitude: 1, longitude: 1),
      ]),
      isNull,
    );
  });

  test('gateway de IA envia autenticação e interpreta o trabalho', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      expect(request.headers['apikey'], 'publishable-key');
      return http.Response(
        jsonEncode({
          'job': {'id': 'job-1', 'kind': 'daily_plan', 'status': 'queued'},
        }),
        202,
      );
    });
    final service = AgentService(
      client: client,
      gatewayUrl: 'https://example.test/agent',
      anonKey: 'publishable-key',
    );
    final job = await service.enqueue(
      accessToken: 'token',
      kind: 'daily_plan',
      input: const {'text': 'Organiza o dia'},
    );

    expect(job.id, 'job-1');
    expect(job.kind, 'daily_plan');
    expect(job.status, 'queued');
  });

  test('gateway de IA apresenta erro útil quando o serviço falha', () async {
    final service = AgentService(
      client: MockClient((_) async => http.Response('{}', 500)),
      gatewayUrl: 'https://example.test/agent',
    );
    expect(
      () => service.enqueue(
        accessToken: 'token',
        kind: 'daily_plan',
        input: const {},
      ),
      throwsA(isA<Exception>()),
    );
  });
}
