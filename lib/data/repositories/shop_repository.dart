import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/shop_model.dart';

class ShopRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('shop');

  Future<ShopModel?> getShopProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snapshot = await _dbRef.child(uid).get();
    if (snapshot.value is! Map) return null;
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    data['id'] = uid;
    return ShopModel.fromJson(data);
  }

  Stream<ShopModel?> watchShopProfile(String uid) {
    final ref = _dbRef.child(uid);
    ref.keepSynced(true);
    return ref.onValue.map((event) {
      if (event.snapshot.value is! Map) return null;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      data['id'] = uid;
      return ShopModel.fromJson(data);
    });
  }

  Future<void> updateShopProfile(ShopModel shop) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');
    final data = shop.copyWith(id: uid).toJson();
    await _dbRef.child(uid).set(data);
  }
}
