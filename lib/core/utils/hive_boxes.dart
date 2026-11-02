import 'package:hive/hive.dart';
import '../../features/product/data/models/raw_product_data.dart';
import '../../features/product/data/models/inventory_item.dart';
import '../../features/product/data/models/barcode_cache_model.dart';
import '../../features/alerts/data/models/alert_settings_model.dart';

class HiveBoxes {
  // Novas boxes
  static const String rawProducts = 'raw_products';
  static const String inventoryItems = 'inventory_items';
  
  // Boxes mantidas
  static const String barcodeCache = 'barcode_cache';
  static const String alertSettings = 'alert_settings';

  static late Box<RawProductData> rawProductBox;
  static late Box<InventoryItem> inventoryItemBox;
  static late Box<BarcodeCacheModel> barcodeCacheBox;
  static late Box<AlertSettingsModel> alertSettingsBox;

  static Future<void> init() async {
    rawProductBox = await Hive.openBox<RawProductData>(rawProducts);
    inventoryItemBox = await Hive.openBox<InventoryItem>(inventoryItems);
    barcodeCacheBox = await Hive.openBox<BarcodeCacheModel>(barcodeCache);
    alertSettingsBox = await Hive.openBox<AlertSettingsModel>(alertSettings);
  }
}
