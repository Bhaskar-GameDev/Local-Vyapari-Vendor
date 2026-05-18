import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_model.freezed.dart';
part 'product_model.g.dart';

@freezed
class ProductModel with _$ProductModel {
  const factory ProductModel({
    required String id,
    required String name,
    required String description,
    required String category,
    required double actualPrice,
    double? offerPrice,
    required int stockQuantity,
    @Default([]) List<String> images,
    @Default(true) bool isActive,
  }) = _ProductModel;

  factory ProductModel.fromJson(Map<String, dynamic> json) => _$ProductModelFromJson(json);
}
