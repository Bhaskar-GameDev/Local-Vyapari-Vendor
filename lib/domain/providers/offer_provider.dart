import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/offer_model.dart';
import '../../data/repositories/offer_repository.dart';
import 'fb_list_notifier.dart';

final offerRepositoryProvider = Provider<OfferRepository>((ref) => OfferRepository());

class OffersNotifier extends FBListNotifier<OfferModel> {
  final OfferRepository _repository;

  OffersNotifier(super.ref, this._repository);

  @override
  Stream<List<OfferModel>> watchForUser(String uid) =>
      _repository.watchOffersForShop(uid);

  Future<void> addOffer(OfferModel offer) =>
      _repository.addOffer(offer);

  Future<void> updateOffer(OfferModel offer) =>
      _repository.updateOffer(offer);

  Future<void> deleteOffer(String offerId) =>
      _repository.deleteOffer(offerId);

  Future<void> toggleOfferAvailability(String offerId, bool isActive) =>
      _repository.updateOfferStatus(offerId, isActive);
}

final offersProvider =
    StateNotifierProvider<OffersNotifier, AsyncValue<List<OfferModel>>>((ref) {
  return OffersNotifier(ref, ref.watch(offerRepositoryProvider));
});
