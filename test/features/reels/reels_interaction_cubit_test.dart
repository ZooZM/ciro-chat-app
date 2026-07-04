import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_creator.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

Reel _reel(String id, {String creatorId = 'creator-1'}) => Reel(
      id: id,
      videoUrl: 'https://example.com/$id.mp4',
      thumbnailUrl: 'https://example.com/$id.jpg',
      createdAt: DateTime(2026, 1, 1),
      creator: ReelCreator(
        id: creatorId,
        name: 'Creator',
        avatarUrl: '',
        viewerFollowing: false,
      ),
      likesCount: 10,
      commentsCount: 2,
      sharesCount: 1,
      viewerLiked: false,
    );

void main() {
  late MockReelsRepository repository;

  setUp(() {
    repository = MockReelsRepository();
  });

  group('seedReels', () {
    blocTest<ReelsInteractionCubit, ReelsInteractionState>(
      'populates likes/comments/shares/follows from the reel payload without overwriting existing entries',
      build: () => ReelsInteractionCubit(repository),
      act: (cubit) {
        cubit.seedReels([_reel('a')]);
        // Re-seeding the same id must not clobber a local optimistic change.
        cubit.seedReels([_reel('a')]);
      },
      verify: (cubit) {
        expect(cubit.state.likes['a'], const LikeEntry(liked: false, count: 10));
        expect(cubit.state.commentCounts['a'], 2);
        expect(cubit.state.shareCounts['a'], 1);
        expect(cubit.state.follows['creator-1']?.following, false);
      },
    );
  });

  group('toggleLike (FR-018, id-keyed isolation)', () {
    blocTest<ReelsInteractionCubit, ReelsInteractionState>(
      'optimistically flips liked/count then reconciles with the server response '
      '(a concurrent like landed server-side, so the confirmed count differs from the guess)',
      setUp: () {
        when(() => repository.toggleLike('a'))
            .thenAnswer((_) async => const Right((liked: true, likesCount: 12)));
      },
      build: () => ReelsInteractionCubit(repository),
      seed: () => const ReelsInteractionState(
        likes: {'a': LikeEntry(liked: false, count: 10), 'b': LikeEntry(liked: true, count: 5)},
      ),
      act: (cubit) => cubit.toggleLike('a'),
      expect: () => [
        isA<ReelsInteractionState>().having(
          (s) => s.likes['a'],
          "likes['a'] optimistic",
          const LikeEntry(liked: true, count: 11),
        ),
        isA<ReelsInteractionState>().having(
          (s) => s.likes['a'],
          "likes['a'] confirmed",
          const LikeEntry(liked: true, count: 12),
        ),
      ],
      verify: (cubit) {
        // Untouched reel's like entry never rebuilds/changes.
        expect(cubit.state.likes['b'], const LikeEntry(liked: true, count: 5));
      },
    );

    blocTest<ReelsInteractionCubit, ReelsInteractionState>(
      'reverts the optimistic change and flags lastActionFailed on repository failure (FR-037)',
      setUp: () {
        when(() => repository.toggleLike('a'))
            .thenAnswer((_) async => Left(ServerFailure('offline')));
      },
      build: () => ReelsInteractionCubit(repository),
      seed: () => const ReelsInteractionState(
        likes: {'a': LikeEntry(liked: false, count: 10)},
      ),
      act: (cubit) => cubit.toggleLike('a'),
      expect: () => [
        isA<ReelsInteractionState>()
            .having((s) => s.likes['a'], 'optimistic', const LikeEntry(liked: true, count: 11)),
        isA<ReelsInteractionState>()
            .having((s) => s.likes['a'], 'reverted', const LikeEntry(liked: false, count: 10)),
        isA<ReelsInteractionState>().having((s) => s.lastActionFailed, 'lastActionFailed', true),
      ],
    );
  });

  group('toggleFollow (FR-029/030, keyed by creatorId)', () {
    blocTest<ReelsInteractionCubit, ReelsInteractionState>(
      'optimistically flips following/followersCount then reconciles with the server response',
      setUp: () {
        when(() => repository.toggleFollow('creator-1'))
            .thenAnswer((_) async => const Right((following: true, followersCount: 7)));
      },
      build: () => ReelsInteractionCubit(repository),
      seed: () => const ReelsInteractionState(
        follows: {'creator-1': FollowEntry(following: false, followersCount: 5)},
      ),
      act: (cubit) => cubit.toggleFollow('creator-1'),
      expect: () => [
        isA<ReelsInteractionState>().having(
          (s) => s.follows['creator-1'],
          'optimistic',
          const FollowEntry(following: true, followersCount: 6),
        ),
        isA<ReelsInteractionState>().having(
          (s) => s.follows['creator-1'],
          'confirmed',
          const FollowEntry(following: true, followersCount: 7),
        ),
      ],
    );

    blocTest<ReelsInteractionCubit, ReelsInteractionState>(
      'reverts on failure so the overlay and profile screen stay consistent, and flags lastActionFailed',
      setUp: () {
        when(() => repository.toggleFollow('creator-1'))
            .thenAnswer((_) async => Left(ServerFailure('offline')));
      },
      build: () => ReelsInteractionCubit(repository),
      seed: () => const ReelsInteractionState(
        follows: {'creator-1': FollowEntry(following: false, followersCount: 5)},
      ),
      act: (cubit) => cubit.toggleFollow('creator-1'),
      expect: () => [
        isA<ReelsInteractionState>().having(
          (s) => s.follows['creator-1'],
          'optimistic',
          const FollowEntry(following: true, followersCount: 6),
        ),
        isA<ReelsInteractionState>().having(
          (s) => s.follows['creator-1'],
          'reverted',
          const FollowEntry(following: false, followersCount: 5),
        ),
        isA<ReelsInteractionState>().having((s) => s.lastActionFailed, 'lastActionFailed', true),
      ],
    );
  });

  group('recordShare', () {
    blocTest<ReelsInteractionCubit, ReelsInteractionState>(
      'updates the share count from the backend response',
      setUp: () {
        when(() => repository.recordShare('a')).thenAnswer((_) async => const Right(4));
      },
      build: () => ReelsInteractionCubit(repository),
      act: (cubit) => cubit.recordShare('a'),
      expect: () => [
        isA<ReelsInteractionState>().having((s) => s.shareCounts['a'], "shareCounts['a']", 4),
      ],
    );
  });

  group('toggleSave (FR-049, private toggle)', () {
    blocTest<ReelsInteractionCubit, ReelsInteractionState>(
      'optimistically flips saved then reconciles with the server response '
      '(another device already re-saved it, so the confirmed value differs from the optimistic guess)',
      setUp: () {
        when(() => repository.toggleSave('a')).thenAnswer((_) async => const Right(true));
      },
      build: () => ReelsInteractionCubit(repository),
      seed: () => const ReelsInteractionState(saves: {'a': true}),
      act: (cubit) => cubit.toggleSave('a'),
      expect: () => [
        isA<ReelsInteractionState>().having((s) => s.saves['a'], "saves['a'] optimistic", false),
        isA<ReelsInteractionState>().having((s) => s.saves['a'], "saves['a'] confirmed", true),
      ],
    );

    blocTest<ReelsInteractionCubit, ReelsInteractionState>(
      'reverts the optimistic change and flags lastActionFailed on repository failure (FR-037)',
      setUp: () {
        when(() => repository.toggleSave('a')).thenAnswer((_) async => Left(ServerFailure('offline')));
      },
      build: () => ReelsInteractionCubit(repository),
      seed: () => const ReelsInteractionState(saves: {'a': false}),
      act: (cubit) => cubit.toggleSave('a'),
      expect: () => [
        isA<ReelsInteractionState>().having((s) => s.saves['a'], 'optimistic', true),
        isA<ReelsInteractionState>().having((s) => s.saves['a'], 'reverted', false),
        isA<ReelsInteractionState>().having((s) => s.lastActionFailed, 'lastActionFailed', true),
      ],
    );
  });

  group('recordView (FR-048, deduped per reel per session)', () {
    test('fires exactly once per reel id even when called repeatedly', () {
      when(() => repository.recordView('a')).thenAnswer((_) async => const Right(1));
      final cubit = ReelsInteractionCubit(repository);

      cubit.recordView('a');
      cubit.recordView('a');
      cubit.recordView('a');

      verify(() => repository.recordView('a')).called(1);
      cubit.close();
    });

    test('reset() clears the per-session dedup guard so a fresh session re-fires', () {
      when(() => repository.recordView('a')).thenAnswer((_) async => const Right(1));
      final cubit = ReelsInteractionCubit(repository);

      cubit.recordView('a');
      cubit.reset();
      cubit.recordView('a');

      verify(() => repository.recordView('a')).called(2);
      cubit.close();
    });
  });
}
