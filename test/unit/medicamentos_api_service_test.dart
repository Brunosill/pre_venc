import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pre_venc/features/product/data/services/medicamentos_api_service.dart';

void main() {
  test('retorna null se apiKey não configurada', () async {
    final service = MedicamentosApiService(apiKey: null);
    expect(service.isConfigured, isFalse);
    expect(await service.lookup('123'), isNull);
  });

  test('retorna null em 429 (cota esgotada)', () async {
    final mockClient = MockClient((request) async {
      return http.Response('Too many requests', 429);
    });

    final service =
        MedicamentosApiService(apiKey: 'abc', client: mockClient);
    final result = await service.lookup('123');

    expect(result, isNull);
  });

  test('retorna dados quando produto existe', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'nomeComercial': 'Dipirona Sódica',
          'laboratorio': 'Medley',
        }),
        200,
      );
    });

    final service =
        MedicamentosApiService(apiKey: 'abc', client: mockClient);
    final result = await service.lookup('7891234567890');

    expect(result, isNotNull);
    expect(result!['name'], 'Dipirona Sódica');
    expect(result['brand'], 'Medley');
    expect(result['source'], 'medicamentos_api');
  });

  test('envia o header X-API-Key', () async {
    String? receivedKey;
    final mockClient = MockClient((request) async {
      receivedKey = request.headers['X-API-Key'];
      return http.Response('{}', 200);
    });

    final service =
        MedicamentosApiService(apiKey: 'minha_chave_123', client: mockClient);
    await service.lookup('123');

    expect(receivedKey, 'minha_chave_123');
  });
}