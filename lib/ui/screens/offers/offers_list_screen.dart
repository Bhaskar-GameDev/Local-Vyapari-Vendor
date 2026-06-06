import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/providers/offer_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/responsive.dart';
import '../../common/app_animations.dart';
import '../../common/error_view.dart';
import '../../common/incremental_list.dart';
import '../../common/skeleton.dart';
import 'create_offer_screen.dart';
import '../../../l10n/app_localizations.dart';

class OffersListScreen extends ConsumerWidget {
  const OffersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offersState = ref.watch(offersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activeOffers),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints:
                const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
            child: offersState.when(
              data: (offers) {
                if (offers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        l10n.noOffers,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }

                final hPad = Responsive.horizontalPadding(context);
                final cols = Responsive.offerGridColumns(context);
                final padding = EdgeInsets.fromLTRB(hPad, hPad, hPad, hPad);

                Widget buildOfferTile(int index) {
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
                          AppPageRoute.slideUp<void>(
                              CreateOfferScreen(existingOffer: offer)),
                        );
                      },
                      child: Card(
                        margin: cols == 1
                            ? const EdgeInsets.only(bottom: AppSpacing.sm)
                            : EdgeInsets.zero,
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
                              color: (effectiveActive
                                      ? AppColors.warning
                                      : Colors.grey)
                                  .withValues(alpha: 0.15),
                              borderRadius: AppRadius.borderSm,
                            ),
                            child: Icon(
                              Icons.local_offer_rounded,
                              color: effectiveActive
                                  ? AppColors.warning
                                  : Colors.grey,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            offer.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: effectiveActive
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              isExpired
                                  ? l10n.expiredOn(DateFormat('MMM dd, hh:mm a')
                                      .format(endDate))
                                  : l10n.offerSubtitle(
                                      offer.discountPercentage.toInt(),
                                      DateFormat('MMM dd, hh:mm a')
                                          .format(endDate)),
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpired
                                    ? AppColors.error
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: effectiveActive,
                                onChanged: isExpired
                                    ? null
                                    : (val) {
                                        ref
                                            .read(offersProvider.notifier)
                                            .toggleOfferAvailability(
                                                offer.id, val);
                                      },
                                activeThumbColor: AppColors.success,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppColors.error),
                                onPressed: () {
                                  ref
                                      .read(offersProvider.notifier)
                                      .deleteOffer(offer.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return IncrementalList(
                  itemCount: offers.length,
                  builder: (context, controller, visibleCount) {
                    if (cols == 2) {
                      return GridView.builder(
                        controller: controller,
                        padding: padding,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.55,
                        ),
                        itemCount: visibleCount,
                        itemBuilder: (_, i) => buildOfferTile(i),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      padding: padding,
                      itemCount: visibleCount,
                      itemBuilder: (_, i) => buildOfferTile(i),
                    );
                  },
                );
              },
              loading: () => _buildShimmerLoading(context),
              error: (error, stack) => ErrorView(
                error: error,
                title: l10n.failedToLoadOffers,
                onRetry: () => ref.invalidate(offersProvider),
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
            AppPageRoute.slideUp<void>(const CreateOfferScreen()),
          );
        },
        icon: const Icon(Icons.local_offer),
        label: Text(l10n.createOffer),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final cols = Responsive.offerGridColumns(context);
    const shimmerCard = Skeleton(
      child: Card(
        child: SkeletonBox(height: 84, radius: 0),
      ),
    );
    if (cols == 2) {
      return GridView.builder(
        padding: EdgeInsets.all(hPad),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => shimmerCard,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(hPad),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: shimmerCard,
      ),
    );
  }
}
