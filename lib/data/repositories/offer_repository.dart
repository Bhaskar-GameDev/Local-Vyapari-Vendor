import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/offer_model.dart';

class OfferRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('offers');

  String? get _currentShopId => _auth.currentUser?.uid;

  Stream<List<OfferModel>> watchOffersForShop(String shopId) {
    _ref.child(shopId).keepSynced(true);

    return _ref.child(shopId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) return <OfferModel>[];

      // Parse per-item so one malformed record can't blank the whole list.
      final offers = <OfferModel>[];
      data.forEach((key, value) {
        if (value is! Map) return;
        try {
          final offerData = Map<String, dynamic>.from(value);
          offerData['id'] = key;
          offers.add(OfferModel.fromJson(offerData));
        } catch (e) {
          if (kDebugMode) debugPrint('Error parsing offer $key: $e');
        }
      });
      return offers;
    });
  }

  Future<void> addOffer(OfferModel offer) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception('User not authenticated');

    final data = offer.toJson()..remove('id');
    await _ref.child(shopId).push().set(data);
  }

  Future<void> updateOffer(OfferModel offer) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception('User not authenticated');

    final data = offer.toJson()..remove('id');
    await _ref.child(shopId).child(offer.id).update(data);
  }

  Future<void> deleteOffer(String offerId) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception('User not authenticated');

    await _ref.child(shopId).child(offerId).remove();
  }

  Future<void> updateOfferStatus(String offerId, bool isActive) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception('User not authenticated');

    await _ref.child(shopId).child(offerId).update({'isActive': isActive});
  }
}
