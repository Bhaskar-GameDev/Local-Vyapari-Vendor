import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/offer_model.dart';
import '../../data/repositories/offer_repository.dart';

final offerRepositoryProvider = Provider<OfferRepository>((ref) => OfferRepository());

class OffersNotifier extends StateNotifier<AsyncValue<List<OfferModel>>> {
  final OfferRepository _repository;
  StreamSubscription? _subscription;

  OffersNotifier(this._repository) : super(const AsyncValue.loading()) {
    _subscription = _repository.watchOffers().listen((offers) {
      state = AsyncValue.data(offers);
      
      // Automatically deactivate any expired offers in the database
      final now = DateTime.now();
      for (final offer in offers) {
        if (offer.isActive) {
          try {
            final endDate = DateTime.parse(offer.endDate);
            if (endDate.isBefore(now)) {
              _repository.updateOfferStatus(offer.id, false);
            }
          } catch (_) {}
        }
      }

    }, onError: (e, st) {
      state = AsyncValue.error(e, st);
    });
  }

  Future<void> addOffer(OfferModel offer) async {
    await _repository.addOffer(offer);
  }

  Future<void> updateOffer(OfferModel offer) async {
    await _repository.updateOffer(offer);
  }

  Future<void> deleteOffer(String offerId) async {
    await _repository.deleteOffer(offerId);
  }

  Future<void> toggleOfferAvailability(String offerId, bool isActive) async {
    await _repository.updateOfferStatus(offerId, isActive);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final offersProvider = StateNotifierProvider<OffersNotifier, AsyncValue<List<OfferModel>>>((ref) {
  return OffersNotifier(ref.watch(offerRepositoryProvider));
});
