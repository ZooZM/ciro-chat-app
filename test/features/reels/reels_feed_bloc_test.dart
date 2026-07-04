import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/reels/data/datasources/reels_prefetch_service.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_creator.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reels_page.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_feed_bloc.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/services/reels_player_pool.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

class MockReelsPlayerPool extends Mock implements ReelsPlayerPool {}

class MockReelsPrefetchService extends Mock implements ReelsPrefetchService {}

Reel _reel(String id) => Reel(
      id: id,
      videoUrl: 'https://example.com/$id.mp4',
      thumbnailUrl: 'https://example.com/$id.jpg',
      createdAt: DateTime(2026, 1, 1),
      creator: const ReelCreator(
        id: 'creator-1',
        name: 'Creator',
        avatarUrl: '',
        viewerFollowing: false,
      ),
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      viewerLiked: false,
    );

/// A list long enough that `ReelsPageChanged` never auto-triggers the
/// next-page fetch on its own (keeps FR-007 auto-pagination isolated to the
/// tests that specifically exercise it).
List<Reel> _longList(int count) => List.generate(count, (i) => _reel('r$i'));

void main() {
  late MockReelsRepository repository;
  late MockReelsPlayerPool playerPool;
  late MockReelsPrefetchService prefetchService;
  late ReelsInteractionCubit interactionCubit;

  setUp(() {
    repository = MockReelsRepository();
    playerPool = MockReelsPlayerPool();
    prefetchService = MockReelsPrefetchService();
    interactionCubit = ReelsInteractionCubit(repository);
    when(() => playerPool.syncWindow(any(), any())).thenReturn(null);
    when(() => playerPool.pauseAll()).thenReturn(null);
    when(() => playerPool.disposeAll()).thenReturn(null);
    when(() => playerPool.evict(any())).thenReturn(null);
    when(() => prefetchService.prefetch(any())).thenAnswer((_) async {});
    // Broad fallback so any cursor not explicitly stubbed by a test just
    // returns an exhausted page instead of throwing MissingStubError.
    when(
      () => repository.fetchFeed(
        cursor: any(named: 'cursor'),
        creatorId: any(named: 'creatorId'),
      ),
    ).thenAnswer((_) async => const Right(ReelsPage(items: [], nextCursor: null)));
    // FR-048: fired on every page-changed/started event — stubbed broadly so
    // tests unrelated to view recording don't need to know about it.
    when(() => repository.recordView(any())).thenAnswer((_) async => const Right(0));
  });

  ReelsFeedBloc build() =>
      ReelsFeedBloc(repository, playerPool, prefetchService, interactionCubit);

  blocTest<ReelsFeedBloc, ReelsFeedState>(
    'ReelsFeedStarted loads the first page and syncs the player window at index 0',
    setUp: () {
      when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
        (_) async => Right(ReelsPage(items: _longList(5), nextCursor: '5')),
      );
    },
    build: build,
    act: (bloc) => bloc.add(const ReelsFeedStarted()),
    expect: () => [
      isA<ReelsFeedState>().having((s) => s.status, 'status', ReelsFeedStatus.loading),
      isA<ReelsFeedState>()
          .having((s) => s.status, 'status', ReelsFeedStatus.ready)
          .having((s) => s.reels.length, 'reels.length', 5)
          .having((s) => s.currentIndex, 'currentIndex', 0),
    ],
    verify: (_) {
      verify(() => playerPool.syncWindow(0, any())).called(1);
      verify(() => prefetchService.prefetch(any())).called(1);
    },
  );

  blocTest<ReelsFeedBloc, ReelsFeedState>(
    'ReelsFeedStarted emits an error state with the failure message on repository failure',
    setUp: () {
      when(() => repository.fetchFeed(cursor: null, creatorId: null))
          .thenAnswer((_) async => Left(ServerFailure('offline')));
    },
    build: build,
    act: (bloc) => bloc.add(const ReelsFeedStarted()),
    expect: () => [
      isA<ReelsFeedState>().having((s) => s.status, 'status', ReelsFeedStatus.loading),
      isA<ReelsFeedState>()
          .having((s) => s.status, 'status', ReelsFeedStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', 'offline'),
    ],
  );

  blocTest<ReelsFeedBloc, ReelsFeedState>(
    'ReelsPageChanged updates currentIndex and re-syncs the player window',
    setUp: () {
      when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
        (_) async => Right(ReelsPage(items: _longList(10), nextCursor: '10')),
      );
    },
    build: build,
    act: (bloc) async {
      bloc.add(const ReelsFeedStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ReelsPageChanged(1));
    },
    skip: 2,
    expect: () => [
      isA<ReelsFeedState>().having((s) => s.currentIndex, 'currentIndex', 1),
    ],
    verify: (_) {
      verify(() => playerPool.syncWindow(1, any())).called(1);
    },
  );

  blocTest<ReelsFeedBloc, ReelsFeedState>(
    'ReelsFeedPaused pauses the pool without changing currentIndex; '
    'ReelsFeedResumed re-syncs at the preserved index',
    setUp: () {
      when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
        (_) async => Right(ReelsPage(items: _longList(10), nextCursor: '10')),
      );
    },
    build: build,
    act: (bloc) async {
      bloc.add(const ReelsFeedStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ReelsPageChanged(1));
      bloc.add(const ReelsFeedPaused());
      bloc.add(const ReelsFeedResumed());
    },
    verify: (bloc) {
      expect(bloc.state.currentIndex, 1);
      verify(() => playerPool.pauseAll()).called(1);
      // Once for the initial load (index 0), once for the explicit page
      // change (index 1), once more on resume (index 1 again).
      verify(() => playerPool.syncWindow(0, any())).called(1);
      verify(() => playerPool.syncWindow(1, any())).called(2);
    },
  );

  group('US2 — infinite pagination', () {
    blocTest<ReelsFeedBloc, ReelsFeedState>(
      'ReelsPageChanged near the end auto-triggers ReelsNextPageRequested and appends the page (FR-007)',
      setUp: () {
        when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(5), nextCursor: '5')),
        );
        when(() => repository.fetchFeed(cursor: '5', creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(5), nextCursor: '10')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ReelsFeedStarted());
        await Future<void>.delayed(Duration.zero);
        // Index 3 of 5 items → only 1 unseen ahead, below the threshold (3).
        bloc.add(const ReelsPageChanged(3));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.reels.length, 10);
        expect(bloc.state.nextCursor, '10');
        verify(() => repository.fetchFeed(cursor: '5', creatorId: null)).called(1);
      },
    );

    blocTest<ReelsFeedBloc, ReelsFeedState>(
      'the main feed loop never dead-ends: nextCursor is never null across repeated pagination (FR-007)',
      setUp: () {
        when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(2), nextCursor: '2')),
        );
        when(() => repository.fetchFeed(cursor: '2', creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(2), nextCursor: '4')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ReelsFeedStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ReelsNextPageRequested());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.nextCursor, isNotNull);
      },
    );

    blocTest<ReelsFeedBloc, ReelsFeedState>(
      'droppable(): a second ReelsNextPageRequested while one is in flight is dropped, not queued',
      setUp: () {
        when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(5), nextCursor: '5')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ReelsFeedStarted());
        await Future<void>.delayed(Duration.zero);
        // Both fire before the first fetchFeed('5') resolves.
        bloc.add(const ReelsNextPageRequested());
        bloc.add(const ReelsNextPageRequested());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        verify(() => repository.fetchFeed(cursor: '5', creatorId: null)).called(1);
      },
    );
  });

  group('US2 — per-item failure (FR-035)', () {
    blocTest<ReelsFeedBloc, ReelsFeedState>(
      'ReelsItemOpenFailed marks that reel id as failed without touching others',
      setUp: () {
        when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(5), nextCursor: '5')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ReelsFeedStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ReelsItemOpenFailed(2));
      },
      skip: 2,
      expect: () => [
        isA<ReelsFeedState>().having(
          (s) => s.failedItemIds,
          'failedItemIds',
          {'r2'},
        ),
      ],
    );

    blocTest<ReelsFeedBloc, ReelsFeedState>(
      'ReelsItemRetryRequested clears the failure and evicts+resyncs that index',
      setUp: () {
        when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(5), nextCursor: '5')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ReelsFeedStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ReelsItemOpenFailed(2));
        bloc.add(const ReelsItemRetryRequested(2));
      },
      verify: (bloc) {
        expect(bloc.state.failedItemIds, isEmpty);
        verify(() => playerPool.evict(2)).called(1);
      },
    );
  });

  group('US6 — deep-link seeding', () {
    blocTest<ReelsFeedBloc, ReelsFeedState>(
      'ReelsFeedStarted(initialReelId) fetches that reel first, leads the feed with it, and dedupes it out of the regular page',
      setUp: () {
        when(() => repository.fetchReel('r0'))
            .thenAnswer((_) async => Right(_reel('r0')));
        when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(3), nextCursor: '3')),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const ReelsFeedStarted(initialReelId: 'r0')),
      expect: () => [
        isA<ReelsFeedState>()
            .having((s) => s.status, 'status', ReelsFeedStatus.loadingDeepLink)
            .having((s) => s.initialReelId, 'initialReelId', 'r0'),
        isA<ReelsFeedState>().having((s) => s.status, 'status', ReelsFeedStatus.loading),
        isA<ReelsFeedState>()
            .having((s) => s.status, 'status', ReelsFeedStatus.ready)
            .having((s) => s.reels.map((r) => r.id).toList(), 'reel order', ['r0', 'r1', 'r2'])
            .having((s) => s.deepLinkFailed, 'deepLinkFailed', false),
      ],
      verify: (_) {
        verify(() => playerPool.syncWindow(0, any())).called(1);
      },
    );

    blocTest<ReelsFeedBloc, ReelsFeedState>(
      'an unknown/deleted linked reel sets deepLinkFailed and falls back to the regular feed (FR-043)',
      setUp: () {
        when(() => repository.fetchReel('missing'))
            .thenAnswer((_) async => Left(ServerFailure('Reel not found')));
        when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(3), nextCursor: '3')),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const ReelsFeedStarted(initialReelId: 'missing')),
      verify: (bloc) {
        expect(bloc.state.status, ReelsFeedStatus.ready);
        expect(bloc.state.deepLinkFailed, true);
        expect(bloc.state.reels.map((r) => r.id).toList(), ['r0', 'r1', 'r2']);
      },
    );

    blocTest<ReelsFeedBloc, ReelsFeedState>(
      'returning to the main tab after a creator-scoped/deep-linked view clears the stale scope and reloads (scope-mismatch guard)',
      setUp: () {
        when(() => repository.fetchFeed(cursor: null, creatorId: 'creator-x')).thenAnswer(
          (_) async => Right(ReelsPage(items: [_reel('cx-1')], nextCursor: null)),
        );
        when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(3), nextCursor: '3')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ReelsFeedStarted(creatorId: 'creator-x'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.creatorId, 'creator-x');
        // Simulates the main tab screen re-mounting after a scope change —
        // ReelsFeedScreen would dispatch a fresh Started, not Resumed, here.
        bloc.add(const ReelsFeedStarted());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.creatorId, isNull);
        expect(bloc.state.reels.map((r) => r.id).toList(), ['r0', 'r1', 'r2']);
      },
    );
  });

  group('Polish — logout teardown (constitution V-A)', () {
    blocTest<ReelsFeedBloc, ReelsFeedState>(
      'resetForLogout() disposes the player pool and returns to a pristine initial state',
      setUp: () {
        when(() => repository.fetchFeed(cursor: null, creatorId: null)).thenAnswer(
          (_) async => Right(ReelsPage(items: _longList(5), nextCursor: '5')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ReelsFeedStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ReelsPageChanged(2));
        bloc.resetForLogout();
      },
      verify: (bloc) {
        expect(bloc.state, const ReelsFeedState());
        verify(() => playerPool.disposeAll()).called(greaterThanOrEqualTo(1));
      },
    );
  });
}
