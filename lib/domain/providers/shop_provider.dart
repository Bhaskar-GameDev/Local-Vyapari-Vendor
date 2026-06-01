import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/shop_repository.dart';
import 'auth_provider.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) => ShopRepository());

final shopProvider = StreamProvider<ShopModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(shopRepositoryProvider).watchShopProfile(user.uid);
});

// Returns how long until the shop should next auto-open:
//   Duration.zero → opening time has already passed and we are still within hours (open now)
//   positive Duration → time remaining until opening time
//   null → cannot compute (no opening time set)
Duration? _delayUntilAutoOpen(String? openingTime, String? closingTime) {
  if (openingTime == null) return null;
  try {
    final openParts = openingTime.split(':');
    if (openParts.length < 2) return null;
    final now = DateTime.now();
    final openH = int.parse(openParts[0]);
    final openM = int.parse(openParts[1]);
    final openMins = openH * 60 + openM;
    final nowMins = now.hour * 60 + now.minute;

    if (nowMins >= openMins) {
      if (closingTime != null) {
        final closeParts = closingTime.split(':');
        if (closeParts.length >= 2) {
          final closeMins = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
          if (nowMins < closeMins) return Duration.zero; // currently within hours
        }
      } else {
        return Duration.zero; // no closing time — treat as open once past open time
      }
      // Past closing time today → schedule for tomorrow's opening
      return DateTime(now.year, now.month, now.day, openH, openM)
          .add(const Duration(days: 1))
          .difference(now);
    }
    // Before opening time today
    return DateTime(now.year, now.month, now.day, openH, openM).difference(now);
  } catch (_) {
    return null;
  }
}

// Writes isOpen=true unless the vendor manually closed the shop today.
Future<void> _tryAutoOpen(String uid, ShopModel shop) async {
  try {
    final snap = await FirebaseDatabase.instance.ref('shop/$uid/manuallyClosedAt').get();
    final manuallyClosedAt = snap.value as String?;
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (manuallyClosedAt == today) return; // respect explicit close
    await FirebaseDatabase.instance.ref('shop/$uid').update({'isOpen': true});
  } catch (_) {}
}

// Watches the shop and schedules (or immediately triggers) an auto-open at opening time.
// Must be watched from a long-lived widget (e.g. MainNavigation) to stay active.
final shopAutoOpenProvider = Provider<void>((ref) {
  Timer? timer;

  final user = ref.watch(authStateProvider).value;
  if (user == null) return;

  ref.listen<AsyncValue<ShopModel?>>(shopProvider, (_, shopAsync) {
    timer?.cancel();
    final shop = shopAsync.value;
    if (shop == null || shop.isOpen || shop.openingTime == null) return;

    final delay = _delayUntilAutoOpen(shop.openingTime, shop.closingTime);
    if (delay == null) return;

    if (delay == Duration.zero) {
      _tryAutoOpen(user.uid, shop);
    } else {
      timer = Timer(delay, () => _tryAutoOpen(user.uid, shop));
    }
  }, fireImmediately: true);

  ref.onDispose(() => timer?.cancel());
});
