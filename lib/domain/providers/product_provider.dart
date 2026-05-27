import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';
import 'auth_provider.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) => ProductRepository());

class ProductsNotifier extends StateNotifier<AsyncValue<List<ProductModel>>> {
  final Ref _ref;
  final ProductRepository _repository;
  StreamSubscription? _subscription;

  ProductsNotifier(this._ref, this._repository) : super(const AsyncValue.loading()) {
    _bindToUser(_ref.read(authStateProvider).value);
    _ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
      _bindToUser(next.value);
    });
  }

  void _bindToUser(User? user) {
    _subscription?.cancel();
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    _subscription = _repository.watchProductsForShop(user.uid).listen((products) {
      state = AsyncValue.data(products);
    }, onError: (Object e, StackTrace st) {
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

  Future<void> toggleProductAvailability(String productId, bool isActive) async {
    await _repository.updateProductStatus(productId, isActive);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final productsProvider = StateNotifierProvider<ProductsNotifier, AsyncValue<List<ProductModel>>>((ref) {
  return ProductsNotifier(ref, ref.watch(productRepositoryProvider));
});
