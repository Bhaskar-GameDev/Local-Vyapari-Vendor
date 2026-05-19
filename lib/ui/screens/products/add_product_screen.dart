import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/providers/product_provider.dart';
import '../../../data/models/product_model.dart';
import '../../../core/theme/app_colors.dart';
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
  
  File? _selectedImage;
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null && (widget.existingProduct == null || widget.existingProduct!.images.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await CloudinaryService.uploadImage(_selectedImage!.path);
        if (imageUrl == null) throw Exception("Image upload failed");
      } else {
        imageUrl = widget.existingProduct!.images.first;
      }

      final newProduct = ProductModel(
        id: widget.existingProduct?.id ?? '', 
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
        actualPrice: double.parse(_priceController.text.trim()),
        offerPrice: _offerPriceController.text.trim().isNotEmpty ? double.parse(_offerPriceController.text.trim()) : null,
        stockQuantity: int.parse(_stockController.text.trim()),
        images: [imageUrl],
        isActive: widget.existingProduct?.isActive ?? true,
      );

      if (widget.existingProduct != null) {
        await ref.read(productsProvider.notifier).updateProduct(newProduct);
      } else {
        await ref.read(productsProvider.notifier).addProduct(newProduct);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.existingProduct != null ? 'Product updated successfully!' : 'Product added successfully!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e'), backgroundColor: AppColors.error),
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
        title: Text(widget.existingProduct != null ? 'Edit Product' : 'Add New Product'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageUploader(),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Product Name',
                controller: _nameController,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 16),
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
                  const SizedBox(width: 16),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Description',
                controller: _descController,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Publish Product',
                isLoading: _isLoading,
                onPressed: _submitProduct,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploader() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity),
              )
            : widget.existingProduct != null && widget.existingProduct!.images.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(widget.existingProduct!.images.first, fit: BoxFit.cover, width: double.infinity),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text('Tap to Upload Product Image', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
      ),
    );
  }
}
