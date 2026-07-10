import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_creator.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/reel_more_button.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

Reel _reel(String id, {required String creatorId}) => Reel(
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
  late MockReelsRepository mockRepository;
  late MockAuthLocalDataSource mockAuthLocalDataSource;

  setUp(() {
    mockRepository = MockReelsRepository();
    mockAuthLocalDataSource = MockAuthLocalDataSource();
    getIt.registerSingleton<ReelsRepository>(mockRepository);
    getIt.registerSingleton<ReelsInteractionCubit>(
      ReelsInteractionCubit(mockRepository),
    );
    getIt.registerSingleton<AuthLocalDataSource>(mockAuthLocalDataSource);
  });

  tearDown(() {
    getIt.unregister<ReelsRepository>();
    getIt.unregister<ReelsInteractionCubit>();
    getIt.unregister<AuthLocalDataSource>();
  });

  group('ReelMoreButton (FR-067/FR-068, v4)', () {
    testWidgets('owner sees Save and Delete, not Report', (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'owner-1');
      final reel = _reel('reel-1', creatorId: 'owner-1');

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Stack(children: [ReelMoreButton(reel: reel)]))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('reels.save'), findsOneWidget);
      expect(find.text('reels.delete_menu'), findsOneWidget);
      expect(find.text('reels.report_menu'), findsNothing);
    });

    testWidgets('non-owner sees Save and Report, not Delete', (tester) async {
      when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'viewer-1');
      final reel = _reel('reel-1', creatorId: 'owner-1');

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Stack(children: [ReelMoreButton(reel: reel)]))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('reels.save'), findsOneWidget);
      expect(find.text('reels.report_menu'), findsOneWidget);
      expect(find.text('reels.delete_menu'), findsNothing);
    });
  });
}
