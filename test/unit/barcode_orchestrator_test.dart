import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pre_venc/features/product/data/services/barcode_cache_service.dart';
import 'package:pre_venc/features/product/data/services/barcode_lookup_orchestrator.dart';
import 'package:pre_venc/features/product/data/services/medicamentos_api_service.dart';
import 'package:pre_venc/features/product/data/services/open_beauty_facts_service.dart';
import 'package:pre_venc/features/product/data/services/open_food_facts_service.dart';

class MockCache extends Mock implements BarcodeCacheService {}
class MockFood extends Mock implements OpenFoodFactsService {}
class MockBeauty extends Mock implements OpenBeautyFactsService {}
class MockMedicamentos extends Mock implements MedicamentosApiService {}

void main() {
  late MockCache cache;
  late MockFood food;
  late MockBeauty beauty;
  late MockMedicamentos medicamentos;
  late BarcodeLookupOrchestrator orchestrator;

  setUp(() {
    cache = MockCache();
    food = MockFood();
    beauty = MockBeauty();
    medicamentos = MockMedicamentos();
    orchestrator = BarcodeLookupOrchestrator(
      cache: cache,
      food: food,
      beauty: beauty,
      medicamentos: medicamentos,
    );
  });

  group('lookupAuto', () {
    test('usa cache local quando disponível', () async {
      when(() => cache.get('123'))
          .thenAnswer((_) async => {'name': 'Do Cache'});

      final result = await orchestrator.lookupAuto('123');

      expect(result?['name'], 'Do Cache');
      verify(() => cache.get('123')).called(1);
      verifyNever(() => food.lookup(any()));
      verifyNever(() => beauty.lookup(any()));
      verifyNever(() => medicamentos.lookup(any()));
    });

    test('consulta Open Food Facts se cache vazio', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123'))
          .thenAnswer((_) async => {'name': 'Leite', 'source': 'off'});
      when(() => cache.put('123', any())).thenAnswer((_) async {});

      final result = await orchestrator.lookupAuto('123');

      expect(result?['name'], 'Leite');
      verify(() => food.lookup('123')).called(1);
      verifyNever(() => beauty.lookup(any()));
      verifyNever(() => medicamentos.lookup(any()));
      verify(() => cache.put('123', any())).called(1);
    });

    test('consulta Open Beauty se alimento falhar', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123')).thenAnswer((_) async => null);
      when(() => beauty.lookup('123'))
          .thenAnswer((_) async => {'name': 'Shampoo', 'source': 'obf'});
      when(() => cache.put('123', any())).thenAnswer((_) async {});

      final result = await orchestrator.lookupAuto('123');

      expect(result?['name'], 'Shampoo');
      verify(() => food.lookup('123')).called(1);
      verify(() => beauty.lookup('123')).called(1);
      verifyNever(() => medicamentos.lookup(any()));
    });

    test('medicamentos é última opção', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123')).thenAnswer((_) async => null);
      when(() => beauty.lookup('123')).thenAnswer((_) async => null);
      when(() => medicamentos.lookup('123'))
          .thenAnswer((_) async => {'name': 'Dipirona', 'source': 'med'});
      when(() => cache.put('123', any())).thenAnswer((_) async {});

      final result = await orchestrator.lookupAuto('123');

      expect(result?['name'], 'Dipirona');
      verify(() => food.lookup('123')).called(1);
      verify(() => beauty.lookup('123')).called(1);
      verify(() => medicamentos.lookup('123')).called(1);
    });

    test('retorna null quando nenhuma fonte encontra', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123')).thenAnswer((_) async => null);
      when(() => beauty.lookup('123')).thenAnswer((_) async => null);
      when(() => medicamentos.lookup('123')).thenAnswer((_) async => null);

      final result = await orchestrator.lookupAuto('123');

      expect(result, isNull);
      verifyNever(() => cache.put(any(), any()));
    });
  });
}