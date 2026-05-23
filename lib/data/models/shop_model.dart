import 'package:freezed_annotation/freezed_annotation.dart';

part 'shop_model.freezed.dart';
part 'shop_model.g.dart';

@freezed
class ShopModel with _$ShopModel {
  const factory ShopModel({
    required String id,
    required String name,
    required String description,
    required String address,
    required String phone,
    double? latitude,
    double? longitude,
    String? logoUrl,
    @Default(false) bool isVerified,
    @Default(true) bool isOpen,
    String? openingTime,
    String? closingTime,
  }) = _ShopModel;

  factory ShopModel.fromJson(Map<String, dynamic> json) => _$ShopModelFromJson(json);
}
