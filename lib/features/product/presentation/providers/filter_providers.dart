import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/inventory_item.dart';
import 'inventory_providers.dart';

// ==================== ENUMS ====================

enum StatusFilter { all, expired, expiringSoon, ok }

extension StatusFilterX on StatusFilter {
  String get label {
    switch (this) {
      case StatusFilter.all:
        return 'Todos';
      case StatusFilter.expired:
        return 'Vencidos';
      case StatusFilter.expiringSoon:
        return 'Vencendo';
      case StatusFilter.ok:
        return 'Em dia';
    }
  }
}

// ==================== NOTIFIERS (API MODERNA) ====================

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;

  void clear() => state = '';
}

class StatusFilterNotifier extends Notifier<StatusFilter> {
  @override
  StatusFilter build() => StatusFilter.all;

  void set(StatusFilter value) => state = value;
}

class TypeFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? value) => state = value;
}

// ==================== PROVIDERS ====================

final searchQueryProvider =
NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

final statusFilterProvider =
NotifierProvider<StatusFilterNotifier, StatusFilter>(
    StatusFilterNotifier.new);

final typeFilterProvider =
NotifierProvider<TypeFilterNotifier, int?>(TypeFilterNotifier.new);

// ==================== HELPERS ====================

StatusFilter _statusOf(InventoryItem item) {
  if (item.expirationDate == null) return StatusFilter.ok;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final exp = item.expirationDate!;
  final days =
      DateTime(exp.year, exp.month, exp.day).difference(today).inDays;

  if (days < 0) return StatusFilter.expired;
  if (days <= 7) return StatusFilter.expiringSoon;
  return StatusFilter.ok;
}

// ==================== LISTA FILTRADA ====================

final filteredInventoryItemsProvider =
Provider<List<InventoryItem>>((ref) {
  final items =
      ref.watch(inventoryItemsStreamProvider).asData?.value ??
          const <InventoryItem>[];
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final status = ref.watch(statusFilterProvider);
  final type = ref.watch(typeFilterProvider);

  return items.where((item) {
    if (type != null && item.type != type) return false;
    if (status != StatusFilter.all && _statusOf(item) != status) {
      return false;
    }
    if (query.isEmpty) return true;
    final name = item.name.toLowerCase();
    final lote = (item.lote ?? '').toLowerCase();
    final barcode = (item.barcode ?? '').toLowerCase();
    final notes = (item.notes ?? '').toLowerCase();
    return name.contains(query) ||
        lote.contains(query) ||
        barcode.contains(query) ||
        notes.contains(query);
  }).toList();
});

// ==================== CONTADORES ====================

final statusCountsProvider = Provider<Map<StatusFilter, int>>((ref) {
  final items =
      ref.watch(inventoryItemsStreamProvider).asData?.value ??
          const <InventoryItem>[];
  final type = ref.watch(typeFilterProvider);

  final counts = {
    StatusFilter.all: 0,
    StatusFilter.expired: 0,
    StatusFilter.expiringSoon: 0,
    StatusFilter.ok: 0,
  };

  for (final item in items) {
    if (type != null && item.type != type) continue;
    counts[StatusFilter.all] = counts[StatusFilter.all]! + 1;
    final s = _statusOf(item);
    counts[s] = counts[s]! + 1;
  }
  return counts;
});