import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../data/models/analytics_model.dart';
import 'auth_provider.dart';

final analyticsProvider = StreamProvider<AnalyticsModel>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(const AnalyticsModel());

  final databaseRef = FirebaseDatabase.instance.ref('analytics').child(user.uid);
  databaseRef.keepSynced(true);

  return databaseRef.onValue.map((event) {
    if (event.snapshot.value == null) {
      return const AnalyticsModel();
    }
    
    try {
      final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
      final totals = rawData['totals'] != null 
          ? Map<String, dynamic>.from(rawData['totals'] as Map) 
          : <String, dynamic>{};
      final daily = rawData['daily'] != null 
          ? Map<String, dynamic>.from(rawData['daily'] as Map) 
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
      print('Error parsing analytics: $e\n$stack');
      return const AnalyticsModel();
    }
  });
});
