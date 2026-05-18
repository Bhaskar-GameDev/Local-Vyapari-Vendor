import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/providers/offer_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'create_offer_screen.dart';

class OffersListScreen extends ConsumerWidget {
  const OffersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersState = ref.watch(offersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Offers'),
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_offer, color: AppColors.warning),
                  ),
                  title: Text(offer.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${offer.discountPercentage}% OFF • Ends ${offer.endDate}'),
                  trailing: Switch(
                    value: offer.isActive,
                    onChanged: (val) {},
                    activeColor: AppColors.success,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_offer_fab',
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOfferScreen()));
        },
        icon: const Icon(Icons.local_offer),
        label: const Text('Create Offer'),
      ),
    );
  }
}
