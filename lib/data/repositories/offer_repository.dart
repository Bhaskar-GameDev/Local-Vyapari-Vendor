import 'package:firebase_database/firebase_database.dart';
import '../models/offer_model.dart';

class OfferRepository {
  final DatabaseReference _ref =
      FirebaseDatabase.instance.ref('offers');

  Stream<List<OfferModel>> watchOffers() {
    return _ref.onValue.map((event) {
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
    final data = offer.toJson()..remove('id');
    await _ref.push().set(data);
  }

  Future<void> deleteOffer(String offerId) async {
    await _ref.child(offerId).remove();
  }
}
