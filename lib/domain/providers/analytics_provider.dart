import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/analytics_model.dart';
import 'auth_provider.dart';

final analyticsProvider = StreamProvider<AnalyticsModel>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(const AnalyticsModel());

  final uid = user.uid;

  // Keep totals synced (small node — always useful offline)
  FirebaseDatabase.instance.ref('analytics/$uid/totals').keepSynced(true);

  // For daily stats: only query the last 30 days, don't keepSynced the full history
  final thirtyDaysAgo = DateTime.now()
      .subtract(const Duration(days: 30))
      .toIso8601String()
      .split('T')[0];

  final dailyRef = FirebaseDatabase.instance
      .ref('analytics/$uid/daily')
      .orderByKey()
      .startAt(thirtyDaysAgo);

  final totalsRef = FirebaseDatabase.instance.ref('analytics/$uid/totals');

  return totalsRef.onValue.asyncMap((totalsEvent) async {
    try {
      final dailySnapshot = await dailyRef.get();
      final totalsVal = totalsEvent.snapshot.value;
      final dailyVal = dailySnapshot.value;

      final totals = totalsVal != null
          ? Map<String, dynamic>.from(totalsVal as Map)
          : <String, dynamic>{};
      final daily = dailyVal != null
          ? Map<String, dynamic>.from(dailyVal as Map)
          : <String, dynamic>{};

      final dailyMap = Map<String, DailyStat>.from(
        daily.map((key, val) {
          final valMap = Map<String, dynamic>.from(val as Map);
          return MapEntry(
            key,
            DailyStat.fromJson(valMap),
          );
        }),
      );

      return AnalyticsModel(
        totalViews: (totals['views'] as num?)?.toInt() ?? 0,
        totalClicks: (totals['clicks'] as num?)?.toInt() ?? 0,
        daily: dailyMap,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Error parsing analytics: $e\n$stack');
      }
      return const AnalyticsModel();
    }
  });
});
