import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String baseurl = 'https://gateease.pythonanywhere.com';

final Dio dio = Dio(BaseOptions(
  baseUrl: baseurl,
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
  headers: {'Content-Type': 'application/json'},
));

void setupDioInterceptor() {
  dio.interceptors.clear();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
          // Fallback header for production servers that strip standard Authorization headers
          options.headers['X-Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) {
        if (error.response?.statusCode == 401) {}
        return handler.next(error);
      },
    ),
  );
}
