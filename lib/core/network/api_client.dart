import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient() : _dio = Dio(BaseOptions(
    baseUrl: 'https://local-vyapari-838cd-default-rtdb.firebaseio.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add JWT token here
        // final token = await SecureStorage.getToken();
        // options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        // Handle global errors, e.g., token expiration
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}
