import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<UserCredential> register(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
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

  Future<bool> register(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.register(email, password);
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

  Future<void> logout() async {
    await _repository.logout();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthNotifierState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
