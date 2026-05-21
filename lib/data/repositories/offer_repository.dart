import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/offer_model.dart';

class OfferRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('offers');

  String? get _currentShopId => _auth.currentUser?.uid;

  Stream<List<OfferModel>> watchOffers() {
    final shopId = _currentShopId;
    if (shopId == null) return Stream.value([]);

    _ref.child(shopId).keepSynced(true);

    return _ref.child(shopId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final map = Map<String, dynamic>.from(data as Map);
      return map.entries.map((e) {
        final offerData = Map<String, dynamic>.from(e.value as Map);
        offerData['id'] = e.key;
        return OfferModel.fromJson(offerData);
      }).toList();
    });
  }

  Future<void> addOffer(OfferModel offer) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception("User not authenticated");

    final data = offer.toJson()..remove('id');
    await _ref.child(shopId).push().set(data);
  }

  Future<void> deleteOffer(String offerId) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception("User not authenticated");

    await _ref.child(shopId).child(offerId).remove();
  }

  Future<void> updateOfferStatus(String offerId, bool isActive) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception("User not authenticated");

    await _ref.child(shopId).child(offerId).update({'isActive': isActive});
  }
}
