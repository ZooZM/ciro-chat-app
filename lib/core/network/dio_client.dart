import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../core/network/socket_service.dart';
import '../../core/di/injection.dart';
import '../error/revocation_exception.dart';
import '../services/token_refresh_service.dart';

// Decoupled global callback to enforce redirect cleanly outside Dio's module graph
void Function()? globalOnUnauthorizedRedirect;

@lazySingleton
class DioClient {
  final Dio _dio;
  final AuthLocalDataSource _authLocal;

  DioClient(this._authLocal, this._dio) {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 120),
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
            try {
              final newAccess = await getIt<TokenRefreshService>().refreshTokens();

              // The old socket connection is using the expired JWT. Silently
              // tear it down and reconnect with the new token so the user
              // never experiences a WebSocket interruption mid-session.
              try {
                final socketService = getIt<SocketService>();
                socketService.disconnect();
                socketService.connect(newAccess);
                debugPrint('[DioClient] Socket silently re-synced with new token');
              } catch (socketErr) {
                debugPrint('[DioClient] Socket re-sync failed: $socketErr');
              }

              e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
              final retryResponse = await _dio.fetch(e.requestOptions);
              return handler.resolve(retryResponse);
            } on RevocationException catch (revoked) {
              debugPrint('[DioClient] Session revoked: $revoked');
              // Full V-A teardown (including deleteTokens) runs inside
              // globalOnUnauthorizedRedirect → AuthCubit.logOut().
              globalOnUnauthorizedRedirect?.call();
            } catch (refreshErr) {
              // Transient failure path inside the service was exhausted, OR
              // the service threw a non-revocation error. Either way, do NOT
              // delete tokens — let the request fail naturally so the session
              // survives. The next request will trigger another refresh.
              debugPrint('[DioClient] Refresh failed (non-terminal): $refreshErr');
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
