import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// `true` = at least one active network interface; `false` = no connectivity.
/// Defaults to `true` (optimistic) until the first stream event arrives.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).maybeWhen(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    orElse: () => true,
  );
});
