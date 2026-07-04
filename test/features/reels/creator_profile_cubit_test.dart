import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/creator_profile.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_creator.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/creator_profile_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

const _profile = CreatorProfile(
  id: 'creator-1',
  name: 'Creator',
  avatarUrl: '',
  bio: 'bio',
  followersCount: 5,
  followingCount: 2,
  totalLikes: 100,
  videos: [],
  viewerFollowing: false,
  isSelf: false,
);

void main() {
  late MockReelsRepository repository;
  late ReelsInteractionCubit interactionCubit;

  setUp(() {
    repository = MockReelsRepository();
    interactionCubit = ReelsInteractionCubit(repository);
  });

  blocTest<CreatorProfileCubit, CreatorProfileState>(
    'load() emits loading then ready with the fetched profile, and seeds the follow entry (FR-030)',
    setUp: () {
      when(() => repository.fetchProfile('creator-1'))
          .thenAnswer((_) async => const Right(_profile));
    },
    build: () => CreatorProfileCubit(repository, interactionCubit),
    act: (cubit) => cubit.load('creator-1'),
    expect: () => [
      isA<CreatorProfileState>().having((s) => s.status, 'status', CreatorProfileStatus.loading),
      isA<CreatorProfileState>()
          .having((s) => s.status, 'status', CreatorProfileStatus.ready)
          .having((s) => s.profile, 'profile', _profile),
    ],
    verify: (_) {
      expect(
        interactionCubit.state.follows['creator-1'],
        const FollowEntry(following: false, followersCount: 5),
      );
    },
  );

  blocTest<CreatorProfileCubit, CreatorProfileState>(
    'load() corrects a stale followersCount placeholder left by seedReels '
    '(regression: the feed seeds followersCount:0 as a placeholder since Reel '
    'DTOs carry no follower count; the profile fetch must always win)',
    setUp: () {
      // Simulates having browsed the feed first: seedReels plants a follow
      // entry with a hardcoded followersCount:0 placeholder for this creator.
      interactionCubit.seedReels([
        Reel(
          id: 'reel-1',
          videoUrl: '',
          thumbnailUrl: '',
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
        ),
      ]);
      when(() => repository.fetchProfile('creator-1'))
          .thenAnswer((_) async => const Right(_profile));
    },
    build: () => CreatorProfileCubit(repository, interactionCubit),
    act: (cubit) => cubit.load('creator-1'),
    verify: (_) {
      // Must reflect the real backend value (5), not the stale 0 placeholder.
      expect(
        interactionCubit.state.follows['creator-1'],
        const FollowEntry(following: false, followersCount: 5),
      );
    },
  );

  blocTest<CreatorProfileCubit, CreatorProfileState>(
    'load() emits an error state on repository failure',
    setUp: () {
      when(() => repository.fetchProfile('creator-1'))
          .thenAnswer((_) async => Left(ServerFailure('offline')));
    },
    build: () => CreatorProfileCubit(repository, interactionCubit),
    act: (cubit) => cubit.load('creator-1'),
    expect: () => [
      isA<CreatorProfileState>().having((s) => s.status, 'status', CreatorProfileStatus.loading),
      isA<CreatorProfileState>().having((s) => s.status, 'status', CreatorProfileStatus.error),
    ],
  );
}
