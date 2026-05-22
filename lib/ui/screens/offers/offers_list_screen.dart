import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../domain/providers/offer_provider.dart';
import '../../../core/theme/app_colors.dart';
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
      body: offersState.when(
        data: (offers) {
          if (offers.isEmpty) {
            return const Center(child: Text('No active offers. Create a flash sale!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: (effectiveActive ? AppColors.warning : Colors.grey).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.local_offer, color: effectiveActive ? AppColors.warning : Colors.grey),
                      ),
                      title: Text(offer.title, style: TextStyle(fontWeight: FontWeight.bold, color: effectiveActive ? null : Colors.grey)),
                      subtitle: Text(
                        isExpired 
                            ? 'Expired on ${DateFormat('MMM dd, hh:mm a').format(endDate)}' 
                            : '${offer.discountPercentage}% OFF • Ends ${DateFormat('MMM dd, hh:mm a').format(endDate)}',
                        style: TextStyle(color: isExpired ? AppColors.error : null),
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
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
        error: (error, stack) => Center(child: Text('Error: $error')),
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
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 90,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
