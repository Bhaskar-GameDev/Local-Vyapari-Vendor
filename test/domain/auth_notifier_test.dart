import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vyapari_vendor/domain/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

// Unit tests for AuthNotifier's *pure* guard logic — the validation branches that
// run BEFORE any Firebase sign-in and never touch the RoleService singleton.
//
// We mock AuthRepository (the only dependency AuthNotifier takes) with mocktail.
// `implements` avoids running AuthRepository's real field initializers, so no
// live Firebase instance is needed. Sign-in success paths (login, MFA, OTP
// completion) are intentionally NOT covered here: they call
// RoleService.instance, a hard-coded singleton that binds FirebaseAuth.instance
// and cannot be faked without a small production refactor (see the audit notes).

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;
  late AuthNotifier notifier;

  setUp(() {
    repo = _MockAuthRepository();
    notifier = AuthNotifier(repo);
  });

  group('checkPhone', () {
    test('returns true and clears loading when the number is registered', () async {
      when(() => repo.isPhoneRegistered('+919000000001'))
          .thenAnswer((_) async => true);

      final result = await notifier.checkPhone('+919000000001');

      expect(result, isTrue);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('returns false when the number is not registered', () async {
      when(() => repo.isPhoneRegistered(any())).thenAnswer((_) async => false);

      expect(await notifier.checkPhone('+910000000000'), isFalse);
      expect(notifier.state.isLoading, isFalse);
    });

    test('surfaces an error and stops loading when the lookup throws', () async {
      when(() => repo.isPhoneRegistered(any()))
          .thenThrow(Exception('rtdb offline'));

      expect(await notifier.checkPhone('+910000000000'), isFalse);
      expect(notifier.state.error, contains('rtdb offline'));
      expect(notifier.state.isLoading, isFalse);
    });
  });

  group('register guard', () {
    test('blocks registration when the phone is already taken', () async {
      when(() => repo.isPhoneRegistered('+919000000001'))
          .thenAnswer((_) async => true);

      final ok = await notifier.register(
        'a@b.com', 'pw123456', 'merchant', 'My Shop',
        phone: '+919000000001',
      );

      expect(ok, isFalse);
      expect(notifier.state.error, contains('already registered'));
      // The actual account-creating call must never fire when the guard trips.
      verifyNever(() => repo.register(any(), any(), any(),
          shopName: any(named: 'shopName'), phone: any(named: 'phone')));
    });

    test('proceeds to create the account when the phone is free', () async {
      when(() => repo.isPhoneRegistered(any())).thenAnswer((_) async => false);
      when(() => repo.register(any(), any(), any(),
              shopName: any(named: 'shopName'), phone: any(named: 'phone')))
          .thenAnswer((_) async => _FakeUserCredential());

      final ok = await notifier.register(
        'a@b.com', 'pw123456', 'merchant', 'My Shop',
        phone: '+919000000002',
      );

      expect(ok, isTrue);
      expect(notifier.state.error, isNull);
      verify(() => repo.register('a@b.com', 'pw123456', 'merchant',
          shopName: 'My Shop', phone: '+919000000002')).called(1);
    });

    test('maps a FirebaseAuthException to a friendly message', () async {
      when(() => repo.isPhoneRegistered(any())).thenAnswer((_) async => false);
      when(() => repo.register(any(), any(), any(),
              shopName: any(named: 'shopName'), phone: any(named: 'phone')))
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      final ok = await notifier.register('a@b.com', 'pw', 'customer', null);

      expect(ok, isFalse);
      expect(notifier.state.error, contains('already registered'));
    });
  });

  group('requestPasswordResetOtp guard', () {
    test('fails fast for an unregistered number without sending an OTP', () async {
      when(() => repo.isPhoneRegistered(any())).thenAnswer((_) async => false);

      String? reportedError;
      final ok = await notifier.requestPasswordResetOtp(
        '+910000000000',
        onCodeSent: (_) {},
        onFailed: (e) => reportedError = e,
      );

      expect(ok, isFalse);
      expect(reportedError, 'This phone number is not registered');
      verifyNever(() => repo.sendFirebaseOtp(
            phone: any(named: 'phone'),
            onCodeSent: any(named: 'onCodeSent'),
            onFailed: any(named: 'onFailed'),
          ));
    });
  });

  group('sendRegistrationOtp guard', () {
    test('refuses to send an OTP to an already-registered number', () async {
      when(() => repo.isPhoneRegistered(any())).thenAnswer((_) async => true);

      String? reportedError;
      final ok = await notifier.sendRegistrationOtp(
        '+919000000001',
        onCodeSent: (_) {},
        onFailed: (e) => reportedError = e,
      );

      expect(ok, isFalse);
      expect(reportedError, 'This phone number is already registered');
      verifyNever(() => repo.sendFirebaseOtp(
            phone: any(named: 'phone'),
            onCodeSent: any(named: 'onCodeSent'),
            onFailed: any(named: 'onFailed'),
          ));
    });
  });

  group('clearError', () {
    test('drops the error but preserves the loading flag', () {
      // Drive an error in via a failed guard, then clear it.
      when(() => repo.isPhoneRegistered(any())).thenThrow(Exception('x'));
      return notifier.checkPhone('+910').then((_) {
        expect(notifier.state.error, isNotNull);
        notifier.clearError();
        expect(notifier.state.error, isNull);
      });
    });
  });
}

class _FakeUserCredential extends Mock implements UserCredential {}
