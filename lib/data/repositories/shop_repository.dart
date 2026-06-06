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
    // Server-owned fields: verification is granted server-side and ratings are
    // computed by Cloud Functions from the reviews collections. The client must
    // never write these — the security rules reject them, and re-sending a stale
    // rating here would otherwise fail the whole update. Strip before writing.
    final data = shop.copyWith(id: uid).toJson()
      ..remove('isVerified')
      ..remove('rating')
      ..remove('totalReviews');
    // update() instead of set() so extra fields (e.g. manuallyClosedAt) are preserved.
    await _dbRef.child(uid).update(data);
  }
}
