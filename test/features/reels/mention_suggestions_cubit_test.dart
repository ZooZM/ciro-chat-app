import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/followed_user.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/mention_suggestions_cubit.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

const _sara = FollowedUser(id: 'u1', username: 'sara_films', name: 'Sara Adel');
const _sam = FollowedUser(id: 'u2', username: 'sam99', name: 'Sam Nabil');

void main() {
  late MockReelsRepository repository;

  setUp(() {
    repository = MockReelsRepository();
  });

  group('MentionSuggestionsCubit (v5, FR-083)', () {
    blocTest<MentionSuggestionsCubit, MentionSuggestionsState>(
      'ensureLoaded fetches once, transitioning loading -> hidden',
      build: () => MentionSuggestionsCubit(repository),
      setUp: () {
        when(() => repository.getFollowingUsers()).thenAnswer(
          (_) async => const Right((items: [_sara, _sam], nextCursor: null)),
        );
      },
      act: (cubit) => cubit.ensureLoaded(),
      expect: () => [
        const MentionSuggestionsState(visibility: MentionSuggestionsVisibility.loading),
        const MentionSuggestionsState(),
      ],
    );

    blocTest<MentionSuggestionsCubit, MentionSuggestionsState>(
      'a second ensureLoaded() call does not re-fetch',
      build: () => MentionSuggestionsCubit(repository),
      setUp: () {
        when(() => repository.getFollowingUsers()).thenAnswer(
          (_) async => const Right((items: [_sara], nextCursor: null)),
        );
      },
      act: (cubit) async {
        await cubit.ensureLoaded();
        await cubit.ensureLoaded();
      },
      verify: (_) {
        verify(() => repository.getFollowingUsers()).called(1);
      },
    );

    blocTest<MentionSuggestionsCubit, MentionSuggestionsState>(
      'updateToken narrows matches by username or name substring, case-insensitively',
      build: () => MentionSuggestionsCubit(repository),
      setUp: () {
        when(() => repository.getFollowingUsers()).thenAnswer(
          (_) async => const Right((items: [_sara, _sam], nextCursor: null)),
        );
      },
      act: (cubit) async {
        await cubit.ensureLoaded();
        cubit.updateToken('SA');
      },
      expect: () => [
        const MentionSuggestionsState(visibility: MentionSuggestionsVisibility.loading),
        const MentionSuggestionsState(),
        const MentionSuggestionsState(
          visibility: MentionSuggestionsVisibility.active,
          query: 'SA',
          matches: [_sara, _sam],
        ),
      ],
    );

    blocTest<MentionSuggestionsCubit, MentionSuggestionsState>(
      'updateToken(null) dismisses an active panel',
      build: () => MentionSuggestionsCubit(repository),
      setUp: () {
        when(() => repository.getFollowingUsers()).thenAnswer(
          (_) async => const Right((items: [_sara], nextCursor: null)),
        );
      },
      act: (cubit) async {
        await cubit.ensureLoaded();
        cubit.updateToken('sa');
        cubit.updateToken(null);
      },
      expect: () => [
        const MentionSuggestionsState(visibility: MentionSuggestionsVisibility.loading),
        const MentionSuggestionsState(),
        const MentionSuggestionsState(
          visibility: MentionSuggestionsVisibility.active,
          query: 'sa',
          matches: [_sara],
        ),
        const MentionSuggestionsState(),
      ],
    );

    blocTest<MentionSuggestionsCubit, MentionSuggestionsState>(
      'a failed fetch never shows the overlay — updateToken stays silent (typing never blocked)',
      build: () => MentionSuggestionsCubit(repository),
      setUp: () {
        when(() => repository.getFollowingUsers())
            .thenAnswer((_) async => Left(ServerFailure('network error')));
      },
      act: (cubit) async {
        await cubit.ensureLoaded();
        cubit.updateToken('anything');
      },
      expect: () => [
        const MentionSuggestionsState(visibility: MentionSuggestionsVisibility.loading),
        const MentionSuggestionsState(),
      ],
    );

    blocTest<MentionSuggestionsCubit, MentionSuggestionsState>(
      'an empty following list never shows the overlay',
      build: () => MentionSuggestionsCubit(repository),
      setUp: () {
        when(() => repository.getFollowingUsers()).thenAnswer(
          (_) async => const Right((items: <FollowedUser>[], nextCursor: null)),
        );
      },
      act: (cubit) async {
        await cubit.ensureLoaded();
        cubit.updateToken('anything');
      },
      expect: () => [
        const MentionSuggestionsState(visibility: MentionSuggestionsVisibility.loading),
        const MentionSuggestionsState(),
      ],
    );

    blocTest<MentionSuggestionsCubit, MentionSuggestionsState>(
      'dismiss() hides an active panel',
      build: () => MentionSuggestionsCubit(repository),
      setUp: () {
        when(() => repository.getFollowingUsers()).thenAnswer(
          (_) async => const Right((items: [_sara], nextCursor: null)),
        );
      },
      act: (cubit) async {
        await cubit.ensureLoaded();
        cubit.updateToken('sa');
        cubit.dismiss();
      },
      skip: 3,
      expect: () => [
        const MentionSuggestionsState(),
      ],
    );
  });
}
