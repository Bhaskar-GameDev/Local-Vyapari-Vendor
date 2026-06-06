// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shop_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShopModelImpl _$$ShopModelImplFromJson(Map<String, dynamic> json) =>
    _$ShopModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      logoUrl: json['logoUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      isOpen: json['isOpen'] as bool? ?? true,
      rating: (json['rating'] as num?)?.toDouble(),
      totalReviews: (json['totalReviews'] as num?)?.toInt(),
      openingTime: json['openingTime'] as String?,
      closingTime: json['closingTime'] as String?,
      ownerId: json['ownerId'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      createdAt: (json['createdAt'] as num?)?.toInt(),
      geohash: json['geohash'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      placeId: json['placeId'] as String?,
    );

Map<String, dynamic> _$$ShopModelImplToJson(_$ShopModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'address': instance.address,
      'phone': instance.phone,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'logoUrl': instance.logoUrl,
      'isVerified': instance.isVerified,
      'isOpen': instance.isOpen,
      'rating': instance.rating,
      'totalReviews': instance.totalReviews,
      'openingTime': instance.openingTime,
      'closingTime': instance.closingTime,
      'ownerId': instance.ownerId,
      'bannerUrl': instance.bannerUrl,
      'createdAt': instance.createdAt,
      'geohash': instance.geohash,
      'city': instance.city,
      'state': instance.state,
      'pincode': instance.pincode,
      'placeId': instance.placeId,
    };
