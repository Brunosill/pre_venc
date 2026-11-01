import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/add_product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/get_products.dart';
import '../../domain/usecases/update_product.dart';

final productBoxProvider =
    Provider<Box<ProductModel>>((ref) => HiveBoxes.productBox);

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(productBoxProvider));
});

final addProductProvider = Provider<AddProduct>((ref) {
  return AddProduct(ref.watch(productRepositoryProvider));
});

final getProductsProvider = Provider<GetProducts>((ref) {
  return GetProducts(ref.watch(productRepositoryProvider));
});

final updateProductProvider = Provider<UpdateProduct>((ref) {
  return UpdateProduct(ref.watch(productRepositoryProvider));
});

final deleteProductProvider = Provider<DeleteProduct>((ref) {
  return DeleteProduct(ref.watch(productRepositoryProvider));
});

/// Stream reativo da lista de produtos.
final productsStreamProvider = StreamProvider<List<Product>>((ref) async* {
  final box = ref.watch(productBoxProvider);
  yield _mapBox(box);
  await for (final _ in box.watch()) {
    yield _mapBox(box);
  }
});

List<Product> _mapBox(Box<ProductModel> box) {
  final models = box.values.toList()
    ..sort((a, b) {
      final aExp = a.expirationDate ?? DateTime(9999);
      final bExp = b.expirationDate ?? DateTime(9999);
      return aExp.compareTo(bExp);
    });
  return models
      .map((m) => Product(
            id: m.id,
            name: m.name,
            barcode: m.barcode,
            manufacturingDate: m.manufacturingDate,
            expirationDate: m.expirationDate,
            imagePath: m.imagePath,
            ocrText: m.ocrText,
            createdAt: m.createdAt,
          ))
      .toList();
}