import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/shop_repository.dart';
import 'auth_provider.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) => ShopRepository());

final shopProvider = StreamProvider<ShopModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(shopRepositoryProvider).watchShopProfile(user.uid);
});
