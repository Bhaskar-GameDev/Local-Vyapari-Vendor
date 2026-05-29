import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

class ProductRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('products');

  String? get _currentShopId => _auth.currentUser?.uid;

  /// Realtime stream — pushes updates the instant Firebase changes for this shop ID
  Stream<List<ProductModel>> watchProductsForShop(String shopId) {
    _dbRef.child(shopId).keepSynced(true);
    
    return _dbRef.child(shopId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) return <ProductModel>[];

      // Parse per-item so one malformed record can't blank the whole list.
      final products = <ProductModel>[];
      data.forEach((key, value) {
        if (value is! Map) return;
        try {
          final productData = Map<String, dynamic>.from(value);
          productData['id'] = key;
          products.add(ProductModel.fromJson(productData));
        } catch (e) {
          if (kDebugMode) debugPrint('Error parsing product $key: $e');
        }
      });
      return products;
    });
  }

  Future<void> addProduct(ProductModel product) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception("User not authenticated");
    
    final data = product.toJson()..remove('id');
    await _dbRef.child(shopId).push().set(data);
  }

  Future<void> updateProduct(ProductModel product) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception("User not authenticated");
    
    final data = product.toJson()..remove('id');
    await _dbRef.child(shopId).child(product.id).update(data);
  }

  Future<void> deleteProduct(String productId) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception("User not authenticated");
    
    await _dbRef.child(shopId).child(productId).remove();
  }

  Future<void> updateProductStatus(String productId, bool isActive) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception("User not authenticated");
    
    await _dbRef.child(shopId).child(productId).update({'isActive': isActive});
  }
}
