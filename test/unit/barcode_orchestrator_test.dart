import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pre_venc/features/product/data/services/barcode_cache_service.dart';
import 'package:pre_venc/features/product/data/services/barcode_lookup_orchestrator.dart';
import 'package:pre_venc/features/product/data/services/medicamentos_api_service.dart';
import 'package:pre_venc/features/product/data/services/open_beauty_facts_service.dart';
import 'package:pre_venc/features/product/data/services/open_food_facts_service.dart';
import 'package:pre_venc/features/product/data/services/remote_catalog_service.dart';

class MockCache extends Mock implements BarcodeCacheService {}
class MockRemote extends Mock implements RemoteCatalogService {}
class MockFood extends Mock implements OpenFoodFactsService {}
class MockBeauty extends Mock implements OpenBeautyFactsService {}
class MockMedicamentos extends Mock implements MedicamentosApiService {}

void main() {
  late MockCache cache;
  late MockRemote remote;
  late MockFood food;
  late MockBeauty beauty;
  late MockMedicamentos medicamentos;
  late BarcodeLookupOrchestrator orchestrator;

  setUp(() {
    cache = MockCache();
    remote = MockRemote();
    food = MockFood();
    beauty = MockBeauty();
    medicamentos = MockMedicamentos();
    orchestrator = BarcodeLookupOrchestrator(
      cache: cache,
      remote: remote,
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
      verifyNever(() => remote.lookup(any()));
      verifyNever(() => food.lookup(any()));
    });

    test('consulta Supabase se cache vazio', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => remote.lookup('123'))
          .thenAnswer((_) async => {'name': 'Do Supabase'});
      when(() => cache.put('123', any())).thenAnswer((_) async {});

      final result = await orchestrator.lookupAuto('123');

      expect(result?['name'], 'Do Supabase');
      verify(() => remote.lookup('123')).called(1);
      verifyNever(() => food.lookup(any()));
    });

    test('consulta Open Food Facts se Supabase vazio', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => remote.lookup('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123'))
          .thenAnswer((_) async => {'name': 'Leite', 'source': 'off'});
      when(() => cache.put('123', any())).thenAnswer((_) async {});
      when(() => remote.publishToCache(any(), any()))
          .thenAnswer((_) async {});

      final result = await orchestrator.lookupAuto('123');

      expect(result?['name'], 'Leite');
      verify(() => food.lookup('123')).called(1);
    });

    test('publica no Supabase após consulta externa bem-sucedida', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => remote.lookup('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123'))
          .thenAnswer((_) async => {'name': 'Leite', 'source': 'off'});
      when(() => cache.put('123', any())).thenAnswer((_) async {});
      when(() => remote.publishToCache(any(), any()))
          .thenAnswer((_) async {});

      await orchestrator.lookupAuto('123');

      // Dá tempo ao fire-and-forget
      await Future.delayed(const Duration(milliseconds: 50));
      verify(() => remote.publishToCache('123', any())).called(1);
    });

    test('consulta Open Beauty se alimento falhar', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => remote.lookup('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123')).thenAnswer((_) async => null);
      when(() => beauty.lookup('123'))
          .thenAnswer((_) async => {'name': 'Shampoo', 'source': 'obf'});
      when(() => cache.put('123', any())).thenAnswer((_) async {});
      when(() => remote.publishToCache(any(), any()))
          .thenAnswer((_) async {});

      final result = await orchestrator.lookupAuto('123');

      expect(result?['name'], 'Shampoo');
    });

    test('medicamentos é última opção', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => remote.lookup('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123')).thenAnswer((_) async => null);
      when(() => beauty.lookup('123')).thenAnswer((_) async => null);
      when(() => medicamentos.lookup('123'))
          .thenAnswer((_) async => {'name': 'Dipirona', 'source': 'med'});
      when(() => cache.put('123', any())).thenAnswer((_) async {});
      when(() => remote.publishToCache(any(), any()))
          .thenAnswer((_) async {});

      final result = await orchestrator.lookupAuto('123');

      expect(result?['name'], 'Dipirona');
    });

    test('retorna null quando nenhuma fonte encontra', () async {
      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => remote.lookup('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123')).thenAnswer((_) async => null);
      when(() => beauty.lookup('123')).thenAnswer((_) async => null);
      when(() => medicamentos.lookup('123')).thenAnswer((_) async => null);

      final result = await orchestrator.lookupAuto('123');

      expect(result, isNull);
      verifyNever(() => cache.put(any(), any()));
    });

    test('funciona sem Supabase configurado (remote null)', () async {
      // Recria orquestrador sem remote
      final noRemoteOrchestrator = BarcodeLookupOrchestrator(
        cache: cache,
        food: food,
        beauty: beauty,
        medicamentos: medicamentos,
      );

      when(() => cache.get('123')).thenAnswer((_) async => null);
      when(() => food.lookup('123'))
          .thenAnswer((_) async => {'name': 'Leite'});
      when(() => cache.put('123', any())).thenAnswer((_) async {});

      final result = await noRemoteOrchestrator.lookupAuto('123');
      expect(result?['name'], 'Leite');
    });
  });
}
