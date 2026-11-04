import 'package:flutter/foundation.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../data/models/inventory_item.dart';
import '../../utils/inventory_id.dart';

class InventoryMigrationService {
  /// Recalcula IDs de itens antigos para o formato barcode_lote.
  /// Itens com mesmo barcode+lote são mesclados automaticamente.
  static Future<int> migrateIdsIfNeeded() async {
    final box = HiveBoxes.inventoryItemBox;
    int migrated = 0;

    final items = box.values.toList();
    for (final item in items) {
      final newId = InventoryId.generate(
        barcode: item.barcode,
        lote: item.lote,
      );
      if (newId == item.id) continue;

      // Já existe alguém com o novo ID? Mescla quantidade.
      final existing = box.get(newId);
      if (existing != null && existing.deletedAt == null) {
        existing.quantity += item.quantity;
        existing.updatedAt = DateTime.now();
        existing.syncStatus = 0;
        await existing.save();
        await box.delete(item.id);
        migrated++;
        continue;
      }

      // Move para o novo ID
      await box.delete(item.id);
      final clone = InventoryItem(
        id: newId,
        userId: item.userId,
        barcode: item.barcode,
        type: item.type,
        name: item.name,
        lote: item.lote,
        manufacturingDate: item.manufacturingDate,
        expirationDate: item.expirationDate,
        quantity: item.quantity,
        unit: item.unit,
        notes: item.notes,
        source: item.source,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        deletedAt: item.deletedAt,
        isDraft: item.isDraft,
        remoteId: item.remoteId,
        syncStatus: item.syncStatus,
      );
      await box.put(newId, clone);
      migrated++;
    }

    if (migrated > 0) {
      debugPrint('Migração de IDs: $migrated item(s) atualizado(s)');
    }
    return migrated;
  }
}