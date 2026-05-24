import 'package:cloud_firestore/cloud_firestore.dart';

class ShopReview {
  final String id;
  final String userId;
  final String userDisplayName;
  final String shopId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ShopReview({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.shopId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ShopReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopReview(
      id: doc.id,
      userId: (data['userId'] ?? '') as String,
      userDisplayName: (data['userDisplayName'] ?? 'Anonymous User') as String,
      shopId: (data['shopId'] ?? '') as String,
      rating: ((data['rating'] ?? 0.0) as num).toDouble(),
      comment: (data['comment'] ?? '') as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
