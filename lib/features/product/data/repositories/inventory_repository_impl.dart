import 'package:hive/hive.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../models/inventory_item.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final Box<InventoryItem> _box;

  InventoryRepositoryImpl(this._box);

  @override
  Future<void> addItem(InventoryItem item) async {
    await _box.put(item.id, item);
  }

  @override
  Future<void> updateItem(InventoryItem item) async {
    item.updatedAt = DateTime.now();
    await _box.put(item.id, item);
  }

  @override
  Future<void> deleteItem(String id) async {
    final item = _box.get(id);
    if (item != null) {
      item.deletedAt = DateTime.now(); // Soft delete
      item.updatedAt = DateTime.now();
      await item.save();
    }
  }

  @override
  Future<List<InventoryItem>> getItems() async {
    return _box.values
        .where((item) => item.deletedAt == null)
        .toList()
      ..sort((a, b) {
        final aDate = a.expirationDate ?? DateTime(9999);
        final bDate = b.expirationDate ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });
  }

  @override
  Future<InventoryItem?> getItemById(String id) async {
    final item = _box.get(id);
    if (item == null || item.deletedAt != null) return null;
    return item;
  }
}