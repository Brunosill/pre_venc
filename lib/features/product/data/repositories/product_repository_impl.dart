import 'package:hive/hive.dart';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final Box<ProductModel> _box;

  ProductRepositoryImpl(this._box);

  Product _toEntity(ProductModel m) => Product(
        id: m.id,
        name: m.name,
        barcode: m.barcode,
        manufacturingDate: m.manufacturingDate,
        expirationDate: m.expirationDate,
        imagePath: m.imagePath,
        ocrText: m.ocrText,
        createdAt: m.createdAt,
      );

  ProductModel _toModel(Product p) => ProductModel(
        id: p.id,
        name: p.name,
        barcode: p.barcode,
        manufacturingDate: p.manufacturingDate,
        expirationDate: p.expirationDate,
        imagePath: p.imagePath,
        ocrText: p.ocrText,
        createdAt: p.createdAt,
      );

  @override
  Future<void> addProduct(Product product) async {
    await _box.put(product.id, _toModel(product));
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _box.put(product.id, _toModel(product));
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _box.delete(id);
  }

  @override
  Future<List<Product>> getProducts() async {
    final models = _box.values.toList()
      ..sort((a, b) {
        // Ordena por vencimento (mais próximo primeiro)
        final aExp = a.expirationDate ?? DateTime(9999);
        final bExp = b.expirationDate ?? DateTime(9999);
        return aExp.compareTo(bExp);
      });
    return models.map(_toEntity).toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    final model = _box.get(id);
    return model == null ? null : _toEntity(model);
  }
}