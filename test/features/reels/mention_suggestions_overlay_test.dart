import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/followed_user.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/mention_suggestions_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/mention_suggestions_overlay.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

const _sara = FollowedUser(id: 'u1', username: 'sara_films', name: 'Sara Adel');
const _sam = FollowedUser(id: 'u2', username: 'sam99', name: 'Sam Nabil');

void main() {
  late MockReelsRepository repository;
  late TextEditingController controller;

  setUp(() {
    repository = MockReelsRepository();
    controller = TextEditingController();
    when(() => repository.getFollowingUsers()).thenAnswer(
      (_) async => const Right((items: [_sara, _sam], nextCursor: null)),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  Future<void> pumpOverlay(WidgetTester tester) async {
    final cubit = MentionSuggestionsCubit(repository);
    await cubit.ensureLoaded();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<MentionSuggestionsCubit>.value(
          value: cubit,
          child: Scaffold(
            body: MentionSuggestionsOverlay(
              controller: controller,
              child: TextField(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MentionSuggestionsOverlay (v5, FR-083)', () {
    testWidgets('no panel is shown until an @ token is typed', (tester) async {
      await pumpOverlay(tester);
      expect(find.text('Sara Adel'), findsNothing);
    });

    testWidgets('typing @sa shows and narrows matches by username/name substring', (tester) async {
      await pumpOverlay(tester);

      await tester.enterText(find.byType(TextField), 'hi @sa');
      await tester.pumpAndSettle();

      expect(find.text('Sara Adel'), findsOneWidget);
      expect(find.text('Sam Nabil'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hi @sam');
      await tester.pumpAndSettle();

      expect(find.text('Sara Adel'), findsNothing);
      expect(find.text('Sam Nabil'), findsOneWidget);
    });

    testWidgets('tapping a suggestion inserts the handle and dismisses the panel', (tester) async {
      await pumpOverlay(tester);

      await tester.enterText(find.byType(TextField), 'hi @sa');
      await tester.pumpAndSettle();
      expect(find.text('Sara Adel'), findsOneWidget);

      await tester.tap(find.text('Sara Adel'));
      await tester.pumpAndSettle();

      expect(controller.text, 'hi @sara_films ');
      expect(find.text('Sara Adel'), findsNothing);
      expect(find.text('Sam Nabil'), findsNothing);
    });

    testWidgets('typing a space after the token dismisses the panel', (tester) async {
      await pumpOverlay(tester);

      await tester.enterText(find.byType(TextField), 'hi @sa');
      await tester.pumpAndSettle();
      expect(find.text('Sara Adel'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hi @sa ');
      await tester.pumpAndSettle();

      expect(find.text('Sara Adel'), findsNothing);
    });

    testWidgets('deleting the @ dismisses the panel', (tester) async {
      await pumpOverlay(tester);

      await tester.enterText(find.byType(TextField), 'hi @sa');
      await tester.pumpAndSettle();
      expect(find.text('Sara Adel'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hi sa');
      await tester.pumpAndSettle();

      expect(find.text('Sara Adel'), findsNothing);
    });

    testWidgets('an empty following list never shows a panel, typing is unaffected', (tester) async {
      final emptyRepo = MockReelsRepository();
      when(() => emptyRepo.getFollowingUsers()).thenAnswer(
        (_) async => const Right((items: <FollowedUser>[], nextCursor: null)),
      );
      final cubit = MentionSuggestionsCubit(emptyRepo);
      await cubit.ensureLoaded();
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<MentionSuggestionsCubit>.value(
            value: cubit,
            child: Scaffold(
              body: MentionSuggestionsOverlay(
                controller: controller,
                child: TextField(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hi @sa');
      await tester.pumpAndSettle();

      expect(find.text('Sara Adel'), findsNothing);
      expect(controller.text, 'hi @sa');
    });
  });
}
