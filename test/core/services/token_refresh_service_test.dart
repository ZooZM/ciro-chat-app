import 'dart:async';

import 'package:ciro_chat_app/core/error/revocation_exception.dart';
import 'package:ciro_chat_app/core/services/token_refresh_service.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthLocal extends Mock implements AuthLocalDataSource {}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount += 1;
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int status, Map<String, dynamic> body) {
  final bytes = '{"accessToken":"${body['accessToken'] ?? ''}","refreshToken":"${body['refreshToken'] ?? ''}","message":"${body['message'] ?? ''}"}';
  return ResponseBody.fromString(
    bytes,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  late _MockAuthLocal authLocal;
  late Dio dio;

  setUp(() {
    authLocal = _MockAuthLocal();
    when(() => authLocal.getRefreshToken()).thenAnswer((_) async => 'old-refresh');
    when(
      () => authLocal.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});

    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  });

  TokenRefreshService buildService() =>
      TokenRefreshService.forTesting(authLocal, dio);

  group('TokenRefreshService — happy path (T011)', () {
    test('returns new access token and persists both tokens', () async {
      final adapter = _StubAdapter((_) async => _jsonResponse(200, {
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
          }));
      dio.httpClientAdapter = adapter;

      final service = buildService();
      final token = await service.refreshTokens();

      expect(token, 'new-access');
      expect(adapter.callCount, 1);
      verify(() => authLocal.saveTokens(
            accessToken: 'new-access',
            refreshToken: 'new-refresh',
          )).called(1);
    });
  });

  group('TokenRefreshService — coalescing (T012, FR-008)', () {
    test('three concurrent callers result in exactly one backend call', () async {
      final adapter = _StubAdapter((_) async {
        // Small delay to ensure callers overlap in time.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _jsonResponse(200, {
          'accessToken': 'shared-access',
          'refreshToken': 'shared-refresh',
        });
      });
      dio.httpClientAdapter = adapter;

      final service = buildService();
      final results = await Future.wait([
        service.refreshTokens(),
        service.refreshTokens(),
        service.refreshTokens(),
      ]);

      expect(results, ['shared-access', 'shared-access', 'shared-access']);
      expect(adapter.callCount, 1);
    });
  });

  group('TokenRefreshService — revocation detection (T018, FR-005)', () {
    test('throws RevocationException on "Refresh token revoked"', () async {
      final adapter = _StubAdapter((_) async => _jsonResponse(401, {
            'message': 'Refresh token revoked',
          }));
      dio.httpClientAdapter = adapter;

      final service = buildService();

      expect(() => service.refreshTokens(), throwsA(isA<RevocationException>()));
      // Allow the future to resolve.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verifyNever(() => authLocal.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ));
      // Service does NOT delete tokens itself — that is the caller's job.
      verifyNever(() => authLocal.deleteTokens());
    });

    test('throws RevocationException on "Invalid or expired refresh token"', () async {
      final adapter = _StubAdapter((_) async => _jsonResponse(401, {
            'message': 'Invalid or expired refresh token',
          }));
      dio.httpClientAdapter = adapter;

      final service = buildService();

      expect(() => service.refreshTokens(), throwsA(isA<RevocationException>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });

  group('TokenRefreshService — transient retry (T019, FR-004)', () {
    test('retries connectionError twice then succeeds; backoff is positive', () {
      fakeAsync((async) {
        var attempt = 0;
        final adapter = _StubAdapter((opts) async {
          attempt += 1;
          if (attempt <= 2) {
            throw DioException(
              requestOptions: opts,
              type: DioExceptionType.connectionError,
              error: 'simulated network failure',
            );
          }
          return _jsonResponse(200, {
            'accessToken': 'after-retry',
            'refreshToken': 'after-retry-r',
          });
        });
        dio.httpClientAdapter = adapter;

        final service = buildService();
        String? token;
        Object? error;
        service.refreshTokens().then((t) => token = t).catchError((e) {
          error = e;
          return '';
        });

        // Advance enough virtual time to cover 2s + 4s + processing overhead.
        // Loop a few times to ensure microtasks between Dio awaits drain.
        for (var i = 0; i < 20; i++) {
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
        }

        expect(attempt, 3, reason: 'must have made 3 backend attempts');
        expect(token, 'after-retry');
        expect(error, isNull);
      });
    });
  });

  group('TokenRefreshService — 5xx is retried (T020, FR-004)', () {
    test('503 is retried then succeeds', () {
      fakeAsync((async) {
        var attempt = 0;
        final adapter = _StubAdapter((opts) async {
          attempt += 1;
          if (attempt == 1) {
            return _jsonResponse(503, {'message': 'Service Unavailable'});
          }
          return _jsonResponse(200, {
            'accessToken': 'recovered',
            'refreshToken': 'recovered-r',
          });
        });
        dio.httpClientAdapter = adapter;

        final service = buildService();
        String? token;
        Object? error;
        service.refreshTokens().then((t) => token = t).catchError((e) {
          error = e;
          return '';
        });

        for (var i = 0; i < 10; i++) {
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
        }

        expect(attempt, 2);
        expect(token, 'recovered');
        expect(error, isNull);
      });
    });
  });

  group('TokenRefreshService — non-terminal 401 is retried (T021, FR-005)', () {
    test('401 with unknown message is treated as transient (no Revocation)', () {
      fakeAsync((async) {
        var attempt = 0;
        final adapter = _StubAdapter((opts) async {
          attempt += 1;
          if (attempt == 1) {
            return _jsonResponse(401, {'message': 'Some other auth error'});
          }
          return _jsonResponse(200, {
            'accessToken': 'survived',
            'refreshToken': 'survived-r',
          });
        });
        dio.httpClientAdapter = adapter;

        final service = buildService();
        String? token;
        Object? error;
        service.refreshTokens().then((t) => token = t).catchError((e) {
          error = e;
          return '';
        });

        for (var i = 0; i < 10; i++) {
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
        }

        expect(attempt, 2);
        expect(token, 'survived');
        expect(error, isNull, reason: 'unknown 401 message must NOT throw RevocationException');
      });
    });
  });
}
