import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/shop_repository.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) => ShopRepository());

class ShopNotifier extends StateNotifier<AsyncValue<ShopModel?>> {
  final ShopRepository _repository;

  ShopNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadShopProfile();
  }

  Future<void> loadShopProfile() async {
    state = const AsyncValue.loading();
    try {
      final shop = await _repository.getShopProfile();
      state = AsyncValue.data(shop);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> createOrUpdateShop(ShopModel shop) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateShopProfile(shop);
      state = AsyncValue.data(shop);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final shopProvider = StateNotifierProvider<ShopNotifier, AsyncValue<ShopModel?>>((ref) {
  return ShopNotifier(ref.watch(shopRepositoryProvider));
});
