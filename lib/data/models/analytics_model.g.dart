// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DailyStatImpl _$$DailyStatImplFromJson(Map<String, dynamic> json) =>
    _$DailyStatImpl(
      views: (json['views'] as num?)?.toInt() ?? 0,
      clicks: (json['clicks'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$DailyStatImplToJson(_$DailyStatImpl instance) =>
    <String, dynamic>{
      'views': instance.views,
      'clicks': instance.clicks,
    };

_$AnalyticsModelImpl _$$AnalyticsModelImplFromJson(Map<String, dynamic> json) =>
    _$AnalyticsModelImpl(
      totalViews: (json['totalViews'] as num?)?.toInt() ?? 0,
      totalClicks: (json['totalClicks'] as num?)?.toInt() ?? 0,
      daily: (json['daily'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, DailyStat.fromJson(e as Map<String, dynamic>)),
          ) ??
          const {},
    );

Map<String, dynamic> _$$AnalyticsModelImplToJson(
        _$AnalyticsModelImpl instance) =>
    <String, dynamic>{
      'totalViews': instance.totalViews,
      'totalClicks': instance.totalClicks,
      'daily': instance.daily,
    };
