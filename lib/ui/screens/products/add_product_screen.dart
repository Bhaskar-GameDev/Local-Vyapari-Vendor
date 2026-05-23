import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/providers/product_provider.dart';
import '../../../data/models/product_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/cloudinary_service.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final ProductModel? existingProduct;
  const AddProductScreen({super.key, this.existingProduct});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _offerPriceController = TextEditingController();
  final _stockController = TextEditingController();
  
  String _selectedCategory = 'Groceries';
  final List<String> _categories = ['Groceries', 'Electronics', 'Clothing', 'Pharmacy', 'Other'];
  
  final List<dynamic> _images = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    if (p != null) {
      _nameController.text = p.name;
      _descController.text = p.description;
      _priceController.text = p.actualPrice.toString();
      _offerPriceController.text = p.offerPrice?.toString() ?? '';
      _stockController.text = p.stockQuantity.toString();
      if (_categories.contains(p.category)) {
        _selectedCategory = p.category;
      }
      _images.addAll(p.images);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _offerPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can add up to 5 images only', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    try {
      final List<XFile> pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          final remainingSlots = 5 - _images.length;
          final imagesToAdd = pickedFiles.take(remainingSlots).map((xFile) => File(xFile.path)).toList();
          _images.addAll(imagesToAdd);
          if (pickedFiles.length > remainingSlots) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Only up to 5 images can be added', style: TextStyle(color: Colors.white)),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 image', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<String> imageUrls = [];
      for (final image in _images) {
        if (image is File) {
          final imageUrl = await CloudinaryService.uploadImage(image.path);
          if (imageUrl == null) throw Exception("Image upload failed");
          imageUrls.add(imageUrl);
        } else if (image is String) {
          imageUrls.add(image);
        }
      }

      final newProduct = ProductModel(
        id: widget.existingProduct?.id ?? '', 
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
        actualPrice: double.parse(_priceController.text.trim()),
        offerPrice: _offerPriceController.text.trim().isNotEmpty ? double.parse(_offerPriceController.text.trim()) : null,
        stockQuantity: int.parse(_stockController.text.trim()),
        images: imageUrls,
        isActive: widget.existingProduct?.isActive ?? true,
      );

      if (widget.existingProduct != null) {
        await ref.read(productsProvider.notifier).updateProduct(newProduct);
      } else {
        await ref.read(productsProvider.notifier).addProduct(newProduct);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingProduct != null ? 'Product updated successfully!' : 'Product added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${widget.existingProduct!.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(productsProvider.notifier).deleteProduct(widget.existingProduct!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting product: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingProduct != null ? 'Edit Product' : 'Add New Product'),
        actions: widget.existingProduct != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _confirmDelete(context),
                ),
              ]
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
                    _buildImageUploader(),
                    AppSpacing.verticalLg,
                    CustomTextField(
                      label: 'Product Name',
                      controller: _nameController,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    AppSpacing.verticalMd,
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: AppRadius.borderMedium),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                    AppSpacing.verticalMd,
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'Actual Price (₹)',
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              if (double.tryParse(val) == null) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        AppSpacing.horizontalMd,
                        Expanded(
                          child: CustomTextField(
                            label: 'Offer Price (₹)',
                            controller: _offerPriceController,
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val != null && val.isNotEmpty && double.tryParse(val) == null) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalMd,
                    CustomTextField(
                      label: 'Stock Qty',
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (int.tryParse(val) == null) return 'Invalid';
                        return null;
                      },
                    ),
                    AppSpacing.verticalMd,
                    CustomTextField(
                      label: 'Description',
                      controller: _descController,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    AppSpacing.verticalXl,
                    PrimaryButton(
                      text: 'Publish Product',
                      isLoading: _isLoading,
                      onPressed: _submitProduct,
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

  Widget _buildImageUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Product Images (${_images.length}/5)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'Min 1, Max 5',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        AppSpacing.verticalSm,
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length + (_images.length < 5 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _images.length) {
                return _buildAddImageCard();
              }
              
              final image = _images[index];
              return _buildImageCard(image, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageCard() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.borderMedium,
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.primary),
            AppSpacing.verticalXs,
            const Text(
              'Add Image',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(dynamic image, int index) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: AppRadius.borderMedium,
              child: image is File
                  ? Image.file(image, fit: BoxFit.cover)
                  : Image.network(image as String, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _images.removeAt(index);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
