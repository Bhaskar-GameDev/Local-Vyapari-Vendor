import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_model.freezed.dart';
part 'analytics_model.g.dart';

@freezed
class DailyStat with _$DailyStat {
  const factory DailyStat({
    @Default(0) int views,
    @Default(0) int clicks,
  }) = _DailyStat;

  factory DailyStat.fromJson(Map<String, dynamic> json) => _$DailyStatFromJson(json);
}

@freezed
class AnalyticsModel with _$AnalyticsModel {
  const factory AnalyticsModel({
    @Default(0) int totalViews,
    @Default(0) int totalClicks,
    @Default({}) Map<String, DailyStat> daily,
  }) = _AnalyticsModel;

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) => _$AnalyticsModelFromJson(json);
}
