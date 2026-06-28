import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../error/revocation_exception.dart';
import '../theme/app_constants.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';

/// Coalesces concurrent refresh requests behind a single `Completer` and retries
/// transient failures with exponential backoff. Only an explicit backend
/// revocation (per FR-005) throws `RevocationException`; everything else loops.
@lazySingleton
class TokenRefreshService {
  final AuthLocalDataSource _authLocal;
  @visibleForTesting
  final Dio refreshDio;
  Completer<String>? _refreshCompleter;

  TokenRefreshService(this._authLocal)
      : refreshDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));

  @visibleForTesting
  TokenRefreshService.forTesting(this._authLocal, this.refreshDio);

  static const _initialBackoff = Duration(seconds: 2);
  static const _maxBackoff = Duration(seconds: 60);

  /// Returns the new access token. Retries transient failures with backoff
  /// until success. Throws `RevocationException` on explicit backend
  /// revocation. Concurrent callers share the same in-flight refresh.
  Future<String> refreshTokens() {
    final existing = _refreshCompleter;
    if (existing != null && !existing.isCompleted) {
      return existing.future;
    }

    final completer = Completer<String>();
    _refreshCompleter = completer;
    debugPrint('[TokenRefreshService] Starting refresh');

    unawaited(_runRefreshLoop(completer));
    return completer.future;
  }

  Future<void> _runRefreshLoop(Completer<String> completer) async {
    var delay = _initialBackoff;
    try {
      while (true) {
        try {
          final newToken = await _attemptRefresh();
          debugPrint('[TokenRefreshService] Refresh successful');
          completer.complete(newToken);
          return;
        } on RevocationException catch (e) {
          debugPrint('[TokenRefreshService] Revocation detected: logging out');
          completer.completeError(e);
          return;
        } on DioException catch (e) {
          if (_isRevocationResponse(e)) {
            debugPrint('[TokenRefreshService] Revocation detected: logging out');
            completer.completeError(const RevocationException());
            return;
          }
          debugPrint(
            '[TokenRefreshService] Transient failure, retrying in ${delay.inSeconds}s: $e',
          );
          await Future<void>.delayed(delay);
          final nextMs = delay.inMilliseconds * 2;
          delay = nextMs > _maxBackoff.inMilliseconds
              ? _maxBackoff
              : Duration(milliseconds: nextMs);
        } catch (e) {
          debugPrint(
            '[TokenRefreshService] Unexpected error, retrying in ${delay.inSeconds}s: $e',
          );
          await Future<void>.delayed(delay);
          final nextMs = delay.inMilliseconds * 2;
          delay = nextMs > _maxBackoff.inMilliseconds
              ? _maxBackoff
              : Duration(milliseconds: nextMs);
        }
      }
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<String> _attemptRefresh() async {
    final refreshToken = await _authLocal.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const RevocationException('No refresh token in secure storage');
    }

    final response = await refreshDio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final body = response.data;
    if (body is! Map) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Malformed /auth/refresh response',
      );
    }
    // Backend wraps every response as {success, message, data: {...}} via
    // GlobalResponseInterceptor — the tokens live under `data`, not at the root.
    final payload = body['data'];
    if (payload is! Map) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Malformed /auth/refresh response',
      );
    }
    final map = Map<String, dynamic>.from(payload);
    final newAccess = map['accessToken']?.toString();
    final newRefresh = map['refreshToken']?.toString() ?? refreshToken;

    if (newAccess == null || newAccess.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Missing accessToken in /auth/refresh response',
      );
    }

    await _authLocal.saveTokens(
      accessToken: newAccess,
      refreshToken: newRefresh,
    );
    return newAccess;
  }

  bool _isRevocationResponse(DioException e) {
    try {
      if (e.response?.statusCode != 401) return false;
      final body = e.response?.data;
      if (body is! Map) return false;
      final message = body['message']?.toString();
      return message == 'Refresh token revoked' ||
          message == 'Invalid or expired refresh token';
    } catch (_) {
      return false;
    }
  }
}
