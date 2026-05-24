import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/sms_service.dart';

// ─── Repository ───────────────────────────────────────────────────────────────
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        'role': role,
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

  // --- OTP Authentication Support ---

  Future<bool> isPhoneRegistered(String phone) async {
    final snapshot = await FirebaseDatabase.instance.ref('phones').child(phone).get();
    return snapshot.exists && snapshot.value != null;
  }

  Future<void> sendOtp(String phone) async {
    // Calling Cloud Function via HTTPS with ApiClient
    await ApiClient.instance.post('generateAndSendOtp', data: {'data': {'phone': phone}});
  }

  Future<String?> verifyOtp(String phone, String code) async {
    try {
      final response = await ApiClient.instance.post('verifyOtp', data: {'data': {'phone': phone, 'code': code}});
      if (response.data['result']['success'] == true) {
        return response.data['result']['customToken'] as String?;
      }
    } catch (e) {
      print('verifyOtp error: $e');
    }
    return null;
  }

  Future<UserCredential> loginWithCustomToken(String customToken) async {
    return await _auth.signInWithCustomToken(customToken);
  }

  Future<UserCredential> registerWithPhone(String phone, {String? shopName}) async {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final password = String.fromCharCodes(values.map((x) => 33 + (x % 94)));

    final email = '${phone.replaceAll('+', '')}@localvyapari.com';
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid != null) {
      await FirebaseDatabase.instance.ref('users').child(uid).set({
        'email': email,
        'phone': phone,
        'role': 'merchant',
        'createdAt': ServerValue.timestamp,
        'verified': true,
      });

      await FirebaseDatabase.instance.ref('phones').child(phone).set(uid);

      await FirebaseDatabase.instance.ref('shop').child(uid).set({
        'name': shopName ?? 'My Shop',
        'description': 'Welcome to our shop!',
        'address': '',
        'phone': phone,
        'isOpen': true,
        'isVerified': false,
      });
    }
    return credential;
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

  Future<String> requestBindPhoneOtp(String phone) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");
    
    final formattedPhone = phone.trim();
    
    final existingUidSnapshot = await FirebaseDatabase.instance.ref('phones').child(formattedPhone).get();
    if (existingUidSnapshot.exists && existingUidSnapshot.value != uid) {
      throw Exception("This phone number is already linked to another account");
    }
    
    await sendOtp(formattedPhone);
    return formattedPhone;
  }

  Future<bool> verifyAndBindPhone(String phone, String code) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");
    
    final formattedPhone = phone.trim();
    
    final verified = await verifyOtp(formattedPhone, code);
    if (verified == null) return false;
    
    await FirebaseDatabase.instance.ref('users').child(uid).update({
      'phone': formattedPhone,
      'verified': true,
    });
    
    await FirebaseDatabase.instance.ref('phones').child(formattedPhone).set(uid);
    
    return true;
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
}

// ─── Providers ────────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Stream provider that reacts to Firebase auth state in real-time
final authStateProvider = StreamProvider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges.asyncMap((user) async {
    if (user == null) return null;
    try {
      // TEMP BYPASS: Returning user immediately without checking merchant role
      return user;
      /*
      // Retry logic for newly registered users since the onCreate trigger takes a moment
      for (int i = 0; i < 5; i++) {
        final idTokenResult = await user.getIdTokenResult(true);
        final role = idTokenResult.claims?['role'] as String?;
        if (role == 'merchant') {
          return user;
        }
        if (i < 4) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      // If still no merchant role after retries
      await authRepo.logout();
      return null;
      */
    } catch (e) {
      await authRepo.logout();
      return null;
    }
  });
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
      
      // TEMP BYPASS: Commented out role check
      /*
      String? role;
      for (int i = 0; i < 5; i++) {
        final idTokenResult = await credential.user?.getIdTokenResult(true);
        role = idTokenResult?.claims?['role'] as String?;
        if (role == 'merchant') break;
        if (i < 4) await Future.delayed(const Duration(seconds: 1));
      }
      
      if (role != 'merchant') {
        await _repository.logout();
        state = const AuthNotifierState(
          error: 'Access Denied: This account is registered as a customer.',
        );
        return false;
      }
      */

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
      
      final phoneSnapshot = await FirebaseDatabase.instance.ref('phones').child(formattedPhone).get();
      if (!phoneSnapshot.exists || phoneSnapshot.value == null) {
        state = const AuthNotifierState(error: 'This phone number is not registered');
        return false;
      }
      
      final uid = phoneSnapshot.value as String;

      final emailSnapshot = await FirebaseDatabase.instance.ref('users').child(uid).child('email').get();
      if (!emailSnapshot.exists || emailSnapshot.value == null) {
        state = const AuthNotifierState(error: 'No email found linked to this phone number');
        return false;
      }
      
      final realEmail = emailSnapshot.value as String;
      
      final credential = await _repository.login(realEmail, password);
      
      // TEMP BYPASS: Commented out role check
      /*
      String? role;
      for (int i = 0; i < 5; i++) {
        final idTokenResult = await credential.user?.getIdTokenResult(true);
        role = idTokenResult?.claims?['role'] as String?;
        if (role == 'merchant') break;
        if (i < 4) await Future.delayed(const Duration(seconds: 1));
      }
      
      if (role != 'merchant') {
        await _repository.logout();
        state = const AuthNotifierState(
          error: 'Access Denied: This account is registered as a customer.',
        );
        return false;
      }
      */
      
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

  Future<bool> requestOtp(String phone) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      await _repository.sendOtp(phone);
      state = const AuthNotifierState();
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }


  Future<bool> verifyAndSubmit({
    required String phone,
    required String code,
    required bool isRegistered,
    String? shopName,
  }) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final customToken = await _repository.verifyOtp(phone, code);
      if (customToken == null) {
        state = const AuthNotifierState(error: 'Invalid or expired OTP');
        return false;
      }
      
      if (isRegistered) {
        await _repository.loginWithCustomToken(customToken);
      } else {
        await _repository.registerWithPhone(phone, shopName: shopName);
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
    }
    finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> requestBindPhoneOtp(String phone) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      await _repository.requestBindPhoneOtp(phone);
      state = const AuthNotifierState();
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> requestPasswordResetOtp(String phone) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final isReg = await _repository.isPhoneRegistered(phone);
      if (!isReg) {
        state = const AuthNotifierState(error: 'This phone number is not registered');
        return false;
      }
      await _repository.sendOtp(phone);
      state = const AuthNotifierState();
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> verifyAndBindPhone(String phone, String code) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final success = await _repository.verifyAndBindPhone(phone, code);
      if (!success) {
        state = const AuthNotifierState(error: 'Invalid or expired OTP');
        return false;
      }
      state = const AuthNotifierState();
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
    finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }

  Future<bool> verifyOtpOnly(String phone, String code) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      final success = await _repository.verifyOtp(phone, code);
      if (success == null) {
        state = const AuthNotifierState(error: 'Invalid or expired OTP');
        return false;
      }
      state = const AuthNotifierState();
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
    finally {
      state = AuthNotifierState(isLoading: false, error: state.error);
    }
  }


  Future<bool> resetPasswordWithOtp({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    state = AuthNotifierState(isLoading: true, error: null);
    try {
      await ApiClient.instance.post('resetPasswordWithOtp', data: {
        'data': {
          'phone': phone.trim(),
          'code': otp.trim(),
          'newPassword': newPassword.trim(),
        }
      });
      return true;
    } catch (e) {
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
