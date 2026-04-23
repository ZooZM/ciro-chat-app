import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../core/network/socket_service.dart';
import '../../core/di/injection.dart';

// Decoupled global callback to enforce redirect cleanly outside Dio's module graph
void Function()? globalOnUnauthorizedRedirect;

@lazySingleton
class DioClient {
  final Dio _dio;
  final AuthLocalDataSource _authLocal;

  DioClient(this._authLocal, this._dio) {
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
          final accessToken = await _authLocal.getAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final refreshToken = await _authLocal.getRefreshToken();
            
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                // Secondary isolated Dio instance strictly for token refresh to avoid infinity loops
                final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
                final response = await refreshDio.post('/auth/refresh', data: {
                  'refreshToken': refreshToken
                });
                
                final newAccess = response.data['accessToken'];
                final newRefresh = response.data['refreshToken'] ?? refreshToken;
                
                await _authLocal.saveTokens(accessToken: newAccess, refreshToken: newRefresh);

                // ── SOCKET RE-SYNC ──────────────────────────────────────────────
                // The old socket connection is using the expired JWT. Silently
                // tear it down and reconnect with the new token so the user
                // never experiences a WebSocket interruption mid-session.
                try {
                  final socketService = getIt<SocketService>();
                  socketService.disconnect();
                  socketService.connect(newAccess);
                  debugPrint('[DioClient] Socket silently re-synced with new token');
                } catch (socketErr) {
                  // Non-fatal: HTTP requests continue even if socket sync fails.
                  debugPrint('[DioClient] Socket re-sync failed: $socketErr');
                }
                // ──────────────────────────────────────────────────────────────

                // Resume the original failed HTTP request with the new token.
                e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                final retryResponse = await _dio.fetch(e.requestOptions);
                return handler.resolve(retryResponse);
              } catch (_) {
                // Completely expire the keychain payload. The refresh token is strictly dead.
                await _authLocal.deleteTokens();
                globalOnUnauthorizedRedirect?.call();
              }
            } else {
              // The keychain never possessed a refresh token
              await _authLocal.deleteTokens();
              globalOnUnauthorizedRedirect?.call();
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}

@module
abstract class AppModule {
  @lazySingleton
  Dio get dio => Dio();
}

@module
abstract class StorageModule {
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();
}
