import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_creator.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/upload_cancel_token.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/upload_cubit.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

final _uploadedReel = Reel(
  id: 'r1',
  videoUrl: 'https://example.com/r1.mp4',
  thumbnailUrl: 'https://example.com/r1.jpg',
  createdAt: DateTime(2026, 1, 1),
  creator: const ReelCreator(id: 'c1', name: 'C', avatarUrl: '', viewerFollowing: false),
  likesCount: 0,
  commentsCount: 0,
  sharesCount: 0,
  viewerLiked: false,
);

void main() {
  late MockReelsRepository repository;

  setUpAll(() {
    registerFallbackValue(UploadCancelToken());
  });

  setUp(() {
    repository = MockReelsRepository();
  });

  group('UploadCubit (v3, FR-060)', () {
    blocTest<UploadCubit, UploadState>(
      'a successful upload transitions uploading -> success with the returned reel',
      build: () => UploadCubit(repository),
      setUp: () {
        when(
          () => repository.uploadReel(
            videoPath: any(named: 'videoPath'),
            thumbnailPath: any(named: 'thumbnailPath'),
            description: any(named: 'description'),
            onSendProgress: any(named: 'onSendProgress'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => Right(_uploadedReel));
      },
      act: (cubit) => cubit.upload(
        videoPath: '/tmp/clip.mp4',
        thumbnailPath: '/tmp/clip.jpg',
        description: 'hello #test',
      ),
      expect: () => [
        const UploadState(status: UploadStatus.uploading, progress: 0),
        UploadState(status: UploadStatus.success, uploadedReel: _uploadedReel, progress: 1),
      ],
    );

    blocTest<UploadCubit, UploadState>(
      'onSendProgress updates progress while uploading',
      build: () => UploadCubit(repository),
      setUp: () {
        when(
          () => repository.uploadReel(
            videoPath: any(named: 'videoPath'),
            thumbnailPath: any(named: 'thumbnailPath'),
            description: any(named: 'description'),
            onSendProgress: any(named: 'onSendProgress'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) async {
          final onSendProgress = invocation.namedArguments[#onSendProgress]
              as void Function(int, int)?;
          onSendProgress?.call(50, 100);
          return Right(_uploadedReel);
        });
      },
      act: (cubit) => cubit.upload(videoPath: '/tmp/clip.mp4', description: ''),
      expect: () => [
        const UploadState(status: UploadStatus.uploading, progress: 0),
        const UploadState(status: UploadStatus.uploading, progress: 0.5),
        UploadState(status: UploadStatus.success, uploadedReel: _uploadedReel, progress: 1),
      ],
    );

    blocTest<UploadCubit, UploadState>(
      'a failed upload transitions to an explicit retryable failure state — never a phantom success (FR-060)',
      build: () => UploadCubit(repository),
      setUp: () {
        when(
          () => repository.uploadReel(
            videoPath: any(named: 'videoPath'),
            thumbnailPath: any(named: 'thumbnailPath'),
            description: any(named: 'description'),
            onSendProgress: any(named: 'onSendProgress'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => Left(ServerFailure('upload failed')));
      },
      act: (cubit) => cubit.upload(videoPath: '/tmp/clip.mp4', description: ''),
      expect: () => [
        const UploadState(status: UploadStatus.uploading, progress: 0),
        const UploadState(status: UploadStatus.failure, errorMessage: 'upload failed'),
      ],
      verify: (state) {
        expect(state.state.uploadedReel, isNull);
      },
    );

    test('close() cancels the in-flight upload token', () async {
      when(
        () => repository.uploadReel(
          videoPath: any(named: 'videoPath'),
          thumbnailPath: any(named: 'thumbnailPath'),
          description: any(named: 'description'),
          onSendProgress: any(named: 'onSendProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {
        // Never resolves before close() — simulates a genuinely in-flight upload.
        await Future<void>.delayed(const Duration(seconds: 5));
        return Right(_uploadedReel);
      });

      final cubit = UploadCubit(repository);
      unawaited(cubit.upload(videoPath: '/tmp/clip.mp4', description: ''));
      await Future<void>.delayed(Duration.zero);
      await cubit.close();

      final captured = verify(
        () => repository.uploadReel(
          videoPath: any(named: 'videoPath'),
          thumbnailPath: any(named: 'thumbnailPath'),
          description: any(named: 'description'),
          onSendProgress: any(named: 'onSendProgress'),
          cancelToken: captureAny(named: 'cancelToken'),
        ),
      ).captured;
      final token = captured.single as UploadCancelToken;
      expect(token.isCancelled, isTrue);
    });
  });
}
