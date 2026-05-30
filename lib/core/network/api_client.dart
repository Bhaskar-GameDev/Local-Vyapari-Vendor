import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../exceptions/error_handler.dart';

class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static void initialize() {
    _dio.options.baseUrl = 'https://us-central1-local-vyapari-437e0.cloudfunctions.net/';
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) {
        ErrorHandler.log(error, error.stackTrace);
        return handler.next(error);
      },
    ));
  }

  static Dio get instance => _dio;
}
