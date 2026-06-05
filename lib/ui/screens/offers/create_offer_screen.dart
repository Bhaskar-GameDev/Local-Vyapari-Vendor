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
import '../../common/error_dialog.dart';
import '../../../l10n/app_localizations.dart';

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

  bool _isFeatured = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final o = widget.existingOffer;
    if (o != null) {
      _titleController.text = o.title;
      _descController.text = o.description;
      _discountController.text = o.discountPercentage.toString();
      _isFeatured = o.isFeatured;
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
    final l10n = AppLocalizations.of(context);
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
      isFeatured: _isFeatured,
    );

    try {
      if (widget.existingOffer != null) {
        await ref.read(offersProvider.notifier).updateOffer(newOffer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.offerUpdated), backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      } else {
        await ref.read(offersProvider.notifier).addOffer(newOffer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.offerCreated), backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      }
    } catch (e, st) {
      if (mounted) {
        AppErrorDialog.fromError(
          context: context,
          error: e,
          stackTrace: st,
          title: l10n.couldNotSaveOffer,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingOffer != null ? l10n.editFlashSale : l10n.createFlashSale),
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
                      label: l10n.offerTitleLabel,
                      controller: _titleController,
                      validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                    ),
                    AppSpacing.verticalMd,
                    CustomTextField(
                      label: l10n.discountPercent,
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return l10n.required;
                        }
                        final discount = double.tryParse(val.trim());
                        if (discount == null) return l10n.invalid;
                        if (discount <= 0 || discount > 100) {
                          return l10n.discountRange;
                        }
                        return null;
                      },
                    ),
                    AppSpacing.verticalMd,
                    CustomTextField(
                      label: l10n.descriptionLabel,
                      controller: _descController,
                      validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                    ),
                    AppSpacing.verticalMd,
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                                      l10n.startsAt,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                    AppSpacing.verticalXs,
                                    Text(
                                      DateFormat('MMM dd, yyyy - hh:mm a').format(_startDate),
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final dt = await _pickDateTime(_startDate);
                                  if (dt != null) setState(() => _startDate = dt);
                                },
                                child: Text(l10n.change),
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
                                      l10n.endsAt,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                    AppSpacing.verticalXs,
                                    Text(
                                      DateFormat('MMM dd, yyyy - hh:mm a').format(_endDate),
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final dt = await _pickDateTime(_endDate);
                                  if (dt != null) setState(() => _endDate = dt);
                                },
                                child: Text(l10n.change),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.verticalMd,
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: AppRadius.borderMedium,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.campaign_rounded, color: AppColors.primary),
                          AppSpacing.horizontalSm,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.featureInPromoCarousel,
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                                ),
                                AppSpacing.verticalXs,
                                Text(
                                  l10n.featureInPromoCarouselDescription,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.horizontalSm,
                          Switch(
                            value: _isFeatured,
                            onChanged: (val) => setState(() => _isFeatured = val),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.verticalXl,
                    PrimaryButton(
                      text: widget.existingOffer != null ? l10n.updateOffer : l10n.launchOffer,
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
