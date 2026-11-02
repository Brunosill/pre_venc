import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../data/models/inventory_item.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

// Box provider
final inventoryBoxProvider =
    Provider<Box<InventoryItem>>((ref) => HiveBoxes.inventoryItemBox);

// Repositório
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(ref.watch(inventoryBoxProvider));
});

// Stream de itens ativos (não deletados)
final inventoryItemsStreamProvider =
    StreamProvider<List<InventoryItem>>((ref) async* {
  final box = ref.watch(inventoryBoxProvider);
  
  List<InventoryItem> readItems() {
    return box.values
        .where((item) => item.deletedAt == null)
        .toList()
      ..sort((a, b) {
        final aDate = a.expirationDate ?? DateTime(9999);
        final bDate = b.expirationDate ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });
  }

  yield readItems();
  await for (final _ in box.watch()) {
    yield readItems();
  }
});

// Ações de CRUD
final addItemProvider = Provider<Future<void> Function(InventoryItem)>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return (item) async {
    item.syncStatus = 0; // pendente de sync
    await repo.addItem(item);
  };
});

final updateItemProvider = Provider<Future<void> Function(InventoryItem)>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return (item) async {
    item.syncStatus = 0; // pendente de sync
    await repo.updateItem(item);
  };
});
final deleteItemProvider = Provider<Future<void> Function(String)>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return (id) => repo.deleteItem(id);
});
