import 'package:dio/dio.dart';
import 'package:local_vyapari_vendor/core/network/api_client.dart'; // Add actual import to ApiClient

class CloudinaryService {
  static const String _cloudName = 'drn2kxnrz';
  static const String _apiKey = '927593687989798';
  static const String _uploadUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
  static final Dio _dio = Dio();

  static Future<String?> uploadImage(String filePath, {Function(int, int)? onSendProgress}) async {
    try {
      // 1. Fetch signature from secure HTTPS Cloud Function using our ApiClient
      final response = await ApiClient.instance.post('getCloudinarySignature');
      final result = response.data['result'];
      
      final signature = result['signature'] as String;
      final timestamp = result['timestamp'] as int;

      print('[CloudinaryService] Signature: $signature, Timestamp: $timestamp');

      // 2. Upload file
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'api_key': _apiKey,
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
