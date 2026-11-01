import '../entities/product.dart';

abstract class ProductRepository {
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<List<Product>> getProducts();
  Future<Product?> getProductById(String id);
}