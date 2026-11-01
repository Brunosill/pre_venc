import '../../domain/entities/product_category.dart';
import 'barcode_cache_service.dart';
import 'medicamentos_api_service.dart';
import 'open_beauty_facts_service.dart';
import 'open_food_facts_service.dart';

class BarcodeLookupOrchestrator {
  final BarcodeCacheService cache;
  final OpenFoodFactsService food;
  final OpenBeautyFactsService beauty;
  final MedicamentosApiService medicamentos;

  BarcodeLookupOrchestrator({
    required this.cache,
    required this.food,
    required this.beauty,
    required this.medicamentos,
  });

  /// Consulta automática sem precisar de categoria.
  /// Ordem: cache → (futuro Supabase) → OFF → OBF → medicamentos.
  ///
  /// O `category` no retorno indica qual base respondeu.
  Future<Map<String, dynamic>?> lookupAuto(String barcode) async {
    // 1. Cache local (Hive)
    final cached = await cache.get(barcode);
    if (cached != null) return cached;

    // 2. TODO Sprint 7C: catálogo próprio no Supabase
    // final remote = await remoteCatalog.lookup(barcode);
    // if (remote != null) {
    //   await cache.put(barcode, remote);
    //   return remote;
    // }

    // 3. Open Food Facts (alimentos — maior base, sem quota)
    final foodResult = await food.lookup(barcode);
    if (foodResult != null) {
      await cache.put(barcode, foodResult);
      return foodResult;
    }

    // 4. Open Beauty Facts (beleza — sem quota)
    final beautyResult = await beauty.lookup(barcode);
    if (beautyResult != null) {
      await cache.put(barcode, beautyResult);
      return beautyResult;
    }

    // 5. medicamentos.api.br (com quota — só se as anteriores falharem)
    final medResult = await medicamentos.lookup(barcode);
    if (medResult != null) {
      await cache.put(barcode, medResult);
      return medResult;
    }

    return null;
  }

  /// Consulta por categoria específica (útil quando a UI já sabe o tipo).
  Future<Map<String, dynamic>?> lookupByCategory(
    String barcode,
    ProductCategory category,
  ) async {
    final cached = await cache.get(barcode);
    if (cached != null) return cached;

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
    }
    return result;
  }
}