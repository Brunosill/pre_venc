import '../entities/product.dart';
import '../repositories/product_repository.dart';

class AddProduct {
  final ProductRepository repository;
  AddProduct(this.repository);

  Future<void> call(Product product) => repository.addProduct(product);
}