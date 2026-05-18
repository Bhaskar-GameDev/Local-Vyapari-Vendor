import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) => ProductRepository());

class ProductsNotifier extends StateNotifier<AsyncValue<List<ProductModel>>> {
  final ProductRepository _repository;
  StreamSubscription? _subscription;

  ProductsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _subscription = _repository.watchProducts().listen((products) {
      state = AsyncValue.data(products);
    }, onError: (e, st) {
      state = AsyncValue.error(e, st);
    });
  }

  Future<void> addProduct(ProductModel product) async {
    await _repository.addProduct(product);
    // State updates automatically via the native Firebase stream
  }

  Future<void> updateProduct(ProductModel product) async {
    await _repository.updateProduct(product);
  }

  Future<void> deleteProduct(String productId) async {
    await _repository.deleteProduct(productId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final productsProvider = StateNotifierProvider<ProductsNotifier, AsyncValue<List<ProductModel>>>((ref) {
  return ProductsNotifier(ref.watch(productRepositoryProvider));
});
