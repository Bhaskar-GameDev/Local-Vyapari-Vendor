import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../domain/providers/offer_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../common/app_animations.dart';
import 'create_offer_screen.dart';

class OffersListScreen extends ConsumerWidget {
  const OffersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersState = ref.watch(offersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Offers'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
            child: offersState.when(
              data: (offers) {
                if (offers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'No active offers. Create a flash sale!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppDimensions.horizontalPadding),
                  itemCount: offers.length,
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    final endDate = DateTime.parse(offer.endDate);
                    final isExpired = endDate.isBefore(DateTime.now());
                    final effectiveActive = offer.isActive && !isExpired;

                    return FadeInSlide(
                      duration: const Duration(milliseconds: 400),
                      delay: Duration(milliseconds: index * 60),
                      slideOffset: 16,
                      child: ScaleOnTap(
                        onTap: () {
                          Navigator.push(
                            context,
                            AppPageRoute.slideUp(CreateOfferScreen(existingOffer: offer)),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: (effectiveActive ? AppColors.warning : Colors.grey).withOpacity(0.15),
                                borderRadius: AppRadius.borderSm,
                              ),
                              child: Icon(
                                Icons.local_offer_rounded,
                                color: effectiveActive ? AppColors.warning : Colors.grey,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              offer.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: effectiveActive ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                isExpired 
                                    ? 'Expired on ${DateFormat('MMM dd, hh:mm a').format(endDate)}' 
                                    : '${offer.discountPercentage.toInt()}% OFF • Ends ${DateFormat('MMM dd, hh:mm a').format(endDate)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isExpired ? AppColors.error : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: effectiveActive,
                                  onChanged: isExpired ? null : (val) {
                                    ref.read(offersProvider.notifier).toggleOfferAvailability(offer.id, val);
                                  },
                                  activeColor: AppColors.success,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                  onPressed: () {
                                    ref.read(offersProvider.notifier).deleteOffer(offer.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => _buildShimmerLoading(),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('Error: $error', style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_offer_fab',
        onPressed: () {
          Navigator.push(
            context,
            AppPageRoute.slideUp(const CreateOfferScreen()),
          );
        },
        icon: const Icon(Icons.local_offer),
        label: const Text('Create Offer'),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.horizontalPadding),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              height: 84,
              padding: const EdgeInsets.all(AppSpacing.md),
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
