import '../../data/models/inventory_item.dart';

abstract class InventoryRepository {
  Future<void> addItem(InventoryItem item);
  Future<void> updateItem(InventoryItem item);
  Future<void> deleteItem(String id); // Soft delete
  Future<List<InventoryItem>> getItems();
  Future<InventoryItem?> getItemById(String id);
}