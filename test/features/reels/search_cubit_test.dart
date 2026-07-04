import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_creator.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reels_page.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/search_user.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/search_cubit.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

Reel _reel(String id) => Reel(
      id: id,
      videoUrl: 'https://example.com/$id.mp4',
      thumbnailUrl: 'https://example.com/$id.jpg',
      createdAt: DateTime(2026, 1, 1),
      creator: const ReelCreator(id: 'c1', name: 'C', avatarUrl: '', viewerFollowing: false),
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      viewerLiked: false,
    );

const _user = SearchUser(
  id: 'u1',
  username: 'lina.k',
  name: 'Lina K',
  avatarUrl: '',
  viewerFollowing: false,
);

void main() {
  late MockReelsRepository repository;

  setUp(() {
    repository = MockReelsRepository();
  });

  group('search (FR-057, debounced 350ms)', () {
    blocTest<SearchCubit, SearchState>(
      'a whitespace-only query is a no-op — resets to idle without hitting the repository',
      build: () => SearchCubit(repository),
      act: (cubit) => cubit.search('   '),
      expect: () => [const SearchState()],
      verify: (_) {
        verifyNever(() => repository.searchReels(any()));
        verifyNever(() => repository.searchUsers(any()));
      },
    );

    blocTest<SearchCubit, SearchState>(
      'after the debounce window, fetches both videos and users in parallel',
      setUp: () {
        when(() => repository.searchReels('trav')).thenAnswer(
          (_) async => Right(ReelsPage(items: [_reel('r1')], nextCursor: null)),
        );
        when(() => repository.searchUsers('trav')).thenAnswer(
          (_) async => const Right((items: [_user], nextCursor: null)),
        );
      },
      build: () => SearchCubit(repository),
      act: (cubit) => cubit.search('trav'),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        isA<SearchState>().having((s) => s.status, 'status', SearchStatus.loading),
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.ready)
            .having((s) => s.videos.map((r) => r.id), 'videos', ['r1'])
            .having((s) => s.users, 'users', [_user]),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'a rapid second query supersedes the first — the stale response is dropped',
      setUp: () {
        when(() => repository.searchReels('a')).thenAnswer(
          (_) async =>
              Right(ReelsPage(items: [_reel('stale')], nextCursor: null)),
        );
        when(() => repository.searchUsers('a'))
            .thenAnswer((_) async => const Right((items: [], nextCursor: null)));
        when(() => repository.searchReels('ab')).thenAnswer(
          (_) async =>
              Right(ReelsPage(items: [_reel('fresh')], nextCursor: null)),
        );
        when(() => repository.searchUsers('ab'))
            .thenAnswer((_) async => const Right((items: [], nextCursor: null)));
      },
      build: () => SearchCubit(repository),
      act: (cubit) async {
        cubit.search('a');
        await Future<void>.delayed(const Duration(milliseconds: 360));
        cubit.search('ab');
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      verify: (cubit) {
        expect(cubit.state.videos.map((r) => r.id), ['fresh']);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'both searches failing surfaces an error state',
      setUp: () {
        when(() => repository.searchReels('x'))
            .thenAnswer((_) async => Left(ServerFailure('offline')));
        when(() => repository.searchUsers('x'))
            .thenAnswer((_) async => Left(ServerFailure('offline')));
      },
      build: () => SearchCubit(repository),
      act: (cubit) => cubit.search('x'),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        isA<SearchState>().having((s) => s.status, 'status', SearchStatus.loading),
        isA<SearchState>().having((s) => s.status, 'status', SearchStatus.error),
      ],
    );
  });
}
