import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/cloudinary_service.dart';
import '../../../data/models/shop_model.dart';
import '../../../domain/providers/shop_provider.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';
import '../../common/app_animations.dart';

class SetupShopScreen extends ConsumerStatefulWidget {
  final ShopModel? existingShop;

  const SetupShopScreen({super.key, this.existingShop});

  @override
  ConsumerState<SetupShopScreen> createState() => _SetupShopScreenState();
}

class _SetupShopScreenState extends ConsumerState<SetupShopScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;

  File? _logoFile;
  bool _isSaving = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingShop?.name ?? '');
    _descController = TextEditingController(text: widget.existingShop?.description ?? '');
    _addressController = TextEditingController(text: widget.existingShop?.address ?? '');
    
    final user = FirebaseAuth.instance.currentUser;
    final initialPhone = widget.existingShop?.phone ?? user?.phoneNumber?.replaceAll('+91', '').replaceAll(' ', '') ?? '';
    _phoneController = TextEditingController(text: initialPhone);
    
    _latController = TextEditingController(
      text: widget.existingShop?.latitude != null ? widget.existingShop!.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: widget.existingShop?.longitude != null ? widget.existingShop!.longitude.toString() : '',
    );
    if (widget.existingShop?.openingTime != null) {
      _parseTime(widget.existingShop!.openingTime!, isOpening: true);
    }
    if (widget.existingShop?.closingTime != null) {
      _parseTime(widget.existingShop!.closingTime!, isOpening: false);
    }

    if (widget.existingShop == null && user != null) {
      _prefillFromDatabase(user.uid);
    }
  }

  Future<void> _prefillFromDatabase(String uid) async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('shop').child(uid).get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          setState(() {
            if (_nameController.text.isEmpty && data['name'] != null) {
              _nameController.text = data['name'].toString();
            }
            if (_descController.text.isEmpty && data['description'] != null) {
              _descController.text = data['description'].toString();
            }
            if (_phoneController.text.isEmpty && data['phone'] != null) {
              _phoneController.text = data['phone'].toString().replaceAll('+91', '').replaceAll(' ', '');
            }
            if (_addressController.text.isEmpty && data['address'] != null) {
              _addressController.text = data['address'].toString();
            }
            if (_latController.text.isEmpty && data['latitude'] != null) {
              _latController.text = data['latitude'].toString();
            }
            if (_lngController.text.isEmpty && data['longitude'] != null) {
              _lngController.text = data['longitude'].toString();
            }
            if (data['openingTime'] != null) {
              _parseTime(data['openingTime'].toString(), isOpening: true);
            }
            if (data['closingTime'] != null) {
              _parseTime(data['closingTime'].toString(), isOpening: false);
            }
          });
        }
      }
    } catch (_) {}
  }

  void _parseTime(String timeString, {required bool isOpening}) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1].split(' ')[0]));
        if (isOpening) {
          _openingTime = time;
        } else {
          _closingTime = time;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile != null) {
      setState(() => _logoFile = File(pickedFile.path));
    }
  }

  Future<void> _pickTime({required bool isOpening}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpening 
          ? (_openingTime ?? const TimeOfDay(hour: 9, minute: 0)) 
          : (_closingTime ?? const TimeOfDay(hour: 21, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select Time';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final position = await LocationService.getCurrentLocation();

      String addressStr = _addressController.text;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = [place.street, place.subLocality, place.locality, place.postalCode, place.country]
              .where((p) => p != null && p.isNotEmpty)
              .toList();
          if (parts.isNotEmpty) {
            addressStr = parts.join(', ');
          }
        }
      } catch (_) {}

      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
        if (addressStr.isNotEmpty) {
          _addressController.text = addressStr;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop coordinates updated!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch location: $errorMsg'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<bool> _verifyShopPhone(String phone) async {
    final phoneNum = phone.trim();
    final fullPhone = phoneNum.startsWith('+') ? phoneNum : '+91$phoneNum';

    final authNotifier = ref.read(authProvider.notifier);
    final completer = Completer<bool>();

    // Show request loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Requesting verification..."),
          ],
        ),
      ),
    );

    await authNotifier.requestBindPhoneOtp(
      fullPhone,
      onCodeSent: (verificationId) {
        // Dismiss requesting dialog
        Navigator.pop(context);

        // Show OTP dialog
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final codeController = TextEditingController();
            bool isVerifying = false;

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Verify Phone Number'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('We have sent a verification OTP to $fullPhone.'),
                      AppSpacing.verticalMd,
                      CustomTextField(
                        label: '6-Digit OTP',
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.lock_outline,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: isVerifying ? null : () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: isVerifying ? null : () async {
                        final code = codeController.text.trim();
                        if (code.length != 6) return;

                        setState(() => isVerifying = true);

                        final success = await authNotifier.verifyAndBindPhone(verificationId, code);

                        if (context.mounted) {
                          setState(() => isVerifying = false);
                          Navigator.pop(dialogContext, success);
                        }
                      },
                      child: isVerifying
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Verify'),
                    ),
                  ],
                );
              },
            );
          },
        ).then((verified) {
          completer.complete(verified ?? false);
        });
      },
      onFailed: (error) {
        // Dismiss requesting dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
        completer.complete(false);
      },
    );

    return completer.future;
  }

  Future<void> _submitShop() async {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.existingShop != null && 
                      widget.existingShop!.address.isNotEmpty;

    bool needVerification = !isEditing;
    if (needVerification) {
      final user = FirebaseAuth.instance.currentUser;
      final userPhone = user?.phoneNumber?.replaceAll('+91', '').replaceAll(' ', '').trim();
      final inputPhone = _phoneController.text.trim().replaceAll('+91', '').replaceAll(' ', '').trim();
      
      if (userPhone != null && userPhone.isNotEmpty && userPhone == inputPhone) {
        needVerification = false;
      } else {
        final uid = user?.uid;
        if (uid != null) {
          try {
            final snapshot = await FirebaseDatabase.instance.ref('users').child(uid).get();
            if (snapshot.exists && snapshot.value != null) {
              final userData = Map<String, dynamic>.from(snapshot.value as Map);
              final dbPhone = userData['phone']?.toString().replaceAll('+91', '').replaceAll(' ', '').trim();
              final isVerified = userData['verified'] == true;
              if (isVerified && dbPhone != null && dbPhone.isNotEmpty && dbPhone == inputPhone) {
                needVerification = false;
              }
            }
          } catch (_) {}
        }
      }
    }

    if (needVerification) {
      final verified = await _verifyShopPhone(_phoneController.text.trim());
      if (!verified) return;
    }

    setState(() => _isSaving = true);

    try {
      String? logoUrl = widget.existingShop?.logoUrl;

      if (_logoFile != null) {
        final uploadedUrl = await CloudinaryService.uploadImage(_logoFile!.path);
        if (uploadedUrl == null) throw Exception("Logo upload failed");
        logoUrl = uploadedUrl;
      }

      final shop = ShopModel(
        id: widget.existingShop?.id ?? '', 
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        latitude: double.tryParse(_latController.text),
        longitude: double.tryParse(_lngController.text),
        logoUrl: logoUrl,
        isVerified: widget.existingShop?.isVerified ?? false,
        isOpen: widget.existingShop?.isOpen ?? true,
        rating: widget.existingShop?.rating,
        totalReviews: widget.existingShop?.totalReviews,
        openingTime: _openingTime != null ? '${_openingTime!.hour.toString().padLeft(2, '0')}:${_openingTime!.minute.toString().padLeft(2, '0')}' : null,
        closingTime: _closingTime != null ? '${_closingTime!.hour.toString().padLeft(2, '0')}:${_closingTime!.minute.toString().padLeft(2, '0')}' : null,
      );

      await ref.read(shopRepositoryProvider).updateShopProfile(shop);

      // Securely upgrade user to merchant via Cloud Functions on initial setup
      final isEditing = widget.existingShop != null && 
                        widget.existingShop!.address.isNotEmpty;
      if (!isEditing) {
        final callable = FirebaseFunctions.instance.httpsCallable('assignMerchantRole');
        await callable.call();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Shop profile updated successfully!'
                : 'Shop storefront created successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (isEditing) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving shop profile: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingShop != null && 
                      widget.existingShop!.address.isNotEmpty && 
                      widget.existingShop!.latitude != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Shop Profile' : 'Set Up Your Shop'),
        automaticallyImplyLeading: isEditing,
        leading: isEditing
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.horizontalPadding,
              vertical: AppSpacing.md,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isEditing) Consumer(
                      builder: (context, ref, child) {
                        final profileState = ref.watch(userProfileProvider);
                        final profile = profileState.value;
                        final roles = profile?['roles'] as Map?;
                        final isMerchant = roles?['merchant'] == true;

                        if (profileState.hasValue && !isMerchant) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.08),
                                borderRadius: AppRadius.borderLg,
                                border: Border.all(
                                  color: AppColors.warning.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.warning,
                                    size: 24,
                                  ),
                                  AppSpacing.horizontalSm,
                                  Expanded(
                                    child: Text(
                                      'Merchant Profile Pending: Complete your shop setup to activate your vendor account.',
                                      style: TextStyle(
                                        color: AppColors.warning.withOpacity(0.9),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    if (!isEditing) ...[
                      AppSpacing.verticalXs,
                      FadeInSlide(
                        duration: const Duration(milliseconds: 500),
                        slideOffset: 20,
                        child: Text(
                          'Welcome to Local Vyapari!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      AppSpacing.verticalXs,
                      FadeInSlide(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 100),
                        slideOffset: 16,
                        child: Text(
                          'Please fill in your business details to build your digital storefront and start listing products.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    AppSpacing.verticalLg,
                    
                    // --- Logo Picker ---
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 150),
                      slideOffset: 16,
                      child: Center(
                        child: GestureDetector(
                          onTap: _pickLogo,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 56,
                                  backgroundColor: AppColors.surfaceElevated,
                                  backgroundImage: _logoFile != null
                                      ? FileImage(_logoFile!)
                                      : (widget.existingShop?.logoUrl != null
                                          ? NetworkImage(widget.existingShop!.logoUrl!)
                                          : null) as ImageProvider?,
                                  child: _logoFile == null && widget.existingShop?.logoUrl == null
                                      ? const Icon(Icons.storefront_rounded, size: 48, color: AppColors.primary)
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.verticalXs,
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 200),
                      slideOffset: 10,
                      child: Text(
                        'Upload Shop Logo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    AppSpacing.verticalXl,

                    // --- Business Details ---
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 250),
                      slideOffset: 16,
                      child: CustomTextField(
                        label: 'Business / Shop Name',
                        controller: _nameController,
                        prefixIcon: Icons.business_outlined,
                        validator: (val) => val == null || val.isEmpty ? 'Please enter business name' : null,
                      ),
                    ),
                    AppSpacing.verticalMd,
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 300),
                      slideOffset: 16,
                      child: CustomTextField(
                        label: 'Shop Description',
                        controller: _descController,
                        prefixIcon: Icons.description_outlined,
                        validator: (val) => val == null || val.isEmpty ? 'Please describe your shop' : null,
                      ),
                    ),
                    AppSpacing.verticalMd,
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 350),
                      slideOffset: 16,
                      child: CustomTextField(
                        label: 'Shop Address',
                        controller: _addressController,
                        prefixIcon: Icons.location_on_outlined,
                        validator: (val) => val == null || val.isEmpty ? 'Please enter complete address' : null,
                      ),
                    ),
                    AppSpacing.verticalMd,
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 400),
                      slideOffset: 16,
                      child: CustomTextField(
                        label: 'Contact Phone Number',
                        controller: _phoneController,
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please enter phone number';
                          if (val.replaceAll(RegExp(r'\D'), '').length < 10) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                    ),
                    AppSpacing.verticalLg,

                    // --- Shop Timings ---
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 420),
                      slideOffset: 16,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.borderLg,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 24),
                                AppSpacing.horizontalSm,
                                Expanded(
                                  child: Text(
                                    'Shop Timings',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.verticalXs,
                            Text(
                              'Let customers know when your shop is open.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            AppSpacing.verticalMd,
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickTime(isOpening: true),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Opens At',
                                        prefixIcon: const Icon(Icons.wb_sunny_outlined),
                                        border: OutlineInputBorder(
                                          borderRadius: AppRadius.borderMd,
                                        ),
                                      ),
                                      child: Text(_formatTime(_openingTime)),
                                    ),
                                  ),
                                ),
                                AppSpacing.horizontalSm,
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickTime(isOpening: false),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Closes At',
                                        prefixIcon: const Icon(Icons.nights_stay_outlined),
                                        border: OutlineInputBorder(
                                          borderRadius: AppRadius.borderMd,
                                        ),
                                      ),
                                      child: Text(_formatTime(_closingTime)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.verticalLg,

                    // --- Location Coordinates ---
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 450),
                      slideOffset: 16,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.borderLg,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.map_outlined, color: AppColors.primary, size: 24),
                                AppSpacing.horizontalSm,
                                Expanded(
                                  child: Text(
                                    'Geolocational Storefront',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.verticalXs,
                            Text(
                              'Accurate GPS coordinates help nearby shoppers find your store on their maps.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            AppSpacing.verticalMd,
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Latitude',
                                    controller: _latController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                  ),
                                ),
                                AppSpacing.horizontalSm,
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Longitude',
                                    controller: _lngController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.verticalMd,
                            ScaleOnTap(
                              child: ElevatedButton.icon(
                                onPressed: _isLocating ? null : _getCurrentLocation,
                                icon: _isLocating
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.my_location_rounded, size: 18),
                                label: const Text('Detect Current Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.verticalXl,

                    // --- Submit Button ---
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 500),
                      slideOffset: 16,
                      child: ScaleOnTap(
                        child: PrimaryButton(
                          text: isEditing ? 'Save Changes' : 'Create Storefront',
                          isLoading: _isSaving,
                          onPressed: _submitShop,
                        ),
                      ),
                    ),
                    AppSpacing.verticalMd,

                    // --- Logout Option (if first-time setup only) ---
                    if (!isEditing) ...[
                      FadeInSlide(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 550),
                        slideOffset: 16,
                        child: TextButton.icon(
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                          },
                          icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      AppSpacing.verticalMd,
                    ],
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
