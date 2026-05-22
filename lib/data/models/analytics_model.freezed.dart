// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DailyStat _$DailyStatFromJson(Map<String, dynamic> json) {
  return _DailyStat.fromJson(json);
}

/// @nodoc
mixin _$DailyStat {
  int get views => throw _privateConstructorUsedError;
  int get clicks => throw _privateConstructorUsedError;

  /// Serializes this DailyStat to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DailyStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyStatCopyWith<DailyStat> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyStatCopyWith<$Res> {
  factory $DailyStatCopyWith(DailyStat value, $Res Function(DailyStat) then) =
      _$DailyStatCopyWithImpl<$Res, DailyStat>;
  @useResult
  $Res call({int views, int clicks});
}

/// @nodoc
class _$DailyStatCopyWithImpl<$Res, $Val extends DailyStat>
    implements $DailyStatCopyWith<$Res> {
  _$DailyStatCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? views = null,
    Object? clicks = null,
  }) {
    return _then(_value.copyWith(
      views: null == views
          ? _value.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      clicks: null == clicks
          ? _value.clicks
          : clicks // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DailyStatImplCopyWith<$Res>
    implements $DailyStatCopyWith<$Res> {
  factory _$$DailyStatImplCopyWith(
          _$DailyStatImpl value, $Res Function(_$DailyStatImpl) then) =
      __$$DailyStatImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int views, int clicks});
}

/// @nodoc
class __$$DailyStatImplCopyWithImpl<$Res>
    extends _$DailyStatCopyWithImpl<$Res, _$DailyStatImpl>
    implements _$$DailyStatImplCopyWith<$Res> {
  __$$DailyStatImplCopyWithImpl(
      _$DailyStatImpl _value, $Res Function(_$DailyStatImpl) _then)
      : super(_value, _then);

  /// Create a copy of DailyStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? views = null,
    Object? clicks = null,
  }) {
    return _then(_$DailyStatImpl(
      views: null == views
          ? _value.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      clicks: null == clicks
          ? _value.clicks
          : clicks // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyStatImpl implements _DailyStat {
  const _$DailyStatImpl({this.views = 0, this.clicks = 0});

  factory _$DailyStatImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyStatImplFromJson(json);

  @override
  @JsonKey()
  final int views;
  @override
  @JsonKey()
  final int clicks;

  @override
  String toString() {
    return 'DailyStat(views: $views, clicks: $clicks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyStatImpl &&
            (identical(other.views, views) || other.views == views) &&
            (identical(other.clicks, clicks) || other.clicks == clicks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, views, clicks);

  /// Create a copy of DailyStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyStatImplCopyWith<_$DailyStatImpl> get copyWith =>
      __$$DailyStatImplCopyWithImpl<_$DailyStatImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyStatImplToJson(
      this,
    );
  }
}

abstract class _DailyStat implements DailyStat {
  const factory _DailyStat({final int views, final int clicks}) =
      _$DailyStatImpl;

  factory _DailyStat.fromJson(Map<String, dynamic> json) =
      _$DailyStatImpl.fromJson;

  @override
  int get views;
  @override
  int get clicks;

  /// Create a copy of DailyStat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyStatImplCopyWith<_$DailyStatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AnalyticsModel _$AnalyticsModelFromJson(Map<String, dynamic> json) {
  return _AnalyticsModel.fromJson(json);
}

/// @nodoc
mixin _$AnalyticsModel {
  int get totalViews => throw _privateConstructorUsedError;
  int get totalClicks => throw _privateConstructorUsedError;
  Map<String, DailyStat> get daily => throw _privateConstructorUsedError;

  /// Serializes this AnalyticsModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnalyticsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalyticsModelCopyWith<AnalyticsModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalyticsModelCopyWith<$Res> {
  factory $AnalyticsModelCopyWith(
          AnalyticsModel value, $Res Function(AnalyticsModel) then) =
      _$AnalyticsModelCopyWithImpl<$Res, AnalyticsModel>;
  @useResult
  $Res call({int totalViews, int totalClicks, Map<String, DailyStat> daily});
}

/// @nodoc
class _$AnalyticsModelCopyWithImpl<$Res, $Val extends AnalyticsModel>
    implements $AnalyticsModelCopyWith<$Res> {
  _$AnalyticsModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalyticsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalViews = null,
    Object? totalClicks = null,
    Object? daily = null,
  }) {
    return _then(_value.copyWith(
      totalViews: null == totalViews
          ? _value.totalViews
          : totalViews // ignore: cast_nullable_to_non_nullable
              as int,
      totalClicks: null == totalClicks
          ? _value.totalClicks
          : totalClicks // ignore: cast_nullable_to_non_nullable
              as int,
      daily: null == daily
          ? _value.daily
          : daily // ignore: cast_nullable_to_non_nullable
              as Map<String, DailyStat>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AnalyticsModelImplCopyWith<$Res>
    implements $AnalyticsModelCopyWith<$Res> {
  factory _$$AnalyticsModelImplCopyWith(_$AnalyticsModelImpl value,
          $Res Function(_$AnalyticsModelImpl) then) =
      __$$AnalyticsModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int totalViews, int totalClicks, Map<String, DailyStat> daily});
}

/// @nodoc
class __$$AnalyticsModelImplCopyWithImpl<$Res>
    extends _$AnalyticsModelCopyWithImpl<$Res, _$AnalyticsModelImpl>
    implements _$$AnalyticsModelImplCopyWith<$Res> {
  __$$AnalyticsModelImplCopyWithImpl(
      _$AnalyticsModelImpl _value, $Res Function(_$AnalyticsModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of AnalyticsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalViews = null,
    Object? totalClicks = null,
    Object? daily = null,
  }) {
    return _then(_$AnalyticsModelImpl(
      totalViews: null == totalViews
          ? _value.totalViews
          : totalViews // ignore: cast_nullable_to_non_nullable
              as int,
      totalClicks: null == totalClicks
          ? _value.totalClicks
          : totalClicks // ignore: cast_nullable_to_non_nullable
              as int,
      daily: null == daily
          ? _value._daily
          : daily // ignore: cast_nullable_to_non_nullable
              as Map<String, DailyStat>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AnalyticsModelImpl implements _AnalyticsModel {
  const _$AnalyticsModelImpl(
      {this.totalViews = 0,
      this.totalClicks = 0,
      final Map<String, DailyStat> daily = const {}})
      : _daily = daily;

  factory _$AnalyticsModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnalyticsModelImplFromJson(json);

  @override
  @JsonKey()
  final int totalViews;
  @override
  @JsonKey()
  final int totalClicks;
  final Map<String, DailyStat> _daily;
  @override
  @JsonKey()
  Map<String, DailyStat> get daily {
    if (_daily is EqualUnmodifiableMapView) return _daily;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_daily);
  }

  @override
  String toString() {
    return 'AnalyticsModel(totalViews: $totalViews, totalClicks: $totalClicks, daily: $daily)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalyticsModelImpl &&
            (identical(other.totalViews, totalViews) ||
                other.totalViews == totalViews) &&
            (identical(other.totalClicks, totalClicks) ||
                other.totalClicks == totalClicks) &&
            const DeepCollectionEquality().equals(other._daily, _daily));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, totalViews, totalClicks,
      const DeepCollectionEquality().hash(_daily));

  /// Create a copy of AnalyticsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalyticsModelImplCopyWith<_$AnalyticsModelImpl> get copyWith =>
      __$$AnalyticsModelImplCopyWithImpl<_$AnalyticsModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnalyticsModelImplToJson(
      this,
    );
  }
}

abstract class _AnalyticsModel implements AnalyticsModel {
  const factory _AnalyticsModel(
      {final int totalViews,
      final int totalClicks,
      final Map<String, DailyStat> daily}) = _$AnalyticsModelImpl;

  factory _AnalyticsModel.fromJson(Map<String, dynamic> json) =
      _$AnalyticsModelImpl.fromJson;

  @override
  int get totalViews;
  @override
  int get totalClicks;
  @override
  Map<String, DailyStat> get daily;

  /// Create a copy of AnalyticsModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalyticsModelImplCopyWith<_$AnalyticsModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
