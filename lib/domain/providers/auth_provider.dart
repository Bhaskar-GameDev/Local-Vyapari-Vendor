import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
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

  Future<String> sendOtp(String phone) async {
    final random = DateTime.now().microsecondsSinceEpoch % 1000000;
    final otp = random.toString().padLeft(6, '0');
    final expiresAt = DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch;
    
    await FirebaseDatabase.instance.ref('otps').child(phone).set({
      'otp': otp,
      'expiresAt': expiresAt,
    });
    
    await SmsService.sendOtp(phone, otp);
    
    return otp;
  }

  Future<bool> verifyOtp(String phone, String code) async {
    final snapshot = await FirebaseDatabase.instance.ref('otps').child(phone).get();
    if (!snapshot.exists || snapshot.value == null) return false;
    
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final storedOtp = data['otp']?.toString();
    final expiresAt = data['expiresAt'] as int?;
    
    if (storedOtp == code && expiresAt != null && DateTime.now().millisecondsSinceEpoch < expiresAt) {
      await FirebaseDatabase.instance.ref('otps').child(phone).remove();
      return true;
    }
    
    return false;
  }

  Future<UserCredential> loginWithPhone(String phone) async {
    final email = '${phone.replaceAll('+', '')}@localvyapari.com';
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: 'otp_default_pass_123',
    );
  }

  Future<UserCredential> registerWithPhone(String phone, {String? shopName}) async {
    final email = '${phone.replaceAll('+', '')}@localvyapari.com';
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: 'otp_default_pass_123',
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
    
    return await sendOtp(formattedPhone);
  }

  Future<bool> verifyAndBindPhone(String phone, String code) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");
    
    final formattedPhone = phone.trim();
    
    final verified = await verifyOtp(formattedPhone, code);
    if (!verified) return false;
    
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
        return 'An account with this email already exists.';
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
  return ref.watch(authRepositoryProvider).authStateChanges;
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

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.login(email, password);
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    }
  }

  Future<bool> register(String email, String password, String role, String? shopName, {String? phone}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.register(email, password, role, shopName: shopName, phone: phone);
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    }
  }

  Future<bool> loginWithPhoneAndPassword(String phone, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();
      
      // Look up the uid mapped to this phone number
      final phoneSnapshot = await FirebaseDatabase.instance.ref('phones').child(formattedPhone).get();
      if (!phoneSnapshot.exists || phoneSnapshot.value == null) {
        state = const AuthNotifierState(error: 'This phone number is not registered');
        return false;
      }
      
      final uid = phoneSnapshot.value as String;
      
      // Look up the user's registered email
      final emailSnapshot = await FirebaseDatabase.instance.ref('users').child(uid).child('email').get();
      if (!emailSnapshot.exists || emailSnapshot.value == null) {
        state = const AuthNotifierState(error: 'No email found linked to this phone number');
        return false;
      }
      
      final realEmail = emailSnapshot.value as String;
      
      // Log in using the resolved real email and password
      await _repository.login(realEmail, password);
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    }
  }

  Future<bool> registerWithPhoneAndPassword({
    required String phone,
    required String password,
    required String shopName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
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
    }
  }

  Future<bool> checkPhone(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isRegistered = await _repository.isPhoneRegistered(phone);
      state = const AuthNotifierState();
      return isRegistered;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    }
  }

  Future<String?> requestOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final otp = await _repository.sendOtp(phone);
      state = const AuthNotifierState();
      return otp;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return null;
    }
  }

  Future<bool> verifyAndSubmit({
    required String phone,
    required String code,
    required bool isRegistered,
    String? shopName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final verified = await _repository.verifyOtp(phone, code);
      if (!verified) {
        state = const AuthNotifierState(error: 'Invalid or expired OTP');
        return false;
      }
      
      if (isRegistered) {
        await _repository.loginWithPhone(phone);
      } else {
        await _repository.registerWithPhone(phone, shopName: shopName);
      }
      state = const AuthNotifierState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    }
  }

  Future<bool> bindEmail(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.bindEmail(email);
      state = const AuthNotifierState();
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<String?> requestBindPhoneOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final otp = await _repository.requestBindPhoneOtp(phone);
      state = const AuthNotifierState();
      return otp;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      return null;
    }
  }

  Future<String?> requestPasswordResetOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isReg = await _repository.isPhoneRegistered(phone);
      if (!isReg) {
        state = const AuthNotifierState(error: 'This phone number is not registered');
        return null;
      }
      final otp = await _repository.sendOtp(phone);
      state = const AuthNotifierState();
      return otp;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      return null;
    }
  }

  Future<bool> verifyAndBindPhone(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);
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
  }

  Future<bool> verifyOtpOnly(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _repository.verifyOtp(phone, code);
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
  }

  Future<bool> resetPasswordWithOtp({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();

      // Check if phone number exists in our system first
      final isReg = await _repository.isPhoneRegistered(formattedPhone);
      if (!isReg) {
        state = const AuthNotifierState(error: 'This phone number is not registered');
        return false;
      }

      // Write reset request to DB
      final resetRef = FirebaseDatabase.instance.ref('password_resets').child(formattedPhone);
      await resetRef.set({
        'otp': otp.trim(),
        'newPassword': newPassword.trim(),
        'status': 'pending',
      });

      // Wait/Listen for status update (success or error)
      final completer = Completer<bool>();
      StreamSubscription<DatabaseEvent>? subscription;

      subscription = resetRef.child('status').onValue.listen((event) {
        final val = event.snapshot.value as String?;
        if (val == 'success') {
          completer.complete(true);
          subscription?.cancel();
        } else if (val == 'error') {
          resetRef.child('error').get().then((errSnap) {
            final errorMsg = errSnap.value as String? ?? 'Failed to reset password';
            completer.completeError(errorMsg);
            subscription?.cancel();
          });
        }
      });

      // Timeout after 15 seconds in case backend doesn't respond
      final success = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          subscription?.cancel();
          throw TimeoutException('Password reset request timed out. Please try again.');
        },
      );

      state = const AuthNotifierState();
      return success;
    } catch (e) {
      state = AuthNotifierState(error: e.toString().replaceFirst('Exception: ', ''));
      return false;
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
