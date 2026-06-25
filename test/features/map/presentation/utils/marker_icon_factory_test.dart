import 'dart:async';
import 'dart:io';

import 'package:ciro_chat_app/features/map/domain/entities/map_user.dart';
import 'package:ciro_chat_app/features/map/presentation/utils/marker_icon_factory.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockBaseCacheManager extends Mock implements BaseCacheManager {}

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

MapUser _user(
  String id, {
  bool isOnline = true,
  String? avatarUrl,
}) {
  return MapUser(
    id: id,
    name: 'User $id',
    avatarUrl: avatarUrl,
    isOnline: isOnline,
    latitude: 30.0,
    longitude: 31.0,
    lastUpdatedAt: DateTime(2026, 1, 1),
  );
}

/// The placeholder widget styles its name label via `google_fonts`, which
/// fires an un-awaited, fire-and-forget font-load Future the widget tree
/// never catches. In this sandboxed test environment (no network, no
/// bundled font asset) that Future always rejects, and the rejection
/// otherwise surfaces as a spurious test failure unrelated to anything
/// `MarkerIconFactory` actually does. Scope a zone error filter around the
/// real-async work to swallow only that specific, known-benign rejection.
Future<T> _runIgnoringGoogleFontsErrors<T>(Future<T> Function() body) {
  final completer = Completer<T>();
  runZonedGuarded(() async {
    try {
      completer.complete(await body());
    } catch (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    }
  }, (error, stack) {
    final isGoogleFontsNoise = error.toString().contains('google_fonts') ||
        error.toString().contains('allowRuntimeFetching') ||
        error.toString().contains('Failed to load font');
    if (isGoogleFontsNoise) return;
    if (!completer.isCompleted) completer.completeError(error, stack);
  });
  return completer.future;
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.invalid'));
    // Avoids the real network fetch (and the path_provider save it would
    // trigger afterward) for google_fonts specifically — the resulting
    // exception is still an unhandled fire-and-forget rejection, swallowed
    // below by _runIgnoringGoogleFontsErrors.
    GoogleFonts.config.allowRuntimeFetching = false;
    // `cached_network_image`'s own (separate) internal DefaultCacheManager,
    // and any real flutter_cache_manager use, need a real sqlite backend and
    // a writable directory — neither is provided by plain flutter_test.
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      switch (call.method) {
        case 'getTemporaryDirectory':
        case 'getApplicationSupportDirectory':
          return Directory.systemTemp.path;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
  });

  // `MapAvatarMarker(...).toBitmapDescriptor()` rasterizes a real widget
  // subtree (real `Future.delayed`, real `RenderRepaintBoundary.toImage()`,
  // and for the network path a real `compute()` isolate) — none of that
  // progresses under `testWidgets`'s pumped/fake-clock zone, so every call
  // into `MarkerIconFactory` must run inside `tester.runAsync()`, the
  // documented escape hatch into the real event loop. Without it the test
  // hangs indefinitely rather than failing.
  group('MarkerIconFactory (T059)', () {
    testWidgets('cache hit returns the exact same descriptor instance', (tester) async {
      final factory = MarkerIconFactory();
      final user = _user('u1');

      final identicalIcons = await tester.runAsync(() => _runIgnoringGoogleFontsErrors(() async {
            final first = await factory.resolve(user);
            final second = await factory.resolve(user);
            return identical(first, second);
          }));

      expect(identicalIcons, isTrue);
    });

    testWidgets('cache key varies with isOnline — distinct entries are cached independently', (tester) async {
      final factory = MarkerIconFactory();
      final online = _user('u2', isOnline: true);
      final offline = _user('u2', isOnline: false);

      await tester.runAsync(() => _runIgnoringGoogleFontsErrors(() async {
            await factory.resolve(online);
            await factory.resolve(offline);
          }));

      // Two independent rasterizations: distinct cache entries, distinct
      // BitmapDescriptor instances, both retrievable from cache afterwards.
      expect(factory.cached(online), isNotNull);
      expect(factory.cached(offline), isNotNull);
      expect(identical(factory.cached(online), factory.cached(offline)), isFalse);
    });

    testWidgets('a failed avatar fetch falls back to the placeholder without invoking onResolved', (tester) async {
      // Mocking BaseCacheManager directly for MarkerIconFactory's own fetch
      // keeps that specific path deterministic regardless of real network
      // reachability in CI.
      final mockCacheManager = MockBaseCacheManager();
      when(() => mockCacheManager.getSingleFile(any()))
          .thenThrow(Exception('network down'));
      final factory = MarkerIconFactory.test(cacheManager: mockCacheManager);
      final user = _user('u3', avatarUrl: 'https://example.invalid/avatar.png');

      var resolvedCallCount = 0;
      final placeholder = await tester.runAsync(() => _runIgnoringGoogleFontsErrors(() async {
            final result = await factory.resolve(
              user,
              onResolved: (_) => resolvedCallCount++,
            );
            // Let the unawaited network-composite attempt run to completion.
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return result;
          }));

      expect(resolvedCallCount, 0);
      expect(identical(factory.cached(user), placeholder), isTrue);
    });
  });
}
