import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/providers/offer_provider.dart';
import '../../../data/models/offer_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';

class CreateOfferScreen extends ConsumerStatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _discountController = TextEditingController();
  
  bool _isLoading = false;

  void _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final newOffer = OfferModel(
      id: '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      discountPercentage: double.parse(_discountController.text.trim()),
      startDate: DateTime.now().toIso8601String(),
      endDate: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      isActive: true,
    );

    try {
      await ref.read(offersProvider.notifier).addOffer(newOffer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer created!'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Flash Sale')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomTextField(
              label: 'Offer Title (e.g. Weekend Flash Sale)',
              controller: _titleController,
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Discount %',
              controller: _discountController,
              keyboardType: TextInputType.number,
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Description',
              controller: _descController,
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Launch Offer',
              isLoading: _isLoading,
              onPressed: _submitOffer,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}
