import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/followed_user.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/mention_suggestions_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/upload_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/pages/upload_reel_screen.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

void main() {
  late MockReelsRepository mockRepository;

  setUp(() {
    mockRepository = MockReelsRepository();
    when(() => mockRepository.getFollowingUsers()).thenAnswer(
      (_) async => const Right((items: <FollowedUser>[], nextCursor: null)),
    );
    getIt.registerFactory<UploadCubit>(() => UploadCubit(mockRepository));
    getIt.registerFactory<MentionSuggestionsCubit>(
      () => MentionSuggestionsCubit(mockRepository),
    );
  });

  tearDown(() {
    getIt.unregister<UploadCubit>();
    getIt.unregister<MentionSuggestionsCubit>();
  });

  group('UploadReelScreen post-details step (v5, FR-082)', () {
    testWidgets('renders exactly a description field, a preview thumbnail, and a Post button',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UploadReelScreen(videoPath: '/tmp/clip.mp4', thumbnailPath: '/tmp/clip.jpg'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'reels.post_submit'), findsOneWidget);

      // FR-082 removals: no location/link/privacy/share-to/drafts/#/@ helper
      // buttons — none of that UI is ever constructed on this screen.
      expect(find.byIcon(Icons.location_on), findsNothing);
      expect(find.byIcon(Icons.link), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('submitting calls UploadCubit.upload with the trimmed video/thumbnail and typed description',
        (tester) async {
      // Never resolves within this test's scope — only the call itself
      // (and its arguments) matter here.
      when(
        () => mockRepository.uploadReel(
          videoPath: any(named: 'videoPath'),
          thumbnailPath: any(named: 'thumbnailPath'),
          description: any(named: 'description'),
          onSendProgress: any(named: 'onSendProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => Completer<Either<Failure, Reel>>().future);

      await tester.pumpWidget(
        const MaterialApp(
          home: UploadReelScreen(videoPath: '/tmp/clip.mp4', thumbnailPath: '/tmp/clip.jpg'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hello #test');
      await tester.tap(find.widgetWithText(ElevatedButton, 'reels.post_submit'));
      await tester.pump();

      verify(
        () => mockRepository.uploadReel(
          videoPath: '/tmp/clip.mp4',
          thumbnailPath: '/tmp/clip.jpg',
          description: 'hello #test',
          onSendProgress: any(named: 'onSendProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });
  });
}
