import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';

class CloudinaryService {
  static const String _cloudName = 'drn2kxnrz';
  static const String _uploadUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
  static final Dio _dio = Dio();

  static Future<String?> uploadImage(String filePath, {Function(int, int)? onSendProgress}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getCloudinarySignature');
      final response = await callable.call();
      final result = Map<String, dynamic>.from(response.data as Map);
      final signature = result['signature'] as String;
      final timestamp = (result['timestamp'] as num).toInt();

      print('[CloudinaryService] Signature: $signature, Timestamp: $timestamp');

      // 2. Upload file
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'timestamp': timestamp,
        'signature': signature,
      });

      final uploadResponse = await _dio.post(
        _uploadUrl,
        data: formData,
        onSendProgress: onSendProgress,
      );

      if (uploadResponse.statusCode == 200) {
        return uploadResponse.data['secure_url'] as String?; 
      }
      return null;
    } catch (e) {
      if (e is DioException) {
        print('Cloudinary Upload Error Response: ${e.response?.data}');
        print('Cloudinary Upload Response Headers: ${e.response?.headers}');
      }
      print('Cloudinary Upload Error: $e');
      return null;
    }
  }
}
