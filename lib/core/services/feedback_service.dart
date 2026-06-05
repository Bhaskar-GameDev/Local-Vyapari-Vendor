import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The kind of feedback a vendor can send. The string [value] is the contract
/// shared with the feedback admin app and enforced by the Firestore rule, so it
/// must stay exactly "bug" | "feature" | "general".
enum FeedbackType {
  bug('bug'),
  feature('feature'),
  general('general');

  const FeedbackType(this.value);
  final String value;
}

/// Maximum length of a feedback message, mirrored by the Firestore rule.
const int kFeedbackMaxLength = 500;

/// Writes vendor feedback to the shared `feedback` collection (same Firestore
/// instance as the user app). Each submission is a new auto-ID document; the
/// admin app owns `status` from there on.
class FeedbackService {
  FeedbackService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> submitFeedback({
    required String userId,
    required String userEmail,
    required FeedbackType type,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || trimmed.length > kFeedbackMaxLength) {
      throw ArgumentError('Feedback message must be 1–$kFeedbackMaxLength characters.');
    }

    await _firestore.collection('feedback').add({
      'userId': userId,
      'userEmail': userEmail,
      'type': type.value,
      'message': trimmed,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      // The admin app identifies the originating app by email; tag the source
      // explicitly so it never has to guess for vendor submissions.
      'source': 'vendor',
      // Admin-owned lifecycle field — always starts as "new" from the client.
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final feedbackServiceProvider =
    Provider<FeedbackService>((ref) => FeedbackService());
