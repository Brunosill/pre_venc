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

/// Busca um item em conflito (mesmo barcode E mesmo lote, não deletado, não rascunho).
/// Retorna null se não houver conflito ou se faltar algum dado.
InventoryItem? _findConflict(
    Box<InventoryItem> box,
    InventoryItem candidate, {
      String? ignoreId,
    }) {
  if (candidate.barcode == null || candidate.lote == null) return null;

  final candidateBarcode = candidate.barcode!.trim();
  final candidateLote = candidate.lote!.trim().toUpperCase();

  for (final existing in box.values) {
    if (existing.id == ignoreId) continue;
    if (existing.deletedAt != null) continue;
    if (existing.isDraft) continue;
    if (existing.barcode?.trim() != candidateBarcode) continue;
    if ((existing.lote ?? '').trim().toUpperCase() != candidateLote) continue;
    return existing;
  }
  return null;
}

/// Adiciona ou soma quantidade se houver conflito.
/// Retorna o item resultante (novo ou existente mesclado).
final addItemProvider = Provider<Future<InventoryItem> Function(InventoryItem)>(
        (ref) {
      final repo = ref.watch(inventoryRepositoryProvider);
      final box = ref.watch(inventoryBoxProvider);

      return (item) async {
        item.syncStatus = 0;

        final conflict = _findConflict(box, item);
        if (conflict != null) {
          // Soma quantidade ao existente
          conflict.quantity += item.quantity;
          conflict.updatedAt = DateTime.now();
          conflict.syncStatus = 0;
          // Preserva o userId se o conflito ainda era anônimo
          conflict.userId ??= item.userId;
          await conflict.save();
          return conflict;
        }

        await repo.addItem(item);
        return item;
      };
    });

/// Atualiza ou soma quantidade se a edição gerar conflito.
/// Retorna o item resultante (editado ou existente mesclado).
final updateItemProvider =
Provider<Future<InventoryItem> Function(InventoryItem)>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  final box = ref.watch(inventoryBoxProvider);

  return (item) async {
    item.syncStatus = 0;

    final conflict = _findConflict(box, item, ignoreId: item.id);
    if (conflict != null) {
      // Soma quantidade do item editado ao conflitante
      conflict.quantity += item.quantity;
      conflict.updatedAt = DateTime.now();
      conflict.syncStatus = 0;
      conflict.userId ??= item.userId;
      await conflict.save();

      // Marca o item editado como deletado (soft delete)
      item.deletedAt = DateTime.now();
      item.updatedAt = DateTime.now();
      item.syncStatus = 0;
      await repo.updateItem(item);

      return conflict;
    }

    await repo.updateItem(item);
    return item;
  };
});

final deleteItemProvider = Provider<Future<void> Function(String)>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return (id) => repo.deleteItem(id);
});