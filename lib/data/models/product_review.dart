import 'package:cloud_firestore/cloud_firestore.dart';

class ProductReview {
  final String id;
  final String userId;
  final String userDisplayName;
  final String productId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ProductReview({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.productId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ProductReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductReview(
      id: doc.id,
      userId: (data['userId'] ?? '') as String,
      userDisplayName: (data['userDisplayName'] ?? 'Anonymous User') as String,
      productId: (data['productId'] ?? '') as String,
      rating: ((data['rating'] ?? 0.0) as num).toDouble(),
      comment: (data['comment'] ?? '') as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
