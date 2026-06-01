import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vyapari_vendor/core/services/role_service.dart';
import 'package:local_vyapari_vendor/domain/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

// Failure-path tests for AuthNotifier.login — pins audit finding #2
// (validateUserSession swallowing infrastructure errors and logging legitimate
// users out with a false "suspended"). Enabled by the injectability refactor:
// AuthNotifier now accepts a RoleService, so the role-resolution singleton can
// be faked without a live Firebase app.

class _MockAuthRepository extends Mock implements AuthRepository {}
class _MockRoleService extends Mock implements RoleService {}
class _MockUser extends Mock implements User {}
class _MockCredential extends Mock implements UserCredential {}

// A throwable FirebaseFunctionsException — the subclass may legitimately call
// the protected super constructor, which a test cannot do directly.
class _FnException extends FirebaseFunctionsException {
  _FnException(String code, String message) : super(code: code, message: message);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_MockUser());
  });

  late _MockAuthRepository repo;
  late _MockRoleService roleService;
  late _MockUser user;
  late AuthNotifier notifier;

  setUp(() {
    repo = _MockAuthRepository();
    roleService = _MockRoleService();
    user = _MockUser();
    notifier = AuthNotifier(repo, roleService: roleService);

    final credential = _MockCredential();
    when(() => credential.user).thenReturn(user);
    when(() => user.uid).thenReturn('uid123');
    when(() => repo.login(any(), any())).thenAnswer((_) async => credential);
    when(() => roleService.getRolesFromDatabase(any()))
        .thenAnswer((_) async => {'merchant': true});
    when(() => roleService.getRoles(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => {'merchant': true});
    when(() => repo.logout()).thenAnswer((_) async {});
  });

  test('transient backend failure does NOT log the user out or claim suspended',
      () async {
    // validateSession is unreachable (e.g. flaky network) -> infra error.
    when(() => repo.validateUserSession(any(), any()))
        .thenThrow(_FnException('unavailable', 'Backend unreachable'));

    final ok = await notifier.login('a@b.com', 'pw123456');

    expect(ok, isFalse);
    // The user is NOT signed out for an infrastructure hiccup...
    verifyNever(() => repo.logout());
    // ...and is NOT told their account is suspended/denied.
    expect(notifier.state.error, isNotNull);
    expect(notifier.state.error, isNot(contains('Access Denied')));
    expect(notifier.state.error, isNot(contains('suspended')));
    expect(notifier.state.isLoading, isFalse);
  });

  test('a genuine session rejection DOES log the user out with access denied',
      () async {
    // Backend reachable but explicitly rejects the session.
    when(() => repo.validateUserSession(any(), any()))
        .thenAnswer((_) async => false);

    final ok = await notifier.login('a@b.com', 'pw123456');

    expect(ok, isFalse);
    verify(() => repo.logout()).called(1);
    expect(notifier.state.error, contains('Access Denied'));
  });

  test('a valid session with a known role succeeds without logout', () async {
    when(() => repo.validateUserSession(any(), any()))
        .thenAnswer((_) async => true);

    final ok = await notifier.login('a@b.com', 'pw123456');

    expect(ok, isTrue);
    verifyNever(() => repo.logout());
    expect(notifier.state.error, isNull);
    expect(notifier.state.isLoading, isFalse);
  });

  group('verifyAndSubmit (new phone-OTP signup) delegates rollback', () {
    setUp(() {
      final credential = _MockCredential();
      when(() => credential.user).thenReturn(user);
      when(() => user.phoneNumber).thenReturn('+919000000001');
      when(() => repo.verifyAndSignInWithPhone(any(), any()))
          .thenAnswer((_) async => credential);
    });

    test('calls completePhoneSignupProfile for a new user', () async {
      when(() => repo.completePhoneSignupProfile(
            user: any(named: 'user'),
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            shopName: any(named: 'shopName'),
          )).thenAnswer((_) async {});

      final ok = await notifier.verifyAndSubmit(
        verificationId: 'vid',
        code: '654321',
        isRegistered: false,
        shopName: 'Corner Store',
        phone: '+919000000001',
      );

      expect(ok, isTrue);
      verify(() => repo.completePhoneSignupProfile(
            user: user,
            email: '919000000001@localvyapari.com',
            phone: '+919000000001',
            shopName: 'Corner Store',
          )).called(1);
    });

    test('reports a friendly error when the rollback path rethrows', () async {
      when(() => repo.completePhoneSignupProfile(
            user: any(named: 'user'),
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            shopName: any(named: 'shopName'),
          )).thenThrow(
          FirebaseException(plugin: 'database', code: 'unavailable'));

      final ok = await notifier.verifyAndSubmit(
        verificationId: 'vid',
        code: '654321',
        isRegistered: false,
        phone: '+919000000001',
      );

      expect(ok, isFalse);
      expect(notifier.state.error, isNotNull);
      // Mapped through ErrorHandler, not a raw "Exception: ..." dump.
      expect(notifier.state.error, isNot(contains('Exception:')));
      expect(notifier.state.isLoading, isFalse);
    });
  });
}
