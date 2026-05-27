import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../core/services/role_service.dart';

// ─── Repository ───────────────────────────────────────────────────────────────
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Stream of auth state changes — null means logged out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<UserCredential> register(String email, String password, String role, {String? shopName, String? phone}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final uid = credential.user?.uid;
    if (uid != null) {
      final updates = {
        'email': email.trim(),
        'createdAt': ServerValue.timestamp,
      };
      if (phone != null && phone.isNotEmpty) {
        updates['phone'] = phone.trim();
        updates['verified'] = true;
      }
      
      await FirebaseDatabase.instance.ref('users').child(uid).set(updates);

      if (phone != null && phone.isNotEmpty) {
        await FirebaseDatabase.instance.ref('phones').child(phone.trim()).set(uid);
      }

      if (role == 'merchant') {
        await FirebaseDatabase.instance.ref('shop').child(uid).set({
          'name': shopName ?? 'My Shop',
          'description': 'Welcome to our shop!',
          'address': '',
          'phone': phone ?? '',
          'isOpen': true,
          'isVerified': false,
        });
      }
    }
    return credential;
  }

  Future<bool> isMerchantUser(User user) async {
    final roles = await RoleService.instance.getRoles(forceRefresh: true);
    return roles['merchant'] == true;
  }

  // --- Native Firebase Phone Auth Support ---

  Future<bool> isPhoneRegistered(String phone) async {
    final snapshot = await FirebaseDatabase.instance.ref('phones').child(phone).get();
    return snapshot.exists && snapshot.value != null;
  }

  Future<String> resolveLoginEmailForPhone(String phone) async {
    final result = await _functions.httpsCallable('resolvePhoneLoginEmail').call({
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
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final user = _auth.currentUser;
          if (user != null) {
            await user.linkWithCredential(credential);
            // Update database records
            await FirebaseDatabase.instance.ref('users').child(user.uid).update({
              'phone': phone,
              'verified': true,
            });
            await FirebaseDatabase.instance.ref('phones').child(phone).set(user.uid);
          } else {
            await _auth.signInWithCredential(credential);
          }
        } catch (_) {}
      },
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> verifyAndSignInWithPhone(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> verifyAndLinkPhone(String verificationId, String smsCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    await user.linkWithCredential(credential);

    // Update database records
    final phone = user.phoneNumber ?? '';
    if (phone.isNotEmpty) {
      await FirebaseDatabase.instance.ref('users').child(user.uid).update({
        'phone': phone,
        'verified': true,
      });
      await FirebaseDatabase.instance.ref('phones').child(phone).set(user.uid);
    }
  }

  // --- Bind Email & Phone Support ---

  Future<void> bindEmail(String email) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");
    
    await FirebaseDatabase.instance.ref('users').child(uid).child('email').set(email.trim());
    
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(email.trim());
    } catch (e) {
      print("Firebase Auth email update: $e");
    }
  }

  Future<void> logout() async => await _auth.signOut();

  String mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'This email address is already registered. If it is registered as a customer, please sign in with your password to upgrade to a merchant account.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication error. Please try again.';
    }
  }

  String mapFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'invalid-argument':
        return e.message ?? 'Invalid request.';
      case 'resource-exhausted':
        return e.message ?? 'Too many attempts. Please try again later.';
      case 'not-found':
        return e.message ?? 'Requested record was not found.';
      case 'failed-precondition':
        return e.message ?? 'This action cannot be completed right now.';
      case 'unavailable':
        return e.message ?? 'OTP delivery is unavailable right now. Please try again later.';
      case 'internal':
        return e.message ?? 'OTP delivery failed. Please try again later.';
      case 'permission-denied':
        return e.message ?? 'Access denied for this account.';
      default:
        return e.message ?? 'Request failed. Please try again.';
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Stream provider that reacts to Firebase auth state in real-time
final authStateProvider = StreamProvider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

// ─── Auth State ───────────────────────────────────────────────────────────────
class AuthNotifierState {
  final bool isLoading;
  final String? error;

  const AuthNotifierState({this.isLoading = false, this.error});

  AuthNotifierState copyWith({bool? isLoading, String? error}) =>
      AuthNotifierState(isLoading: isLoading ?? this.isLoading, error: error);
}

class AuthNotifier extends StateNotifier<AuthNotifierState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthNotifierState());

  void clearError() {
    state = AuthNotifierState(isLoading: state.isLoading, error: null);
  }


  Future<bool> login(String email, String password) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final credential = await _repository.login(email, password);

      final user = credential.user;
      if (user == null) {
        state = const AuthNotifierState(error: 'User not found.');
        return false;
      }

      final roles = await RoleService.instance.getRoles(forceRefresh: true);
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
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } on FirebaseFunctionsException catch (e) {
      state = AuthNotifierState(error: _repository.mapFunctionsError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }
  Future<bool> register(String email, String password, String role, String? shopName, {String? phone}) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      if (phone != null && phone.isNotEmpty) {
        final formattedPhone = phone.trim();
        final isPhoneReg = await _repository.isPhoneRegistered(formattedPhone);
        if (isPhoneReg) {
          state = const AuthNotifierState(
            error: 'This phone number is already registered. If it is registered as a customer, please sign in with your password to upgrade to a merchant account.',
          );
          return false;
        }
      }
      await _repository.register(email, password, role, shopName: shopName, phone: phone);
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }


  Future<bool> loginWithPhoneAndPassword(String phone, String password) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();

      final realEmail = await _repository.resolveLoginEmailForPhone(formattedPhone);
      final credential = await _repository.login(realEmail, password);
      final user = credential.user;

      if (user == null) {
        state = const AuthNotifierState(error: 'User not found.');
        return false;
      }

      final roles = await RoleService.instance.getRoles(forceRefresh: true);
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
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } on FirebaseFunctionsException catch (e) {
      state = AuthNotifierState(error: _repository.mapFunctionsError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }
  Future<bool> registerWithPhoneAndPassword({
    required String phone,
    required String password,
    required String shopName,
  }) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();
      final cleanedPhone = formattedPhone.replaceAll(RegExp(r'\D'), '');
      final email = '${cleanedPhone}@localvyapari.com';

      await _repository.register(email, password, 'merchant', shopName: shopName);
      
      final uid = _repository.currentUser?.uid;
      if (uid != null) {
        await FirebaseDatabase.instance.ref('users').child(uid).update({
          'phone': formattedPhone,
          'verified': true,
        });
        await FirebaseDatabase.instance.ref('phones').child(formattedPhone).set(uid);
      }
      
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> checkPhone(String phone) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final isRegistered = await _repository.isPhoneRegistered(phone);
      state = const AuthNotifierState();
      return isRegistered;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    }
    finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> requestOtp(
    String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    state = AuthNotifierState(isLoading: true, error: null);
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
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      if (isRegistered) {
        await _repository.verifyAndSignInWithPhone(verificationId, code);
      } else {
        final credential = await _repository.verifyAndSignInWithPhone(verificationId, code);
        final user = credential.user;
        if (user != null) {
          final phoneNum = phone ?? user.phoneNumber ?? '';
          final email = '${phoneNum.replaceAll('+', '')}@localvyapari.com';

          await FirebaseDatabase.instance.ref('users').child(user.uid).set({
            'email': email,
            'phone': phoneNum,
            'createdAt': ServerValue.timestamp,
            'verified': true,
          });

          await FirebaseDatabase.instance.ref('phones').child(phoneNum).set(user.uid);

          await FirebaseDatabase.instance.ref('shop').child(user.uid).set({
            'name': shopName ?? 'My Shop',
            'description': 'Welcome to our shop!',
            'address': '',
            'phone': phoneNum,
            'isOpen': true,
            'isVerified': false,
          });
        }
      }
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> bindEmail(String email) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      await _repository.bindEmail(email);
      state = const AuthNotifierState();
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> requestBindPhoneOtp(
    String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final uid = _repository.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      final formattedPhone = phone.trim();
      
      final existingUidSnapshot = await FirebaseDatabase.instance.ref('phones').child(formattedPhone).get();
      if (existingUidSnapshot.exists && existingUidSnapshot.value != uid) {
        throw Exception("This phone number is already linked to another account");
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
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      onFailed(state.error ?? 'Verification failed');
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> requestPasswordResetOtp(
    String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();
      final isReg = await _repository.isPhoneRegistered(formattedPhone);
      if (!isReg) {
        state = const AuthNotifierState(error: 'This phone number is not registered');
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
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      onFailed(state.error!);
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      onFailed(state.error ?? 'Password reset request failed');
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> verifyAndBindPhone(String verificationId, String code) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      await _repository.verifyAndLinkPhone(verificationId, code);
      state = const AuthNotifierState();
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
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
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final credential = await _repository.verifyAndSignInWithPhone(verificationId, code);
      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to authenticate user via phone OTP");
      }
      await user.updatePassword(newPassword);
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
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
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();
      final isReg = await _repository.isPhoneRegistered(formattedPhone);
      if (isReg) {
        state = const AuthNotifierState(error: 'This phone number is already registered');
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
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final credential = await _repository.verifyAndSignInWithPhone(verificationId, code);
      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to authenticate user via phone OTP");
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
      await FirebaseDatabase.instance.ref('users').child(uid).set(updates);
      await FirebaseDatabase.instance.ref('phones').child(phone.trim()).set(uid);
      
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
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      await _repository.logout();
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthNotifierState>((ref) {
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
      .map((event) {
        if (event.snapshot.value == null) return null;
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      });
});
