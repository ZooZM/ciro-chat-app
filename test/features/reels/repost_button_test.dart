import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/repost_button.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

void main() {
  late MockReelsRepository mockRepository;
  late MockAuthLocalDataSource mockAuthLocalDataSource;

  setUp(() {
    mockRepository = MockReelsRepository();
    mockAuthLocalDataSource = MockAuthLocalDataSource();
    getIt.registerSingleton<ReelsInteractionCubit>(ReelsInteractionCubit(mockRepository));
    getIt.registerSingleton<AuthLocalDataSource>(mockAuthLocalDataSource);
  });

  tearDown(() {
    getIt.unregister<ReelsInteractionCubit>();
    getIt.unregister<AuthLocalDataSource>();
  });

  group('RepostButton (FR-073, v4)', () {
    testWidgets('hides itself on the viewer\'s own reel', (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'creator-1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepostButton(reelId: 'reel-1', creatorId: 'creator-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('renders on another creator\'s reel', (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepostButton(reelId: 'reel-1', creatorId: 'creator-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });
}
