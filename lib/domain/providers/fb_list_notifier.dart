import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

abstract class FBListNotifier<T> extends StateNotifier<AsyncValue<List<T>>> {
  final Ref _ref;
  StreamSubscription? _subscription;

  FBListNotifier(this._ref) : super(const AsyncValue.loading()) {
    _bindToUser(_ref.read(authStateProvider).value);
    _ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
      _bindToUser(next.value);
    });
  }

  Stream<List<T>> watchForUser(String uid);

  void _bindToUser(User? user) {
    _subscription?.cancel();
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    _subscription = watchForUser(user.uid).listen(
      (items) => state = AsyncValue.data(items),
      onError: (Object e, StackTrace st) => state = AsyncValue.error(e, st),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
