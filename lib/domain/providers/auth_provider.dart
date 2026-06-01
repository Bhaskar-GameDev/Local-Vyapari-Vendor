import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../core/exceptions/error_handler.dart';
import '../../core/services/role_service.dart';

// â”€â”€â”€ Repository â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AuthRepository {
  /// Dependencies default to the real Firebase singletons in production but can
  /// be injected with fakes/mocks in tests. The `?? .instance` fallbacks
  /// short-circuit when a dependency is supplied, so tests never touch a live
  /// Firebase instance.
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseDatabase? database,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _db = database ?? FirebaseDatabase.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseDatabase _db;

  /// Stream of auth state changes â€” null means logged out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Resolves a sign-in that was interrupted by a TOTP MFA challenge.
  Future<UserCredential> resolveMfaSignIn(
      MultiFactorResolver resolver, String code) async {
    final hint = resolver.hints.firstWhere(
      (h) => h.factorId == 'totp',
      orElse: () => resolver.hints.first,
    );
    final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
      hint.uid,
      code.trim(),
    );
    return resolver.resolveSignIn(assertion);
  }

  Future<UserCredential> register(String email, String password, String role,
      {String? shopName, String? phone}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final user = credential.user;
    final uid = user?.uid;
    if (uid != null) {
      // The auth account now exists. If any of the profile writes below fail
      // (network/rules), roll the account back so we don't leave an orphaned
      // login with no users/{uid} record — which would lock the person out with
      // a misleading "account suspended" on their next sign-in.
      try {
        final updates = {
          'email': email.trim(),
          'createdAt': ServerValue.timestamp,
        };
        if (phone != null && phone.isNotEmpty) {
          updates['phone'] = phone.trim();
          updates['verified'] = true;
        }

        await _db.ref('users').child(uid).update(updates);

        if (phone != null && phone.isNotEmpty) {
          await _db.ref('phones').child(phone.trim()).set(uid);
        }

        if (role == 'merchant') {
          await _db.ref('shop').child(uid).set({
            'name': shopName ?? 'My Shop',
            'description': 'Welcome to our shop!',
            'address': '',
            'phone': phone ?? '',
            'isOpen': true,
            'isVerified': false,
          });
        }
      } catch (e) {
        // Best-effort rollback; ignore a delete failure and surface the
        // original write error to the caller.
        try {
          await user!.delete();
        } catch (_) {/* leave cleanup to a server reaper if delete fails */}
        rethrow;
      }
    }
    return credential;
  }

  /// Writes the initial profile (users + phones index + shop) for a brand-new
  /// account created via phone OTP, then rolls the auth account back if any
  /// write fails — same orphan-prevention contract as [register]. Centralizing
  /// these writes here (instead of in the notifier) keeps them behind the
  /// injectable [_db] so the rollback can be unit tested.
  Future<void> completePhoneSignupProfile({
    required User user,
    required String email,
    required String phone,
    String? shopName,
  }) async {
    try {
      await _db.ref('users').child(user.uid).update({
        'email': email,
        'phone': phone,
        'createdAt': ServerValue.timestamp,
        'verified': true,
      });

      await _db.ref('phones').child(phone).set(user.uid);

      await _db.ref('shop').child(user.uid).set({
        'name': shopName ?? 'My Shop',
        'description': 'Welcome to our shop!',
        'address': '',
        'phone': phone,
        'isOpen': true,
        'isVerified': false,
      });
    } catch (e) {
      try {
        await user.delete();
      } catch (_) {/* leave cleanup to a server reaper if delete fails */}
      rethrow;
    }
  }

  Future<bool> isMerchantUser(User user) async {
    return await validateUserSession(user, 'merchant');
  }

  /// Validates the session for [role] against the `validateSession` callable.
  ///
  /// Returns `true` when the backend confirms the session, `false` when it
  /// explicitly rejects it (wrong role / suspended). Crucially it does NOT
  /// swallow infrastructure failures: a [FirebaseFunctionsException] (e.g.
  /// `unavailable`/`internal` on a flaky network) is rethrown so the caller can
  /// tell "you're not authorized" apart from "we couldn't reach the server" and
  /// avoid logging a legitimate user out with a false "suspended" message.
  Future<bool> validateUserSession(User user, String role) async {
    final result =
        await _functions.httpsCallable('validateSession').call<dynamic>({
      'targetRole': role,
      'deviceInfo': {
        'platform': 'flutter-client',
      }
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['success'] == true) {
      await user.getIdToken(true);
      return true;
    }
    return false;
  }

  // --- Native Firebase Phone Auth Support ---

  Future<bool> isPhoneRegistered(String phone) async {
    final snapshot =
        await _db.ref('phones').child(phone).get();
    return snapshot.exists && snapshot.value != null;
  }

  Future<String> resolveLoginEmailForPhone(String phone) async {
    final result =
        await _functions.httpsCallable('resolvePhoneLoginEmail').call<dynamic>({
      'phone': phone,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final email = data['email']?.toString();
    if (email == null || email.isEmpty) {
      throw Exception('No email found linked to this phone number.');
    }
    return email;
  }

  Future<void> sendFirebaseOtp({
    required String phone,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final user = _auth.currentUser;
          if (user != null) {
            await user.linkWithCredential(credential);
            // Update database records
            await _db
                .ref('users')
                .child(user.uid)
                .update({
              'phone': phone,
              'verified': true,
            });
            await _db
                .ref('phones')
                .child(phone)
                .set(user.uid);
          } else {
            await _auth.signInWithCredential(credential);
          }
        } catch (e) {
          // Auto-verification is best-effort, but a failure here can leave the
          // 'phones' index / 'verified' flag out of sync â€” surface it for debugging.
          if (kDebugMode) {
            debugPrint('Phone auto-verification post-link write failed: $e');
          }
        }
      },
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> verifyAndSignInWithPhone(
      String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> verifyAndLinkPhone(String verificationId, String smsCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // The phone provider is already linked to THIS account in Firebase Auth,
      // but the RTDB 'phones' index can be out of sync if the original link's
      // database write failed — leaving the number "already linked" yet "not
      // registered", and impossible to re-link. Rather than dead-ending the
      // user, prove they still control this number by reauthenticating with the
      // OTP (this validates the code and rejects a different number via
      // 'user-mismatch'), then fall through to reconcile the index below.
      if (e.code == 'provider-already-linked') {
        await user.reauthenticateWithCredential(credential);
      } else {
        rethrow;
      }
    }

    // Reconcile DB records — runs whether the link just happened or was already
    // present, repairing the desynced 'phones' index going forward.
    await user.reload();
    final phone = _auth.currentUser?.phoneNumber ?? user.phoneNumber ?? '';
    if (phone.isNotEmpty) {
      await _db.ref('users').child(user.uid).update({
        'phone': phone,
        'verified': true,
      });
      await _db.ref('phones').child(phone).set(user.uid);
    }
  }

  // --- Bind Email & Phone Support ---

  Future<void> bindEmail(String email) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    await _db
        .ref('users')
        .child(uid)
        .child('email')
        .set(email.trim());

    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(email.trim());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase Auth email update: $e');
      }
    }
  }

  Future<void> logout() async => await _auth.signOut();
}

// â”€â”€â”€ Providers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

/// Stream provider that reacts to Firebase auth state in real-time
final authStateProvider = StreamProvider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

// â”€â”€â”€ Auth State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AuthNotifierState {
  final bool isLoading;
  final String? error;

  /// Set when a sign-in is interrupted by an MFA challenge. The login screen
  /// watches this and routes to the MFA challenge screen.
  final MultiFactorResolver? mfaResolver;

  const AuthNotifierState({this.isLoading = false, this.error, this.mfaResolver});

  AuthNotifierState copyWith({bool? isLoading, String? error}) =>
      AuthNotifierState(isLoading: isLoading ?? this.isLoading, error: error);
}

class AuthNotifier extends StateNotifier<AuthNotifierState> {
  final AuthRepository _repository;
  final RoleService? _roleServiceOverride;

  /// Resolved lazily so that constructing an [AuthNotifier] in a test (without a
  /// `roleService`) never evaluates `RoleService.instance` — that singleton binds
  /// `FirebaseAuth.instance` and would throw without a live Firebase app.
  RoleService get _roleService => _roleServiceOverride ?? RoleService.instance;

  AuthNotifier(this._repository, {RoleService? roleService})
      : _roleServiceOverride = roleService,
        super(const AuthNotifierState());

  void clearError() {
    state = AuthNotifierState(isLoading: state.isLoading, error: null);
  }

  Future<bool> login(String email, String password) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      final credential = await _repository.login(email, password);

      final user = credential.user;
      if (user == null) {
        state = const AuthNotifierState(error: 'User not found.');
        return false;
      }

      final dbRoles = await _roleService.getRolesFromDatabase(user.uid);
      final targetRole = dbRoles['merchant'] == true ? 'merchant' : 'customer';

      final isValid = await _repository.validateUserSession(user, targetRole);
      if (!isValid) {
        await _repository.logout();
        state = const AuthNotifierState(
          error: 'Access Denied: Invalid account role or suspended.',
        );
        return false;
      }

      final roles = await _roleService.getRoles(forceRefresh: true);
      final isCustomer = roles['customer'] == true;
      final isMerchant = roles['merchant'] == true;

      if (!isCustomer && !isMerchant) {
        await _repository.logout();
        state = const AuthNotifierState(
          error: 'Access Denied: Invalid account role.',
        );
        return false;
      }

      return true;
    } on FirebaseAuthMultiFactorException catch (e) {
      // A second factor (TOTP) is required to finish signing in. Hand the
      // resolver to the UI, which routes to the MFA challenge screen.
      state = AuthNotifierState(isLoading: false, mfaResolver: e.resolver);
      return false;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } on FirebaseFunctionsException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      // Preserve any mfaResolver set by the MFA catch above.
      state = AuthNotifierState(
          isLoading: false, error: state.error, mfaResolver: state.mfaResolver);
    }
  }

  Future<bool> register(
      String email, String password, String role, String? shopName,
      {String? phone}) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      if (phone != null && phone.isNotEmpty) {
        final formattedPhone = phone.trim();
        final isPhoneReg = await _repository.isPhoneRegistered(formattedPhone);
        if (isPhoneReg) {
          state = const AuthNotifierState(
            error:
                'This phone number is already registered. If it is registered as a customer, please sign in with your password to upgrade to a merchant account.',
          );
          return false;
        }
      }
      await _repository.register(email, password, role,
          shopName: shopName, phone: phone);
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> loginWithPhoneAndPassword(String phone, String password) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();

      final realEmail =
          await _repository.resolveLoginEmailForPhone(formattedPhone);
      final credential = await _repository.login(realEmail, password);
      final user = credential.user;

      if (user == null) {
        state = const AuthNotifierState(error: 'User not found.');
        return false;
      }

      final dbRoles = await _roleService.getRolesFromDatabase(user.uid);
      final targetRole = dbRoles['merchant'] == true ? 'merchant' : 'customer';

      final isValid = await _repository.validateUserSession(user, targetRole);
      if (!isValid) {
        await _repository.logout();
        state = const AuthNotifierState(
          error: 'Access Denied: Invalid account role or suspended.',
        );
        return false;
      }

      final roles = await _roleService.getRoles(forceRefresh: true);
      final isCustomer = roles['customer'] == true;
      final isMerchant = roles['merchant'] == true;

      if (!isCustomer && !isMerchant) {
        await _repository.logout();
        state = const AuthNotifierState(
          error: 'Access Denied: Invalid account role.',
        );
        return false;
      }

      return true;
    } on FirebaseAuthMultiFactorException catch (e) {
      // A second factor (TOTP) is required to finish signing in. Hand the
      // resolver to the UI, which routes to the MFA challenge screen.
      state = AuthNotifierState(isLoading: false, mfaResolver: e.resolver);
      return false;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } on FirebaseFunctionsException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      // Preserve any mfaResolver set by the MFA catch above.
      state = AuthNotifierState(
          isLoading: false, error: state.error, mfaResolver: state.mfaResolver);
    }
  }

  Future<bool> checkPhone(String phone) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      final isRegistered = await _repository.isPhoneRegistered(phone);
      state = const AuthNotifierState();
      return isRegistered;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> requestOtp(
    String phone, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
  }) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      await _repository.sendFirebaseOtp(
        phone: phone,
        onCodeSent: (verificationId, _) {
          state = const AuthNotifierState();
          onCodeSent(verificationId);
        },
        onFailed: (e) {
          state = AuthNotifierState(error: e.message ?? 'Verification failed');
          onFailed(state.error!);
        },
      );
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      onFailed(e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> verifyAndSubmit({
    required String verificationId,
    required String code,
    required bool isRegistered,
    String? shopName,
    String? phone,
  }) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      if (isRegistered) {
        await _repository.verifyAndSignInWithPhone(verificationId, code);
      } else {
        final credential =
            await _repository.verifyAndSignInWithPhone(verificationId, code);
        final user = credential.user;
        if (user != null) {
          final phoneNum = phone ?? user.phoneNumber ?? '';
          final email = '${phoneNum.replaceAll('+', '')}@localvyapari.com';

          // Rolls the just-created account back if any profile write fails,
          // so a failed signup never leaves an orphaned phone-OTP login.
          await _repository.completePhoneSignupProfile(
            user: user,
            email: email,
            phone: phoneNum,
            shopName: shopName,
          );
        }
      }
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> bindEmail(String email) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      await _repository.bindEmail(email);
      state = const AuthNotifierState();
      return true;
    } catch (e) {
      state = AuthNotifierState(
          error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> requestBindPhoneOtp(
    String phone, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
  }) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      final uid = _repository.currentUser?.uid;
      if (uid == null) throw Exception('User not logged in');

      final formattedPhone = phone.trim();

      final existingUidSnapshot = await FirebaseDatabase.instance
          .ref('phones')
          .child(formattedPhone)
          .get();
      if (existingUidSnapshot.exists && existingUidSnapshot.value != uid) {
        throw Exception(
            'This phone number is already linked to another account');
      }

      await _repository.sendFirebaseOtp(
        phone: formattedPhone,
        onCodeSent: (verificationId, _) {
          state = const AuthNotifierState();
          onCodeSent(verificationId);
        },
        onFailed: (e) {
          state = AuthNotifierState(error: e.message ?? 'Verification failed');
          onFailed(state.error!);
        },
      );
      return true;
    } catch (e) {
      state = AuthNotifierState(
          error: e.toString().replaceFirst('Exception: ', ''));
      onFailed(state.error ?? 'Verification failed');
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> requestPasswordResetOtp(
    String phone, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
  }) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();
      final isReg = await _repository.isPhoneRegistered(formattedPhone);
      if (!isReg) {
        state = const AuthNotifierState(
            error: 'This phone number is not registered');
        onFailed(state.error!);
        return false;
      }
      await _repository.sendFirebaseOtp(
        phone: formattedPhone,
        onCodeSent: (verificationId, _) {
          state = const AuthNotifierState();
          onCodeSent(verificationId);
        },
        onFailed: (e) {
          state = AuthNotifierState(error: e.message ?? 'Verification failed');
          onFailed(state.error!);
        },
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      onFailed(state.error!);
      return false;
    } catch (e) {
      state = AuthNotifierState(
          error: e.toString().replaceFirst('Exception: ', ''));
      onFailed(state.error ?? 'Password reset request failed');
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> verifyAndBindPhone(String verificationId, String code) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      await _repository.verifyAndLinkPhone(verificationId, code);
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(
          error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> resetPasswordWithPhoneOtp({
    required String verificationId,
    required String code,
    required String newPassword,
  }) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      final credential =
          await _repository.verifyAndSignInWithPhone(verificationId, code);
      final user = credential.user;
      if (user == null) {
        throw Exception('Failed to authenticate user via phone OTP');
      }
      await user.updatePassword(newPassword);
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> sendRegistrationOtp(
    String phone, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
  }) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();
      final isReg = await _repository.isPhoneRegistered(formattedPhone);
      if (isReg) {
        state = const AuthNotifierState(
            error: 'This phone number is already registered');
        onFailed(state.error!);
        return false;
      }
      await _repository.sendFirebaseOtp(
        phone: formattedPhone,
        onCodeSent: (verificationId, _) {
          state = const AuthNotifierState();
          onCodeSent(verificationId);
        },
        onFailed: (e) {
          state = AuthNotifierState(error: e.message ?? 'Verification failed');
          onFailed(state.error!);
        },
      );
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      onFailed(state.error!);
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> registerWithPhoneOtp({
    required String verificationId,
    required String code,
    required String email,
    required String password,
    required String role,
    String? shopName,
    required String phone,
  }) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      final credential =
          await _repository.verifyAndSignInWithPhone(verificationId, code);
      final user = credential.user;
      if (user == null) {
        throw Exception('Failed to authenticate user via phone OTP');
      }

      final emailCred = EmailAuthProvider.credential(
        email: email.trim(),
        password: password.trim(),
      );
      await user.linkWithCredential(emailCred);

      final uid = user.uid;
      final updates = {
        'email': email.trim(),
        'phone': phone.trim(),
        'verified': true,
        'createdAt': ServerValue.timestamp,
      };
      await FirebaseDatabase.instance.ref('users').child(uid).update(updates);
      await FirebaseDatabase.instance
          .ref('phones')
          .child(phone.trim())
          .set(uid);

      if (role == 'merchant') {
        await FirebaseDatabase.instance.ref('shop').child(uid).set({
          'name': shopName ?? 'My Shop',
          'description': 'Welcome to our shop!',
          'address': '',
          'phone': phone.trim(),
          'isOpen': true,
          'isVerified': false,
        });
      }

      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      await _repository.logout();
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } catch (e) {
      await _repository.logout();
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  /// Completes a sign-in that required a TOTP second factor.
  Future<bool> completeMfaChallenge(
      MultiFactorResolver resolver, String code) async {
    state = const AuthNotifierState(isLoading: true, error: null);
    try {
      final credential = await _repository.resolveMfaSignIn(resolver, code);
      final user = credential.user;
      if (user == null) {
        state = const AuthNotifierState(error: 'User not found.');
        return false;
      }

      final dbRoles = await _roleService.getRolesFromDatabase(user.uid);
      final targetRole = dbRoles['merchant'] == true ? 'merchant' : 'customer';

      final isValid = await _repository.validateUserSession(user, targetRole);
      if (!isValid) {
        await _repository.logout();
        state = const AuthNotifierState(
          error: 'Access Denied: Invalid account role or suspended.',
        );
        return false;
      }

      final roles = await _roleService.getRoles(forceRefresh: true);
      if (roles['customer'] != true && roles['merchant'] != true) {
        await _repository.logout();
        state = const AuthNotifierState(error: 'Access Denied: Invalid account role.');
        return false;
      }
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: ErrorHandler.getMessage(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  /// Clears a pending MFA challenge (e.g. when the user cancels).
  void clearMfa() {
    state = AuthNotifierState(isLoading: false, error: state.error);
  }

  Future<void> logout() async {
    await _repository.logout();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthNotifierState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);

  return FirebaseDatabase.instance
      .ref('users')
      .child(user.uid)
      .onValue
      .map((DatabaseEvent event) {
    if (event.snapshot.value == null) return null;
    return Map<String, dynamic>.from(event.snapshot.value as Map);
  });
});
