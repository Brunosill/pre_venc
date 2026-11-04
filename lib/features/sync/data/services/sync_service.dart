import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../../product/data/models/inventory_item.dart';

import '../../../product/utils/inventory_id.dart';

class SyncResult {
  final int pushed;
  final int pulled;
  final int errors;
  final DateTime syncedAt;

  SyncResult({
    required this.pushed,
    required this.pulled,
    required this.errors,
    required this.syncedAt,
  });

  bool get hasErrors => errors > 0;
  bool get hasChanges => pushed > 0 || pulled > 0;
}

class SyncService {
  final SupabaseClient _client;
  SyncService(this._client);

  Future<SyncResult?> syncAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final box = HiveBoxes.inventoryItemBox;
    int pushed = 0;
    int pulled = 0;
    int errors = 0;

    // ============ 1. PUSH ============
    final pending = box.values
        .where((i) => i.syncStatus == 0 || i.syncStatus == 2)
        .toList();

    for (final item in pending) {
      try {
        await _pushItem(item, userId);
        pushed++;
      } catch (e) {
        debugPrint('Sync push erro em ${item.id}: $e');
        item.syncStatus = 2;
        await item.save();
        errors++;
      }
    }

    // ============ 2. PULL ============
    try {
      final lastSync = _readLastSync();
      final response = await _client
          .from('user_products')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', lastSync.toIso8601String());

      for (final row in response as List) {
        final remoteId = row['id'] as String;
        final remoteUpdatedAt =
        DateTime.tryParse(row['updated_at'] as String? ?? '');

        // ============ RECONCILIAÇÃO ============

        // A. Já existe item local com este remoteId? → atualiza
        InventoryItem? localItem =
        _findByRemoteId(box, remoteId);

        // B. Se não, procura pelo ID determinístico (barcode_lote)
        if (localItem == null) {
          final barcode = row['barcode'] as String?;
          final lote = row['lote'] as String?;
          if (barcode != null && barcode.isNotEmpty) {
            final expectedId =
            InventoryId.generate(barcode: barcode, lote: lote);
            localItem = box.get(expectedId);
          }
        }

        // C. Se ainda não, procura por barcode + lote (fallback)
        if (localItem == null) {
          final barcode = row['barcode'] as String?;
          final lote = row['lote'] as String?;
          if (barcode != null) {
            localItem = _findByBarcodeLote(box, barcode, lote);
          }
        }

        if (localItem != null) {
          // Já temos — só atualiza remoteId e, se remoto mais novo,
          // sobrescreve dados. Mas NÃO cria duplicata.
          bool changed = false;

          if (localItem.remoteId != remoteId) {
            localItem.remoteId = remoteId;
            changed = true;
          }

          if (localItem.syncStatus == 1 &&
              remoteUpdatedAt != null &&
              remoteUpdatedAt.isAfter(localItem.updatedAt)) {
            // Remoto mais novo: atualiza dados
            _applyRemoteToLocal(localItem, row, userId);
            changed = true;
            pulled++;
          }

          if (changed) {
            localItem.syncStatus = 1;
            await localItem.save();
          }
        } else {
          // Não existe localmente → cria item novo
          final newItem = _fromRemote(row, userId);
          if (newItem != null) {
            await box.put(newItem.id, newItem);
            pulled++;
          }
        }
      }
    } catch (e) {
      debugPrint('Sync pull erro: $e');
      errors++;
    }

    // ============ 3. Atualiza timestamp ============
    final syncedAt = DateTime.now();
    await _writeLastSync(syncedAt);

    return SyncResult(
      pushed: pushed,
      pulled: pulled,
      errors: errors,
      syncedAt: syncedAt,
    );
  }

  /// Corrige duplicatas pré-existentes causadas por versões anteriores
  /// do sync. Mescla por barcode_lote, mantendo o item com remoteId.
  Future<int> repairDuplicates() async {
    final box = HiveBoxes.inventoryItemBox;
    final items = box.values
        .where((i) => i.deletedAt == null)
        .toList();

    // Agrupa por chave determinística
    final groups = <String, List<InventoryItem>>{};
    for (final item in items) {
      if (item.barcode == null || item.lote == null) continue;
      final key = '${item.barcode}_${item.lote!.toUpperCase()}';
      groups.putIfAbsent(key, () => []).add(item);
    }

    int removed = 0;
    for (final entry in groups.entries) {
      if (entry.value.length <= 1) continue;

      // Prioriza o que tem remoteId (já sincronizado)
      entry.value.sort((a, b) {
        if (a.remoteId != null && b.remoteId == null) return -1;
        if (a.remoteId == null && b.remoteId != null) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

      final master = entry.value.first;
      double totalQty = 0;
      for (final dup in entry.value) {
        totalQty += dup.quantity;
        if (dup.id != master.id) {
          await box.delete(dup.id);
          removed++;
        }
      }
      master.quantity = totalQty;
      master.updatedAt = DateTime.now();
      master.syncStatus = 0; // vai reenviar
      await master.save();
    }

    if (removed > 0) {
      debugPrint('repairDuplicates: $removed duplicata(s) removida(s)');
    }
    return removed;
  }

  // ============ HELPERS ============

  InventoryItem? _findByRemoteId(dynamic box, String remoteId) {
    for (final item in box.values) {
      if (item.remoteId == remoteId) {
        return item as InventoryItem;
      }
    }
    return null;
  }

  InventoryItem? _findByBarcodeLote(
      dynamic box, String barcode, String? lote) {
    for (final item in box.values) {
      if (item.deletedAt != null) {
        continue;
      }
      if (item.barcode != barcode) {
        continue;
      }
      if ((item.lote ?? '').toUpperCase() !=
          (lote ?? '').toUpperCase()) {
        continue;
      }
      return item as InventoryItem;
    }
    return null;
  }

  void _applyRemoteToLocal(
      InventoryItem local, Map<String, dynamic> row, String userId) {
    local.userId = userId;
    local.remoteId = row['id'] as String;
    local.barcode = row['barcode'] as String?;
    local.type = row['type'] as int? ?? local.type;
    local.name = (row['custom_name'] as String?) ?? local.name;
    local.lote = row['lote'] as String?;
    local.manufacturingDate = _parseDate(row['manufacturing_date']);
    local.expirationDate = _parseDate(row['expiration_date']);
    local.quantity = (row['quantity'] as num?)?.toDouble() ?? local.quantity;
    local.unit = row['unit'] as String? ?? local.unit;
    local.notes = row['notes'] as String?;
    local.source = row['source'] as int? ?? local.source;
    local.updatedAt =
        DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now();
    local.deletedAt = _parseDate(row['deleted_at']);
  }

  Future<int> migrateLocalItems(String userId) async {
    final box = HiveBoxes.inventoryItemBox;
    final toMigrate = box.values.where((i) => i.remoteId == null).toList();

    int migrated = 0;
    for (final item in toMigrate) {
      try {
        await _pushItem(item, userId);
        migrated++;
      } catch (e) {
        debugPrint('Migração erro em ${item.id}: $e');
      }
    }
    return migrated;
  }

  Future<void> _pushItem(InventoryItem item, String userId) async {
    final payload = _toRemote(item, userId);

    if (item.remoteId == null) {
      // INSERT
      final result = await _client
          .from('user_products')
          .insert(payload)
          .select('id')
          .single();
      item.remoteId = result['id'] as String;
    } else {
      // UPDATE por remoteId (não pelo id local!)
      await _client
          .from('user_products')
          .update(payload)
          .eq('id', item.remoteId!);
    }

    item.userId = userId;
    item.syncStatus = 1;
    await item.save();
  }

  Map<String, dynamic> _toRemote(InventoryItem item, String userId) {
    return {
      'user_id': userId,
      'custom_name': item.name,
      'barcode': item.barcode,
      'type': item.type,
      'lote': item.lote,
      'manufacturing_date': _dateOnly(item.manufacturingDate),
      'expiration_date': _dateOnly(item.expirationDate),
      'quantity': item.quantity,
      'unit': item.unit,
      'notes': item.notes,
      'source': item.source,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
      'deleted_at': item.deletedAt?.toIso8601String(),
    };
  }

  /// Constrói InventoryItem a partir de uma linha remota.
  /// O ID local é o determinístico (barcode_lote), não o UUID do Supabase.
  InventoryItem? _fromRemote(Map<String, dynamic> row, String userId) {
    try {
      final remoteId = row['id'] as String;
      final barcode = row['barcode'] as String?;
      final lote = row['lote'] as String?;

      // ID determinístico para o local
      final localId =
      InventoryId.generate(barcode: barcode, lote: lote);

      return InventoryItem(
        id: localId,
        userId: userId,
        remoteId: remoteId,
        barcode: barcode,
        type: row['type'] as int? ?? 0,
        name: (row['custom_name'] as String?) ?? 'Sem nome',
        lote: lote,
        manufacturingDate: _parseDate(row['manufacturing_date']),
        expirationDate: _parseDate(row['expiration_date']),
        quantity: (row['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: row['unit'] as String? ?? 'un',
        notes: row['notes'] as String?,
        source: row['source'] as int? ?? 2,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        deletedAt: _parseDate(row['deleted_at']),
        syncStatus: 1,
      );
    } catch (e) {
      debugPrint('Erro ao converter remoto: $e');
      return null;
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String? _dateOnly(DateTime? d) {
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  DateTime _readLastSync() {
    final stored = HiveBoxes.appSettingsBox.get('last_sync_at') as String?;
    if (stored == null) return DateTime(2000);
    return DateTime.tryParse(stored) ?? DateTime(2000);
  }

  Future<void> _writeLastSync(DateTime date) async {
    await HiveBoxes.appSettingsBox
        .put('last_sync_at', date.toIso8601String());
  }

  DateTime get lastSync => _readLastSync();
}