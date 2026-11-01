import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pre_venc/features/product/data/models/barcode_cache_model.dart';
import 'package:pre_venc/features/product/data/services/barcode_cache_service.dart';

import '../helpers/hive_test_helper.dart';

void main() {
  late Box<BarcodeCacheModel> box;
  late BarcodeCacheService cache;

  setUpAll(() async {
    Hive.registerAdapter(BarcodeCacheModelAdapter());
    await HiveTestHelper.setUp();
  });

  setUp(() async {
    box = await Hive.openBox<BarcodeCacheModel>('test_cache');
    cache = BarcodeCacheService(box);
  });

  tearDown(() async {
    await box.close();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  test('retorna null para barcode inexistente', () async {
    expect(await cache.get('000'), isNull);
  });

  test('salva e recupera do cache', () async {
    await cache.put('123', {
      'name': 'Leite',
      'brand': 'Ninho',
      'category': 'food',
      'source': 'openfoodfacts',
    });

    final result = await cache.get('123');
    expect(result, isNotNull);
    expect(result!['name'], 'Leite');
    expect(result['brand'], 'Ninho');
    expect(result['source'], 'cache_local');
  });

  test('cache expirado é removido ao consultar', () async {
    final old = BarcodeCacheModel(
      barcode: '999',
      name: 'Antigo',
      fetchedAt: DateTime.now().subtract(const Duration(days: 31)),
    );
    await box.put('999', old);

    final result = await cache.get('999');
    expect(result, isNull);
    expect(box.get('999'), isNull);
  });

  test('cache com 29 dias ainda é válido', () async {
    final recent = BarcodeCacheModel(
      barcode: '888',
      name: 'Recente',
      fetchedAt: DateTime.now().subtract(const Duration(days: 29)),
    );
    await box.put('888', recent);

    final result = await cache.get('888');
    expect(result, isNotNull);
    expect(result!['name'], 'Recente');
  });
}