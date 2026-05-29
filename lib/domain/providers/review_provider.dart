import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/shop_review.dart';
import '../../data/models/product_review.dart';
import 'auth_provider.dart';
import 'product_provider.dart';

// Resolves the logged-in merchant's shopId (using authStateProvider)
final vendorShopIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.uid;
});

// Stream Shop Reviews ordered by newest first
final vendorShopReviewsProvider = StreamProvider<List<ShopReview>>((ref) {
  final shopId = ref.watch(vendorShopIdProvider);
  if (shopId == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('shop_reviews')
      .where('shopId', isEqualTo: shopId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ShopReview.fromFirestore(doc))
          .toList());
});

class RatingDistribution {
  final int totalCount;
  final Map<int, int> distribution;
  final double averageRating;

  RatingDistribution({
    required this.totalCount,
    required this.distribution,
    required this.averageRating,
  });
}

// Calculate Rating Distribution on the fly
final vendorRatingDistributionProvider = Provider<RatingDistribution>((ref) {
  final reviewsAsync = ref.watch(vendorShopReviewsProvider);
  return reviewsAsync.maybeWhen(
    data: (reviews) {
      final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      double sum = 0;
      
      for (var r in reviews) {
        int rRounded = r.rating.round().clamp(1, 5);
        dist[rRounded] = (dist[rRounded] ?? 0) + 1;
        sum += r.rating;
      }
      
      return RatingDistribution(
        totalCount: reviews.length,
        distribution: dist,
        averageRating: reviews.isEmpty 
            ? 0.0 
            : double.parse((sum / reviews.length).toStringAsFixed(1)),
      );
    },
    orElse: () => RatingDistribution(
      totalCount: 0,
      distribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      averageRating: 0.0,
    ),
  );
});

// Stream product reviews for a specific productId
final productReviewsProvider = StreamProvider.family<List<ProductReview>, String>((ref, productId) {
  return FirebaseFirestore.instance
      .collection('product_reviews')
      .where('productId', isEqualTo: productId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ProductReview.fromFirestore(doc))
          .toList());
});

/// Single batched Firestore query for all product ratings in the vendor's catalog.
/// Replaces N individual per-product streams with one whereIn query (up to 30 products).
final vendorProductRatingsProvider = StreamProvider.autoDispose<Map<String, RatingDistribution>>((ref) {
  final products = ref.watch(productsProvider).value ?? [];
  if (products.isEmpty) return Stream.value({});

  final productIds = products.map((p) => p.id).take(30).toList();

  return FirebaseFirestore.instance
      .collection('product_reviews')
      .where('productId', whereIn: productIds)
      .snapshots()
      .map((snapshot) {
        final Map<String, List<double>> ratingsByProduct = {};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final pid = (data['productId'] as String?) ?? '';
          final r = ((data['rating'] as num?) ?? 0.0).toDouble();
          if (pid.isNotEmpty) ratingsByProduct.putIfAbsent(pid, () => []).add(r);
        }
        return {for (final id in productIds) id: _computeDistribution(ratingsByProduct[id] ?? [])};
      });
});

RatingDistribution _computeDistribution(List<double> ratings) {
  if (ratings.isEmpty) {
    return RatingDistribution(totalCount: 0, distribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0}, averageRating: 0.0);
  }
  final dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
  double sum = 0;
  for (final r in ratings) {
    final rounded = r.round().clamp(1, 5);
    dist[rounded] = (dist[rounded] ?? 0) + 1;
    sum += r;
  }
  return RatingDistribution(
    totalCount: ratings.length,
    distribution: dist,
    averageRating: double.parse((sum / ratings.length).toStringAsFixed(1)),
  );
}

// Calculate product average rating and total counts on the fly
final productRatingProvider = Provider.family<RatingDistribution, String>((ref, productId) {
  final reviewsAsync = ref.watch(productReviewsProvider(productId));
  return reviewsAsync.maybeWhen(
    data: (reviews) {
      final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      double sum = 0;
      
      for (var r in reviews) {
        int rRounded = r.rating.round().clamp(1, 5);
        dist[rRounded] = (dist[rRounded] ?? 0) + 1;
        sum += r.rating;
      }
      
      return RatingDistribution(
        totalCount: reviews.length,
        distribution: dist,
        averageRating: reviews.isEmpty 
            ? 0.0 
            : double.parse((sum / reviews.length).toStringAsFixed(1)),
      );
    },
    orElse: () => RatingDistribution(
      totalCount: 0,
      distribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      averageRating: 0.0,
    ),
  );
});

