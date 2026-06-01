import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vyapari_vendor/domain/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

// Failure-path test for AuthRepository.register — pins audit finding #1
// (orphaned auth accounts). When the auth account is created but a follow-up
// RTDB profile write fails, register MUST delete the just-created account so the
// user isn't left with a login that has no users/{uid} record (which would lock
// them out with a misleading "account suspended" next time).
//
// Enabled by the injectability refactor: AuthRepository now takes its
// FirebaseAuth / FirebaseDatabase via the constructor.

class _MockAuth extends Mock implements FirebaseAuth {}
class _MockDb extends Mock implements FirebaseDatabase {}
class _MockFunctions extends Mock implements FirebaseFunctions {}
class _MockRef extends Mock implements DatabaseReference {}
class _MockCredential extends Mock implements UserCredential {}
class _MockUser extends Mock implements User {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  late _MockAuth auth;
  late _MockDb db;
  late _MockUser user;
  late AuthRepository repo;

  setUp(() {
    auth = _MockAuth();
    db = _MockDb();
    user = _MockUser();
    repo = AuthRepository(auth: auth, database: db, functions: _MockFunctions());

    final credential = _MockCredential();
    when(() => credential.user).thenReturn(user);
    when(() => user.uid).thenReturn('uid123');
    when(() => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => credential);
  });

  test('rolls back the auth account when the first profile write fails', () async {
    final usersRef = _MockRef();
    final childRef = _MockRef();
    when(() => db.ref('users')).thenReturn(usersRef);
    when(() => usersRef.child('uid123')).thenReturn(childRef);
    // Simulate the users/{uid} write failing (rules / network).
    when(() => childRef.update(any()))
        .thenThrow(FirebaseException(plugin: 'database', code: 'permission-denied'));
    when(() => user.delete()).thenAnswer((_) async {});

    // register must surface the original failure...
    await expectLater(
      repo.register('a@b.com', 'pw123456', 'customer'),
      throwsA(isA<FirebaseException>()),
    );

    // ...and must have rolled the orphaned account back.
    verify(() => user.delete()).called(1);
  });

  test('does not delete the account when all writes succeed', () async {
    final usersRef = _MockRef();
    final phonesRef = _MockRef();
    final childRef = _MockRef();
    final phoneChildRef = _MockRef();
    when(() => db.ref('users')).thenReturn(usersRef);
    when(() => db.ref('phones')).thenReturn(phonesRef);
    when(() => usersRef.child('uid123')).thenReturn(childRef);
    when(() => childRef.update(any())).thenAnswer((_) async {});
    when(() => phonesRef.child(any())).thenReturn(phoneChildRef);
    when(() => phoneChildRef.set(any())).thenAnswer((_) async {});
    when(() => user.delete()).thenAnswer((_) async {});

    await repo.register('a@b.com', 'pw123456', 'customer', phone: '+919000000001');

    verifyNever(() => user.delete());
  });

  group('completePhoneSignupProfile (phone-OTP signup path)', () {
    test('rolls the account back when a profile write fails', () async {
      final usersRef = _MockRef();
      final childRef = _MockRef();
      when(() => db.ref('users')).thenReturn(usersRef);
      when(() => usersRef.child('uid123')).thenReturn(childRef);
      when(() => childRef.update(any()))
          .thenThrow(FirebaseException(plugin: 'database', code: 'unavailable'));
      when(() => user.delete()).thenAnswer((_) async {});

      await expectLater(
        repo.completePhoneSignupProfile(
          user: user,
          email: '919000000001@localvyapari.com',
          phone: '+919000000001',
        ),
        throwsA(isA<FirebaseException>()),
      );

      verify(() => user.delete()).called(1);
    });
  });
}
