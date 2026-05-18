// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductModelImpl _$$ProductModelImplFromJson(Map<String, dynamic> json) =>
    _$ProductModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      actualPrice: (json['actualPrice'] as num).toDouble(),
      offerPrice: (json['offerPrice'] as num?)?.toDouble(),
      stockQuantity: (json['stockQuantity'] as num).toInt(),
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$$ProductModelImplToJson(_$ProductModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'actualPrice': instance.actualPrice,
      'offerPrice': instance.offerPrice,
      'stockQuantity': instance.stockQuantity,
      'images': instance.images,
      'isActive': instance.isActive,
    };
