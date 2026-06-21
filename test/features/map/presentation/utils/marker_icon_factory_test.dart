import 'package:ciro_chat_app/features/map/domain/entities/map_user.dart';
import 'package:ciro_chat_app/features/map/presentation/utils/marker_icon_factory.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  // `MapAvatarMarker(...).toBitmapDescriptor()` rasterizes a real widget
  // subtree off of `ui.PlatformDispatcher`, which only exists once the test
  // binding is up — these tests must run as `testWidgets`, not plain `test`.
  group('MarkerIconFactory (T059)', () {
    testWidgets('cache hit returns the exact same descriptor instance', (tester) async {
      final factory = MarkerIconFactory();
      final user = _user('u1');

      final first = await factory.resolve(user);
      final second = await factory.resolve(user);

      expect(identical(first, second), isTrue);
    });

    testWidgets('cache key varies with isOnline — distinct entries are cached independently', (tester) async {
      final factory = MarkerIconFactory();
      final online = _user('u2', isOnline: true);
      final offline = _user('u2', isOnline: false);

      final onlineIcon = await factory.resolve(online);
      final offlineIcon = await factory.resolve(offline);

      // Two independent rasterizations: distinct cache entries, distinct
      // BitmapDescriptor instances, both retrievable from cache afterwards.
      expect(identical(onlineIcon, offlineIcon), isFalse);
      expect(factory.cached(online), isNotNull);
      expect(factory.cached(offline), isNotNull);
      expect(identical(factory.cached(online), factory.cached(offline)), isFalse);
    });

    testWidgets('a failed avatar fetch falls back to the placeholder without invoking onResolved', (tester) async {
      final factory = MarkerIconFactory();
      // Malformed (schemeless) URL: flutter_cache_manager's underlying http
      // client rejects it immediately — a fast, deterministic failure that
      // doesn't depend on real network reachability.
      final user = _user('u3', avatarUrl: 'not a real url');

      var resolvedCallCount = 0;
      final placeholder = await factory.resolve(
        user,
        onResolved: (_) => resolvedCallCount++,
      );

      // Let the unawaited network-composite attempt run to completion.
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(resolvedCallCount, 0);
      expect(identical(factory.cached(user), placeholder), isTrue);
    });
  });
}
