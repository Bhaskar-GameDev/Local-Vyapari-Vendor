import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/providers/offer_provider.dart';
import '../../../data/models/offer_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';

class CreateOfferScreen extends ConsumerStatefulWidget {
  final OfferModel? existingOffer;
  const CreateOfferScreen({super.key, this.existingOffer});

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

  @override
  void initState() {
    super.initState();
    final o = widget.existingOffer;
    if (o != null) {
      _titleController.text = o.title;
      _descController.text = o.description;
      _discountController.text = o.discountPercentage.toString();
      try {
        _startDate = DateTime.parse(o.startDate);
        _endDate = DateTime.parse(o.endDate);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initialDate) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(DateTime.now()) ? DateTime.now() : initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
      id: widget.existingOffer?.id ?? '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      discountPercentage: double.parse(_discountController.text.trim()),
      startDate: _startDate.toIso8601String(),
      endDate: _endDate.toIso8601String(),
      isActive: widget.existingOffer?.isActive ?? true,
    );

    try {
      if (widget.existingOffer != null) {
        await ref.read(offersProvider.notifier).updateOffer(newOffer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offer updated!'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      } else {
        await ref.read(offersProvider.notifier).addOffer(newOffer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offer created!'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingOffer != null ? 'Edit Flash Sale' : 'Create Flash Sale'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.horizontalPadding,
            vertical: AppSpacing.md,
          ),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      label: 'Offer Title (e.g. Weekend Flash Sale)',
                      controller: _titleController,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    AppSpacing.verticalMd,
                    CustomTextField(
                      label: 'Discount %',
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    AppSpacing.verticalMd,
                    CustomTextField(
                      label: 'Description',
                      controller: _descController,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    AppSpacing.verticalMd,
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: AppRadius.borderMedium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time_filled_rounded, color: AppColors.primary),
                              AppSpacing.horizontalSm,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Starts At', 
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                    ),
                                    AppSpacing.verticalXs,
                                    Text(
                                      DateFormat('MMM dd, yyyy - hh:mm a').format(_startDate),
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                          const Divider(height: AppSpacing.lg),
                          Row(
                            children: [
                              const Icon(Icons.event_busy_rounded, color: AppColors.error),
                              AppSpacing.horizontalSm,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ends At', 
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                    ),
                                    AppSpacing.verticalXs,
                                    Text(
                                      DateFormat('MMM dd, yyyy - hh:mm a').format(_endDate),
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                    AppSpacing.verticalXl,
                    PrimaryButton(
                      text: widget.existingOffer != null ? 'Update Offer' : 'Launch Offer',
                      isLoading: _isLoading,
                      onPressed: _submitOffer,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
