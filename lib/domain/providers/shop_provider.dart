import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/shop_repository.dart';
import 'auth_provider.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) => ShopRepository());

final shopProvider = StreamProvider<ShopModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);

  return FirebaseDatabase.instance
      .ref('shop')
      .child(user.uid)
      .onValue
      .map((event) {
        if (event.snapshot.value == null) return null;
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data['id'] = user.uid;
        return ShopModel.fromJson(data);
      });
});
