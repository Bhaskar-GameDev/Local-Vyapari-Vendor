import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

class CloudinaryService {
  static const String _cloudName = 'drn2kxnrz';
  static const String _apiKey = '927593687989798';
  static const String _apiSecret = 'cV_hIAno_zl_MGSeG5e7rPhutBs';
  static const String _uploadUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  static Future<String?> uploadImage(String filePath) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Cloudinary requires the parameters to be sorted alphabetically to generate the signature.
      // Since we only have 'timestamp', the string to sign is exactly: "timestamp={timestamp}{api_secret}"
      final stringToSign = "timestamp=$timestamp$_apiSecret";
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'api_key': _apiKey,
        'timestamp': timestamp,
        'signature': signature,
      });

      final dio = Dio();
      final response = await dio.post(_uploadUrl, data: formData);

      if (response.statusCode == 200) {
        return response.data['secure_url']; 
      }
      return null;
    } catch (e) {
      print('Cloudinary Upload Error: $e');
      return null;
    }
  }
}
