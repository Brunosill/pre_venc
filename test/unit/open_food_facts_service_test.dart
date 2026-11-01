import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pre_venc/features/product/data/services/open_food_facts_service.dart';

void main() {
  test('retorna dados quando produto existe', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'status': 1,
          'product': {
            'product_name': 'Leite Integral',
            'brands': 'Ninho',
            'ingredients_text': 'Leite integral',
            'nutriscore_grade': 'b',
          },
        }),
        200,
      );
    });

    final service = OpenFoodFactsService(client: mockClient);
    final result = await service.lookup('7891000315507');

    expect(result, isNotNull);
    expect(result!['name'], 'Leite Integral');
    expect(result['brand'], 'Ninho');
    expect(result['source'], 'openfoodfacts');
  });

  test('retorna null quando produto não existe (status 0)', () async {
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode({'status': 0}), 200);
    });

    final service = OpenFoodFactsService(client: mockClient);
    final result = await service.lookup('0000000000000');

    expect(result, isNull);
  });

  test('retorna null em erro HTTP', () async {
    final mockClient = MockClient((request) async {
      return http.Response('Internal error', 500);
    });

    final service = OpenFoodFactsService(client: mockClient);
    final result = await service.lookup('123');

    expect(result, isNull);
  });

  test('retorna null quando conexão falha', () async {
    final mockClient = MockClient((request) async {
      throw Exception('Sem internet');
    });

    final service = OpenFoodFactsService(client: mockClient);
    final result = await service.lookup('123');

    expect(result, isNull);
  });
}