// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OfferModelImpl _$$OfferModelImplFromJson(Map<String, dynamic> json) =>
    _$OfferModelImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      discountPercentage: (json['discountPercentage'] as num).toDouble(),
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
      linkedProductId: json['linkedProductId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$$OfferModelImplToJson(_$OfferModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'discountPercentage': instance.discountPercentage,
      'startDate': instance.startDate,
      'endDate': instance.endDate,
      'linkedProductId': instance.linkedProductId,
      'isActive': instance.isActive,
    };
