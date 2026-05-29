import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';
import 'fb_list_notifier.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) => ProductRepository());

class ProductsNotifier extends FBListNotifier<ProductModel> {
  final ProductRepository _repository;

  ProductsNotifier(super.ref, this._repository);

  @override
  Stream<List<ProductModel>> watchForUser(String uid) =>
      _repository.watchProductsForShop(uid);

  Future<void> addProduct(ProductModel product) =>
      _repository.addProduct(product);

  Future<void> updateProduct(ProductModel product) =>
      _repository.updateProduct(product);

  Future<void> deleteProduct(String productId) =>
      _repository.deleteProduct(productId);

  Future<void> toggleProductAvailability(String productId, bool isActive) =>
      _repository.updateProductStatus(productId, isActive);
}

final productsProvider =
    StateNotifierProvider<ProductsNotifier, AsyncValue<List<ProductModel>>>((ref) {
  return ProductsNotifier(ref, ref.watch(productRepositoryProvider));
});
