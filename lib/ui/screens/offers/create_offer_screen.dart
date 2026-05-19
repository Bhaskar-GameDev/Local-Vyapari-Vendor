import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  
  bool _isLoading = false;

  Future<DateTime?> _pickDateTime(DateTime initialDate) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final newOffer = OfferModel(
      id: '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      discountPercentage: double.parse(_discountController.text.trim()),
      startDate: _startDate.toIso8601String(),
      endDate: _endDate.toIso8601String(),
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_filled, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Starts At', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy - hh:mm a').format(_startDate),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final dt = await _pickDateTime(_startDate);
                          if (dt != null) setState(() => _startDate = dt);
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.event_busy, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ends At', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy - hh:mm a').format(_endDate),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final dt = await _pickDateTime(_endDate);
                          if (dt != null) setState(() => _endDate = dt);
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ],
              ),
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
