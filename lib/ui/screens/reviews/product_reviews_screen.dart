import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/product_review.dart';
import '../../../domain/providers/review_provider.dart';
import '../../common/app_animations.dart';

class ProductReviewsScreen extends ConsumerWidget {
  final ProductModel product;
  const ProductReviewsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(productReviewsProvider(product.id));
    final distribution = ref.watch(productRatingProvider(product.id));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${product.name} Reviews'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
            child: reviewsAsync.when(
              data: (reviews) {
                if (reviews.isEmpty) {
                  return FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.rate_review_outlined,
                                size: 64,
                                color: AppColors.primary,
                              ),
                            ),
                            AppSpacing.verticalLg,
                            Text(
                              'No Reviews Yet',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
                            ),
                            AppSpacing.verticalSm,
                            Text(
                              'Reviews and ratings for this product will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInSlide(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 100),
                        slideOffset: 10,
                        child: _ProductRatingBreakdownWidget(distribution: distribution),
                      ),
                      AppSpacing.verticalLg,
                      FadeInSlide(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 200),
                        slideOffset: 10,
                        child: Text(
                          'Customer Feedback (${reviews.length})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      AppSpacing.verticalSm,
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          return FadeInSlide(
                            duration: const Duration(milliseconds: 500),
                            delay: Duration(milliseconds: 250 + (index * 50)),
                            slideOffset: 15,
                            child: _ProductReviewCard(review: reviews[index]),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      AppSpacing.verticalMd,
                      Text(
                        'Error loading reviews: $err',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductRatingBreakdownWidget extends StatelessWidget {
  final RatingDistribution distribution;
  const _ProductRatingBreakdownWidget({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.borderMedium,
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    distribution.averageRating.toString(),
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: cs.onSurface),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starRating = index + 1;
                      return Icon(
                        Icons.star_rounded,
                        color: starRating <= distribution.averageRating.round()
                            ? AppColors.warning
                            : cs.outlineVariant,
                        size: 20,
                      );
                    }),
                  ),
                  AppSpacing.verticalXs,
                  Text(
                    '${distribution.totalCount} ratings',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(height: 90, width: 1, color: cs.outlineVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 3,
              child: Column(
                children: List.generate(5, (index) {
                  final starVal = 5 - index;
                  final count = distribution.distribution[starVal] ?? 0;
                  final percentage = distribution.totalCount == 0
                      ? 0.0
                      : count / distribution.totalCount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Text('$starVal', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        AppSpacing.horizontalXs,
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: cs.outlineVariant,
                              color: AppColors.warning,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: 20,
                          child: Text(
                            '$count',
                            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductReviewCard extends StatelessWidget {
  final ProductReview review;
  const _ProductReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final formattedDate = '${review.createdAt.day.toString().padLeft(2, '0')}/${review.createdAt.month.toString().padLeft(2, '0')}/${review.createdAt.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.borderMedium,
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    review.userDisplayName.isNotEmpty ? review.userDisplayName : 'Anonymous User',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderXs,
                  ),
                  child: Row(
                    children: [
                      Text(
                        review.rating.toString(),
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      AppSpacing.horizontalXs,
                      const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.verticalSm,
            Text(
              review.comment.isNotEmpty ? review.comment : 'No comment left.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
            AppSpacing.verticalSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formattedDate, style: TextStyle(color: cs.outline, fontSize: 11)),
                Icon(Icons.verified_user_outlined, size: 14, color: cs.outline),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
