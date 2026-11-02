import '../../domain/entities/product_category.dart';
import 'barcode_cache_service.dart';
import 'medicamentos_api_service.dart';
import 'open_beauty_facts_service.dart';
import 'open_food_facts_service.dart';
import 'remote_catalog_service.dart';

class BarcodeLookupOrchestrator {
  final BarcodeCacheService cache;
  final RemoteCatalogService? remote;
  final OpenFoodFactsService food;
  final OpenBeautyFactsService beauty;
  final MedicamentosApiService medicamentos;

  BarcodeLookupOrchestrator({
    required this.cache,
    this.remote,
    required this.food,
    required this.beauty,
    required this.medicamentos,
  });

  /// Cascata: Hive → Supabase → OFF → OBF → medicamentos.
  /// Toda consulta externa bem-sucedida é publicada no cache remoto
  /// (fire-and-forget, sem bloquear o usuário).
  Future<Map<String, dynamic>?> lookupAuto(String barcode) async {
    // 1. Cache local (Hive)
    final cached = await cache.get(barcode);
    if (cached != null) return cached;

    // 2. Catálogo colaborativo (Supabase)
    if (remote != null) {
      final remoteResult = await remote!.lookup(barcode);
      if (remoteResult != null) {
        // Popular o Hive para próximas consultas offline
        await cache.put(barcode, remoteResult);
        return remoteResult;
      }
    }

    // 3. Open Food Facts (alimentos — maior base, sem quota)
    final foodResult = await food.lookup(barcode);
    if (foodResult != null) {
      await cache.put(barcode, foodResult);
      _publishInBackground(barcode, foodResult);
      return foodResult;
    }

    // 4. Open Beauty Facts (beleza — sem quota)
    final beautyResult = await beauty.lookup(barcode);
    if (beautyResult != null) {
      await cache.put(barcode, beautyResult);
      _publishInBackground(barcode, beautyResult);
      return beautyResult;
    }

    // 5. medicamentos.api.br (com quota — só se as anteriores falharem)
    final medResult = await medicamentos.lookup(barcode);
    if (medResult != null) {
      await cache.put(barcode, medResult);
      _publishInBackground(barcode, medResult);
      return medResult;
    }

    return null;
  }

  /// Consulta por categoria específica (mantido para uso futuro).
  Future<Map<String, dynamic>?> lookupByCategory(
    String barcode,
    ProductCategory category,
  ) async {
    final cached = await cache.get(barcode);
    if (cached != null) return cached;

    if (remote != null) {
      final remoteResult = await remote!.lookup(barcode);
      if (remoteResult != null) {
        await cache.put(barcode, remoteResult);
        return remoteResult;
      }
    }

    Map<String, dynamic>? result;
    switch (category) {
      case ProductCategory.food:
        result = await food.lookup(barcode);
        break;
      case ProductCategory.medicine:
        result = await medicamentos.lookup(barcode);
        break;
      case ProductCategory.beauty:
        result = await beauty.lookup(barcode);
        break;
    }

    if (result != null) {
      await cache.put(barcode, result);
      _publishInBackground(barcode, result);
    }
    return result;
  }

  /// Publica no Supabase sem aguardar (o usuário não deve esperar).
  void _publishInBackground(String barcode, Map<String, dynamic> data) {
    final r = remote;
    if (r == null) return;
    // fire-and-forget
    // ignore: discarded_futures
    r.publishToCache(barcode, data);
  }
}
