import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/cloudinary_service.dart';
import '../../../data/models/shop_model.dart';
import '../../../domain/providers/shop_provider.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';
import '../auth/login_screen.dart';

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

  File? _logoFile;
  bool _isSaving = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingShop?.name ?? '');
    _descController = TextEditingController(text: widget.existingShop?.description ?? '');
    _addressController = TextEditingController(text: widget.existingShop?.address ?? '');
    _phoneController = TextEditingController(text: widget.existingShop?.phone ?? '');
    _latController = TextEditingController(
      text: widget.existingShop?.latitude != null ? widget.existingShop!.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: widget.existingShop?.longitude != null ? widget.existingShop!.longitude.toString() : '',
    );
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

  Future<void> _submitShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? logoUrl = widget.existingShop?.logoUrl;

      // 1. Upload new logo if selected
      if (_logoFile != null) {
        final uploadedUrl = await CloudinaryService.uploadImage(_logoFile!.path);
        if (uploadedUrl == null) throw Exception("Logo upload failed");
        logoUrl = uploadedUrl;
      }

      final shop = ShopModel(
        id: widget.existingShop?.id ?? '', // Handled by repository
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        latitude: double.tryParse(_latController.text),
        longitude: double.tryParse(_lngController.text),
        logoUrl: logoUrl,
        isVerified: widget.existingShop?.isVerified ?? false,
        isOpen: widget.existingShop?.isOpen ?? true,
      );

      // 2. Save shop details to DB and update state notifier
      final success = await ref.read(shopProvider.notifier).createOrUpdateShop(shop);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingShop != null
                ? 'Shop profile updated successfully!'
                : 'Shop storefront created successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (widget.existingShop != null) {
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
    final isEditing = widget.existingShop != null;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isEditing) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Welcome to Local Vyapari!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please fill in your business details to build your digital storefront and start listing products.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                
                // --- Logo Picker ---
                Center(
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
                            padding: const EdgeInsets.all(8),
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
                const SizedBox(height: 8),
                Text(
                  'Upload Shop Logo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // --- Business Details ---
                CustomTextField(
                  label: 'Business / Shop Name',
                  controller: _nameController,
                  prefixIcon: Icons.business_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Please enter business name' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Shop Description',
                  controller: _descController,
                  prefixIcon: Icons.description_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Please describe your shop' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Shop Address',
                  controller: _addressController,
                  prefixIcon: Icons.location_on_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Please enter complete address' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
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
                const SizedBox(height: 24),

                // --- Location Coordinates ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.map_outlined, color: AppColors.primary, size: 24),
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 8),
                      Text(
                        'Accurate GPS coordinates help nearby shoppers find your store on their maps.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 16),
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
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
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
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // --- Submit Button ---
                PrimaryButton(
                  text: isEditing ? 'Save Changes' : 'Create Storefront',
                  isLoading: _isSaving,
                  onPressed: _submitShop,
                ),
                const SizedBox(height: 16),

                // --- Logout Option (if first-time setup only) ---
                if (!isEditing) ...[
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
