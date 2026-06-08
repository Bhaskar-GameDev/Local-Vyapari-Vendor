import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  static const String _cloudName = 'drn2kxnrz';
  static final Dio _dio = Dio();

  // Signature cache to prevent duplicate Cloud Function calls
  static String? _cachedSignature;
  static int? _cachedTimestamp;
  static String? _cachedApiKey;
  static String? _cachedCloudName;
  static DateTime? _cacheTime;

  static Future<String?> uploadImage(String filePath,
      {ProgressCallback? onSendProgress}) async {
    try {
      final now = DateTime.now();
      final isCacheValid = _cachedSignature != null &&
          _cacheTime != null &&
          now.difference(_cacheTime!).inMinutes < 10;

      String? signature = _cachedSignature;
      int? timestamp = _cachedTimestamp;
      String? apiKey = _cachedApiKey;
      String? cloudName = _cachedCloudName;

      if (!isCacheValid) {
        final callable =
            FirebaseFunctions.instance.httpsCallable('getCloudinarySignature');
        final response = await callable.call<Map<dynamic, dynamic>>();
        final result = Map<String, dynamic>.from(response.data);
        signature = result['signature'] as String?;
        timestamp = (result['timestamp'] as num?)?.toInt();
        apiKey = result['apiKey'] as String?;
        cloudName = result['cloudName'] as String? ?? _cloudName;

        if (signature == null || timestamp == null || apiKey == null) {
          throw Exception(
              'Invalid Cloudinary signature response from getCloudinarySignature');
        }

        // Cache parameters
        _cachedSignature = signature;
        _cachedTimestamp = timestamp;
        _cachedApiKey = apiKey;
        _cachedCloudName = cloudName;
        _cacheTime = now;
      }

      final uploadUrl =
          'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

      if (kDebugMode) {
        debugPrint(
            '[CloudinaryService] Received upload signature at timestamp: $timestamp');
      }

      // 2. Upload file
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'timestamp': timestamp,
        'signature': signature,
        'api_key': apiKey,
      });

      final uploadResponse = await _dio.post<dynamic>(
        uploadUrl,
        data: formData,
        onSendProgress: onSendProgress,
      );

      if (uploadResponse.statusCode == 200) {
        return uploadResponse.data['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      if (e is DioException) {
        if (kDebugMode) {
          debugPrint('Cloudinary Upload Error Response: ${e.response?.data}');
          debugPrint(
              'Cloudinary Upload Response Headers: ${e.response?.headers}');
        }
      }
      if (kDebugMode) {
        debugPrint('Cloudinary Upload Error: $e');
      }
      return null;
    }
  }
}
