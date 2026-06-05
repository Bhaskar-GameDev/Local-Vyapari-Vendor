// Firestore's CollectionReference/DocumentReference are `@sealed`; mocking them
// with mocktail is safe at runtime, so silence the annotation-only warning.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vyapari_vendor/core/services/feedback_service.dart';
import 'package:mocktail/mocktail.dart';

// Unit tests for FeedbackService. The service is the only client-side writer of
// the shared `feedback` collection, so these pin the document contract the admin
// app depends on (exact type/status strings, trimmed message, source tag) and
// the client-side length guard that mirrors the Firestore rule.

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDocRef extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  late _MockFirestore firestore;
  late _MockCollection collection;
  late FeedbackService service;

  setUp(() {
    firestore = _MockFirestore();
    collection = _MockCollection();
    service = FeedbackService(firestore: firestore);

    when(() => firestore.collection('feedback')).thenReturn(collection);
    when(() => collection.add(any())).thenAnswer((_) async => _MockDocRef());
  });

  Map<String, dynamic> captureAddedData() {
    return verify(() => collection.add(captureAny())).captured.single
        as Map<String, dynamic>;
  }

  test('writes the agreed document shape with one add() call', () async {
    await service.submitFeedback(
      userId: 'uid123',
      userEmail: 'vendor@example.com',
      type: FeedbackType.bug,
      message: 'Something is broken',
    );

    final data = captureAddedData();
    expect(data['userId'], 'uid123');
    expect(data['userEmail'], 'vendor@example.com');
    expect(data['type'], 'bug'); // exact contract string
    expect(data['message'], 'Something is broken');
    expect(data['status'], 'new');
    expect(data['source'], 'vendor');
    expect(data['platform'], isNotEmpty);
    expect(data['createdAt'], isA<FieldValue>()); // serverTimestamp sentinel
  });

  test('maps each FeedbackType to its exact contract string', () async {
    for (final entry in {
      FeedbackType.bug: 'bug',
      FeedbackType.feature: 'feature',
      FeedbackType.general: 'general',
    }.entries) {
      await service.submitFeedback(
        userId: 'u',
        userEmail: 'e@e.com',
        type: entry.key,
        message: 'hello',
      );
    }

    final captured = verify(() => collection.add(captureAny())).captured;
    expect(
      captured.map((d) => (d as Map<String, dynamic>)['type']),
      ['bug', 'feature', 'general'],
    );
  });

  test('trims surrounding whitespace from the message', () async {
    await service.submitFeedback(
      userId: 'u',
      userEmail: 'e@e.com',
      type: FeedbackType.general,
      message: '   padded message   ',
    );

    expect(captureAddedData()['message'], 'padded message');
  });

  test('rejects an empty (or whitespace-only) message without writing',
      () async {
    await expectLater(
      service.submitFeedback(
        userId: 'u',
        userEmail: 'e@e.com',
        type: FeedbackType.general,
        message: '   ',
      ),
      throwsA(isA<ArgumentError>()),
    );
    verifyNever(() => collection.add(any()));
  });

  test('rejects a message longer than the 500-char limit without writing',
      () async {
    await expectLater(
      service.submitFeedback(
        userId: 'u',
        userEmail: 'e@e.com',
        type: FeedbackType.general,
        message: 'x' * (kFeedbackMaxLength + 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
    verifyNever(() => collection.add(any()));
  });
}
