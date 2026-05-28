import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  static const String _cloudName = 'drn2kxnrz';
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
  static final Dio _dio = Dio();

  static Future<String?> uploadImage(String filePath,
      {ProgressCallback? onSendProgress}) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getCloudinarySignature');
      final response = await callable.call<Map<dynamic, dynamic>>();
      final result = Map<String, dynamic>.from(response.data);
      final signature = result['signature'] as String;
      final timestamp = (result['timestamp'] as num).toInt();
      final apiKey = result['apiKey'] as String? ?? '927593687989798';
      final cloudName = result['cloudName'] as String? ?? _cloudName;

      final uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

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
