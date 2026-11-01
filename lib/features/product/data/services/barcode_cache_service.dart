import 'package:hive/hive.dart';
import '../models/barcode_cache_model.dart';

class BarcodeCacheService {
  final Box<BarcodeCacheModel> _box;
  BarcodeCacheService(this._box);

  Future<Map<String, dynamic>?> get(String barcode) async {
    final cached = _box.get(barcode);
    if (cached == null) return null;
    if (cached.isExpired) {
      await cached.delete();
      return null;
    }
    return {
      'name': cached.name,
      'brand': cached.brand,
      'category': cached.category,
      'source': 'cache_local',
      'raw': cached.rawPayload,
    };
  }

  Future<void> put(String barcode, Map<String, dynamic> data) async {
    final model = BarcodeCacheModel(
      barcode: barcode,
      name: data['name'] as String?,
      brand: data['brand'] as String?,
      category: data['category'] as String?,
      source: data['source'] as String?,
      fetchedAt: DateTime.now(),
      rawPayload: (data['raw'] as Map?)?.cast<String, dynamic>(),
    );
    await _box.put(barcode, model);
  }
}