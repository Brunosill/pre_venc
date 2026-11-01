import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../../core/utils/hive_boxes.dart';
import '../../data/models/barcode_cache_model.dart';
import '../../data/services/barcode_cache_service.dart';
import '../../data/services/barcode_lookup_orchestrator.dart';
import '../../data/services/medicamentos_api_service.dart';
import '../../data/services/open_beauty_facts_service.dart';
import '../../data/services/open_food_facts_service.dart';

final barcodeCacheBoxProvider =
    Provider<Box<BarcodeCacheModel>>((ref) => HiveBoxes.barcodeCacheBox);

final barcodeCacheServiceProvider = Provider<BarcodeCacheService>((ref) {
  return BarcodeCacheService(ref.watch(barcodeCacheBoxProvider));
});

final medicamentosApiKeyProvider =
    Provider<String>((ref) => const String.fromEnvironment('MEDICAMENTOS_API_KEY'));

final barcodeOrchestratorProvider = Provider<BarcodeLookupOrchestrator>((ref) {
  return BarcodeLookupOrchestrator(
    cache: ref.watch(barcodeCacheServiceProvider),
    food: OpenFoodFactsService(),
    beauty: OpenBeautyFactsService(),
    medicamentos: MedicamentosApiService(
      apiKey: ref.watch(medicamentosApiKeyProvider),
    ),
  );
});