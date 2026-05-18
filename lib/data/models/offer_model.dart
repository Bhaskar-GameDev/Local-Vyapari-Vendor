import 'package:freezed_annotation/freezed_annotation.dart';

part 'offer_model.freezed.dart';
part 'offer_model.g.dart';

@freezed
class OfferModel with _$OfferModel {
  const factory OfferModel({
    required String id,
    required String title,
    required String description,
    required double discountPercentage,
    required String startDate,
    required String endDate,
    String? linkedProductId,
    @Default(true) bool isActive,
  }) = _OfferModel;

  factory OfferModel.fromJson(Map<String, dynamic> json) => _$OfferModelFromJson(json);
}
