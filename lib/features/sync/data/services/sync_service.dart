import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../../product/data/models/inventory_item.dart';

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

    // ========== 1. PUSH ==========
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

    // ========== 2. PULL ==========
    try {
      final lastSync = _readLastSync();
      final response = await _client
          .from('user_products')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', lastSync.toIso8601String());

      for (final row in response as List) {
        final remote = _fromRemote(row, userId);
        if (remote == null) continue;

        final local = box.get(remote.id);
        if (local == null) {
          await box.put(remote.id, remote);
          pulled++;
        } else if (local.syncStatus == 1 &&
            remote.updatedAt.isAfter(local.updatedAt)) {
          await box.put(remote.id, remote);
          pulled++;
        }
      }
    } catch (e) {
      debugPrint('Sync pull erro: $e');
      errors++;
    }

    // ========== 3. Atualiza timestamp ==========
    final syncedAt = DateTime.now();
    await _writeLastSync(syncedAt);

    return SyncResult(
      pushed: pushed,
      pulled: pulled,
      errors: errors,
      syncedAt: syncedAt,
    );
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
      final result = await _client
          .from('user_products')
          .insert(payload)
          .select('id')
          .single();
      item.remoteId = result['id'] as String;
    } else {
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

  InventoryItem? _fromRemote(Map<String, dynamic> row, String userId) {
    try {
      return InventoryItem(
        id: row['id'] as String,
        userId: userId,
        remoteId: row['id'] as String,
        barcode: row['barcode'] as String?,
        type: row['type'] as int? ?? 0,
        name: (row['custom_name'] as String?) ?? 'Sem nome',
        lote: row['lote'] as String?,
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
    await HiveBoxes.appSettingsBox.put(
        'last_sync_at', date.toIso8601String());
  }

  DateTime get lastSync => _readLastSync();
}