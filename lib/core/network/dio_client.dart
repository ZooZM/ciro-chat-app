import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';

@lazySingleton
class DioClient {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  DioClient(this._secureStorage) : _dio = Dio() {
    _dio.options = BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://firstly-perforative-jaylah.ngrok-free.dev',
      ),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Bypasses ngrok's interception screen which causes CORS errors on web
      },
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Automatically read the accessToken and attach it to the Authorization header
          final accessToken = await _secureStorage.read(key: 'accessToken');
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            // For example, redirect to the auth screen or trigger a logout event.
            // Using appRouter directly here for demonstration, though normally you might
            // dispatch an event to your AuthBloc or use a NavigationService.
            appRouter.go('/auth');
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}

@module
abstract class StorageModule {
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();
}
