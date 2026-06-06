// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shop_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ShopModel _$ShopModelFromJson(Map<String, dynamic> json) {
  return _ShopModel.fromJson(json);
}

/// @nodoc
mixin _$ShopModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  String? get logoUrl => throw _privateConstructorUsedError;
  bool get isVerified => throw _privateConstructorUsedError;
  bool get isOpen => throw _privateConstructorUsedError;
  double? get rating => throw _privateConstructorUsedError;
  int? get totalReviews => throw _privateConstructorUsedError;
  String? get openingTime => throw _privateConstructorUsedError;
  String? get closingTime => throw _privateConstructorUsedError;
  String? get ownerId => throw _privateConstructorUsedError;
  String? get bannerUrl => throw _privateConstructorUsedError;
  int? get createdAt => throw _privateConstructorUsedError;
  String? get geohash => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get state => throw _privateConstructorUsedError;
  String? get pincode => throw _privateConstructorUsedError;
  String? get placeId => throw _privateConstructorUsedError;

  /// Serializes this ShopModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShopModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShopModelCopyWith<ShopModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShopModelCopyWith<$Res> {
  factory $ShopModelCopyWith(ShopModel value, $Res Function(ShopModel) then) =
      _$ShopModelCopyWithImpl<$Res, ShopModel>;
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String address,
      String phone,
      double? latitude,
      double? longitude,
      String? logoUrl,
      bool isVerified,
      bool isOpen,
      double? rating,
      int? totalReviews,
      String? openingTime,
      String? closingTime,
      String? ownerId,
      String? bannerUrl,
      int? createdAt,
      String? geohash,
      String? city,
      String? state,
      String? pincode,
      String? placeId});
}

/// @nodoc
class _$ShopModelCopyWithImpl<$Res, $Val extends ShopModel>
    implements $ShopModelCopyWith<$Res> {
  _$ShopModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShopModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? address = null,
    Object? phone = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? logoUrl = freezed,
    Object? isVerified = null,
    Object? isOpen = null,
    Object? rating = freezed,
    Object? totalReviews = freezed,
    Object? openingTime = freezed,
    Object? closingTime = freezed,
    Object? ownerId = freezed,
    Object? bannerUrl = freezed,
    Object? createdAt = freezed,
    Object? geohash = freezed,
    Object? city = freezed,
    Object? state = freezed,
    Object? pincode = freezed,
    Object? placeId = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: freezed == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: freezed == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      logoUrl: freezed == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isVerified: null == isVerified
          ? _value.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      isOpen: null == isOpen
          ? _value.isOpen
          : isOpen // ignore: cast_nullable_to_non_nullable
              as bool,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      totalReviews: freezed == totalReviews
          ? _value.totalReviews
          : totalReviews // ignore: cast_nullable_to_non_nullable
              as int?,
      openingTime: freezed == openingTime
          ? _value.openingTime
          : openingTime // ignore: cast_nullable_to_non_nullable
              as String?,
      closingTime: freezed == closingTime
          ? _value.closingTime
          : closingTime // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: freezed == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
      bannerUrl: freezed == bannerUrl
          ? _value.bannerUrl
          : bannerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      geohash: freezed == geohash
          ? _value.geohash
          : geohash // ignore: cast_nullable_to_non_nullable
              as String?,
      city: freezed == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String?,
      state: freezed == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String?,
      pincode: freezed == pincode
          ? _value.pincode
          : pincode // ignore: cast_nullable_to_non_nullable
              as String?,
      placeId: freezed == placeId
          ? _value.placeId
          : placeId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ShopModelImplCopyWith<$Res>
    implements $ShopModelCopyWith<$Res> {
  factory _$$ShopModelImplCopyWith(
          _$ShopModelImpl value, $Res Function(_$ShopModelImpl) then) =
      __$$ShopModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String address,
      String phone,
      double? latitude,
      double? longitude,
      String? logoUrl,
      bool isVerified,
      bool isOpen,
      double? rating,
      int? totalReviews,
      String? openingTime,
      String? closingTime,
      String? ownerId,
      String? bannerUrl,
      int? createdAt,
      String? geohash,
      String? city,
      String? state,
      String? pincode,
      String? placeId});
}

/// @nodoc
class __$$ShopModelImplCopyWithImpl<$Res>
    extends _$ShopModelCopyWithImpl<$Res, _$ShopModelImpl>
    implements _$$ShopModelImplCopyWith<$Res> {
  __$$ShopModelImplCopyWithImpl(
      _$ShopModelImpl _value, $Res Function(_$ShopModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of ShopModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? address = null,
    Object? phone = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? logoUrl = freezed,
    Object? isVerified = null,
    Object? isOpen = null,
    Object? rating = freezed,
    Object? totalReviews = freezed,
    Object? openingTime = freezed,
    Object? closingTime = freezed,
    Object? ownerId = freezed,
    Object? bannerUrl = freezed,
    Object? createdAt = freezed,
    Object? geohash = freezed,
    Object? city = freezed,
    Object? state = freezed,
    Object? pincode = freezed,
    Object? placeId = freezed,
  }) {
    return _then(_$ShopModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: freezed == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: freezed == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      logoUrl: freezed == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isVerified: null == isVerified
          ? _value.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      isOpen: null == isOpen
          ? _value.isOpen
          : isOpen // ignore: cast_nullable_to_non_nullable
              as bool,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      totalReviews: freezed == totalReviews
          ? _value.totalReviews
          : totalReviews // ignore: cast_nullable_to_non_nullable
              as int?,
      openingTime: freezed == openingTime
          ? _value.openingTime
          : openingTime // ignore: cast_nullable_to_non_nullable
              as String?,
      closingTime: freezed == closingTime
          ? _value.closingTime
          : closingTime // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: freezed == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
      bannerUrl: freezed == bannerUrl
          ? _value.bannerUrl
          : bannerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      geohash: freezed == geohash
          ? _value.geohash
          : geohash // ignore: cast_nullable_to_non_nullable
              as String?,
      city: freezed == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String?,
      state: freezed == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as String?,
      pincode: freezed == pincode
          ? _value.pincode
          : pincode // ignore: cast_nullable_to_non_nullable
              as String?,
      placeId: freezed == placeId
          ? _value.placeId
          : placeId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ShopModelImpl implements _ShopModel {
  const _$ShopModelImpl(
      {required this.id,
      required this.name,
      required this.description,
      required this.address,
      required this.phone,
      this.latitude,
      this.longitude,
      this.logoUrl,
      this.isVerified = false,
      this.isOpen = true,
      this.rating,
      this.totalReviews,
      this.openingTime,
      this.closingTime,
      this.ownerId,
      this.bannerUrl,
      this.createdAt,
      this.geohash,
      this.city,
      this.state,
      this.pincode,
      this.placeId});

  factory _$ShopModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShopModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final String address;
  @override
  final String phone;
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  final String? logoUrl;
  @override
  @JsonKey()
  final bool isVerified;
  @override
  @JsonKey()
  final bool isOpen;
  @override
  final double? rating;
  @override
  final int? totalReviews;
  @override
  final String? openingTime;
  @override
  final String? closingTime;
  @override
  final String? ownerId;
  @override
  final String? bannerUrl;
  @override
  final int? createdAt;
  @override
  final String? geohash;
  @override
  final String? city;
  @override
  final String? state;
  @override
  final String? pincode;
  @override
  final String? placeId;

  @override
  String toString() {
    return 'ShopModel(id: $id, name: $name, description: $description, address: $address, phone: $phone, latitude: $latitude, longitude: $longitude, logoUrl: $logoUrl, isVerified: $isVerified, isOpen: $isOpen, rating: $rating, totalReviews: $totalReviews, openingTime: $openingTime, closingTime: $closingTime, ownerId: $ownerId, bannerUrl: $bannerUrl, createdAt: $createdAt, geohash: $geohash, city: $city, state: $state, pincode: $pincode, placeId: $placeId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShopModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.isOpen, isOpen) || other.isOpen == isOpen) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.totalReviews, totalReviews) ||
                other.totalReviews == totalReviews) &&
            (identical(other.openingTime, openingTime) ||
                other.openingTime == openingTime) &&
            (identical(other.closingTime, closingTime) ||
                other.closingTime == closingTime) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.bannerUrl, bannerUrl) ||
                other.bannerUrl == bannerUrl) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.geohash, geohash) || other.geohash == geohash) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.pincode, pincode) || other.pincode == pincode) &&
            (identical(other.placeId, placeId) || other.placeId == placeId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        description,
        address,
        phone,
        latitude,
        longitude,
        logoUrl,
        isVerified,
        isOpen,
        rating,
        totalReviews,
        openingTime,
        closingTime,
        ownerId,
        bannerUrl,
        createdAt,
        geohash,
        city,
        state,
        pincode,
        placeId
      ]);

  /// Create a copy of ShopModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShopModelImplCopyWith<_$ShopModelImpl> get copyWith =>
      __$$ShopModelImplCopyWithImpl<_$ShopModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShopModelImplToJson(
      this,
    );
  }
}

abstract class _ShopModel implements ShopModel {
  const factory _ShopModel(
      {required final String id,
      required final String name,
      required final String description,
      required final String address,
      required final String phone,
      final double? latitude,
      final double? longitude,
      final String? logoUrl,
      final bool isVerified,
      final bool isOpen,
      final double? rating,
      final int? totalReviews,
      final String? openingTime,
      final String? closingTime,
      final String? ownerId,
      final String? bannerUrl,
      final int? createdAt,
      final String? geohash,
      final String? city,
      final String? state,
      final String? pincode,
      final String? placeId}) = _$ShopModelImpl;

  factory _ShopModel.fromJson(Map<String, dynamic> json) =
      _$ShopModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  String get address;
  @override
  String get phone;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  String? get logoUrl;
  @override
  bool get isVerified;
  @override
  bool get isOpen;
  @override
  double? get rating;
  @override
  int? get totalReviews;
  @override
  String? get openingTime;
  @override
  String? get closingTime;
  @override
  String? get ownerId;
  @override
  String? get bannerUrl;
  @override
  int? get createdAt;
  @override
  String? get geohash;
  @override
  String? get city;
  @override
  String? get state;
  @override
  String? get pincode;
  @override
  String? get placeId;

  /// Create a copy of ShopModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShopModelImplCopyWith<_$ShopModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
