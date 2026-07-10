import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/followed_user.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_reposter.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/repost_badge.dart';

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

class MockReelsRepository extends Mock implements ReelsRepository {}

void main() {
  late MockAuthLocalDataSource mockAuthLocalDataSource;
  late MockReelsRepository mockRepository;
  late ReelsInteractionCubit interactionCubit;

  setUp(() {
    mockAuthLocalDataSource = MockAuthLocalDataSource();
    mockRepository = MockReelsRepository();
    interactionCubit = ReelsInteractionCubit(mockRepository);
    getIt.registerSingleton<AuthLocalDataSource>(mockAuthLocalDataSource);
    getIt.registerSingleton<ReelsInteractionCubit>(interactionCubit);
    getIt.registerSingleton<ReelsRepository>(mockRepository);
  });

  tearDown(() {
    getIt.unregister<AuthLocalDataSource>();
    getIt.unregister<ReelsInteractionCubit>();
    getIt.unregister<ReelsRepository>();
  });

  group('RepostBadge (FR-076/FR-077, v4; v6 optimistic)', () {
    testWidgets('renders nothing when there is no attribution and no optimistic repost',
        (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RepostBadge(reelId: 'r-1', repostedBy: null))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('renders "[name] reposted" for another reposter', (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepostBadge(
              reelId: 'r-1',
              repostedBy: ReelReposter(
                id: 'friend-1',
                username: 'friend',
                name: 'Friend Name',
                avatarUrl: '',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('reels.reposted_by'), findsOneWidget);
      expect(find.text('reels.you_reposted'), findsNothing);
    });

    testWidgets('renders "You reposted" when the attributed reposter is the current viewer',
        (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepostBadge(
              reelId: 'r-1',
              repostedBy: ReelReposter(
                id: 'viewer-1',
                username: 'me',
                name: 'Me',
                avatarUrl: '',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('reels.you_reposted'), findsOneWidget);
      expect(find.text('reels.reposted_by'), findsNothing);
    });

    // v6: reposting on the feed shows "You reposted" immediately, without a
    // fetched attribution — driven by the interaction cubit's optimistic map.
    testWidgets('shows "You reposted" immediately from an optimistic repost (no attribution)',
        (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');
      when(() => mockRepository.repostReel('r-1')).thenAnswer((_) async => const Right(unit));
      // Drives the optimistic reposts['r-1'] = true via the real toggle path.
      await interactionCubit.toggleRepost('r-1');

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RepostBadge(reelId: 'r-1', repostedBy: null))),
      );
      await tester.pumpAndSettle();

      expect(find.text('reels.you_reposted'), findsOneWidget);
    });

    // v6: >1 relevant reposters → "N reposted" with a stacked avatar cluster.
    testWidgets('renders "N reposted" with an avatar stack when repostersCount > 1',
        (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepostBadge(
              reelId: 'r-1',
              repostedBy: ReelReposter(
                id: 'friend-1',
                username: 'a',
                name: 'A',
                avatarUrl: '',
              ),
              repostersCount: 2,
              topReposters: [
                ReelReposter(id: 'friend-1', username: 'a', name: 'A', avatarUrl: ''),
                ReelReposter(id: 'friend-2', username: 'b', name: 'B', avatarUrl: ''),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('reels.reposted_count'), findsOneWidget);
      expect(find.text('reels.reposted_by'), findsNothing);
      // Two stacked avatars.
      expect(find.byType(CircleAvatar), findsNWidgets(2));
    });

    // v6: a MULTI-reposter badge opens the reposters bottom sheet on tap.
    testWidgets('tapping a multi-reposter badge opens the reposters sheet', (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');
      when(() => mockRepository.fetchReposters('r-1', cursor: any(named: 'cursor')))
          .thenAnswer((_) async => const Right((items: <FollowedUser>[], nextCursor: null)));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepostBadge(
              reelId: 'r-1',
              repostedBy: ReelReposter(id: 'a', username: 'a', name: 'A', avatarUrl: ''),
              repostersCount: 2,
              topReposters: [
                ReelReposter(id: 'a', username: 'a', name: 'A', avatarUrl: ''),
                ReelReposter(id: 'b', username: 'b', name: 'B', avatarUrl: ''),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('reels.reposted_count'));
      await tester.pumpAndSettle();

      expect(find.text('reels.reposters_sheet_title'), findsOneWidget);
      verify(() => mockRepository.fetchReposters('r-1', cursor: any(named: 'cursor'))).called(1);
    });

    // v6: a SINGLE-reposter badge is not tappable — no sheet.
    testWidgets('a single-reposter badge does not open the sheet on tap', (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepostBadge(
              reelId: 'r-1',
              repostedBy: ReelReposter(
                id: 'friend-1',
                username: 'friend',
                name: 'Friend',
                avatarUrl: '',
              ),
              repostersCount: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('reels.reposted_by'));
      await tester.pumpAndSettle();

      expect(find.text('reels.reposters_sheet_title'), findsNothing);
      verifyNever(() => mockRepository.fetchReposters(any(), cursor: any(named: 'cursor')));
    });

    // v6: reposting a reel that already had 1 relevant reposter bumps the
    // count to "2 reposted" immediately (optimistic), no re-fetch needed.
    testWidgets('an optimistic repost bumps a single reposter to "2 reposted" instantly',
        (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');
      when(() => mockRepository.repostReel('r-1')).thenAnswer((_) async => const Right(unit));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepostBadge(
              reelId: 'r-1',
              repostedBy: ReelReposter(id: 'omar', username: 'omar', name: 'Omar', avatarUrl: ''),
              repostersCount: 1,
              topReposters: [
                ReelReposter(id: 'omar', username: 'omar', name: 'Omar', avatarUrl: ''),
              ],
              viewerReposted: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('reels.reposted_by'), findsOneWidget); // "Omar reposted"

      await interactionCubit.toggleRepost('r-1'); // viewer now reposts too
      await tester.pumpAndSettle();

      expect(find.text('reels.reposted_count'), findsOneWidget); // "2 reposted"
      expect(find.text('reels.reposted_by'), findsNothing);
    });
  });
}
