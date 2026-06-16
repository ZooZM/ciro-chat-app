import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_reaction.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_viewer.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  late MockStatusRepository mockRepository;

  final tNow = DateTime(2026, 6, 10);

  StatusEntity buildStatus({required String id, bool isMine = false}) {
    return StatusEntity(
      id: id,
      authorName: 'Author',
      authorAvatar: '',
      timestamp: tNow,
      expiresAt: tNow.add(const Duration(hours: 24)),
      isMine: isMine,
    );
  }

  setUp(() {
    mockRepository = MockStatusRepository();
  });

  group('loadRecentStatuses', () {
    blocTest<StatusCubit, StatusState>(
      'emits [StatusLoading, StatusLoaded] when all repository calls succeed',
      build: () {
        final myStatus = buildStatus(id: 'my-status', isMine: true);
        when(() => mockRepository.getRecentStatuses())
            .thenAnswer((_) async => Right([buildStatus(id: 'other-1')]));
        when(() => mockRepository.getViewedStatuses()).thenAnswer((_) async => const Right([]));
        when(() => mockRepository.getMyStatuses()).thenAnswer((_) async => Right([myStatus]));
        when(() => mockRepository.statusStream).thenAnswer((_) => const Stream.empty());
        when(() => mockRepository.statusViewerAddedStream).thenAnswer((_) => const Stream.empty());
        when(() => mockRepository.statusReactedStream).thenAnswer((_) => const Stream.empty());
        return StatusCubit(mockRepository);
      },
      act: (cubit) => cubit.loadRecentStatuses(),
      expect: () => [
        isA<StatusLoading>(),
        isA<StatusLoaded>()
            .having((s) => s.recentStatuses.map((e) => e.id), 'recentStatuses ids', ['other-1'])
            .having((s) => s.myStatuses.map((e) => e.id), 'myStatuses ids', ['my-status']),
      ],
    );

    blocTest<StatusCubit, StatusState>(
      'emits [StatusLoading, StatusError] when getRecentStatuses fails',
      build: () {
        when(() => mockRepository.getRecentStatuses())
            .thenAnswer((_) async => const Left(CacheFailure('boom')));
        when(() => mockRepository.getViewedStatuses()).thenAnswer((_) async => const Right([]));
        when(() => mockRepository.getMyStatuses()).thenAnswer((_) async => const Right([]));
        when(() => mockRepository.statusStream).thenAnswer((_) => const Stream.empty());
        when(() => mockRepository.statusViewerAddedStream).thenAnswer((_) => const Stream.empty());
        when(() => mockRepository.statusReactedStream).thenAnswer((_) => const Stream.empty());
        return StatusCubit(mockRepository);
      },
      act: (cubit) => cubit.loadRecentStatuses(),
      expect: () => [
        isA<StatusLoading>(),
        isA<StatusError>(),
      ],
    );
  });

  group('realtime updates to own status (T042/T045)', () {
    late StreamController<({String statusId, StatusViewer viewer})> viewerController;
    late StreamController<({String statusId, StatusReaction reaction})> reactedController;

    setUp(() {
      viewerController = StreamController.broadcast();
      reactedController = StreamController.broadcast();
    });

    tearDown(() {
      viewerController.close();
      reactedController.close();
    });

    StatusCubit buildCubit() {
      final myStatus = buildStatus(id: 'my-status', isMine: true);
      when(() => mockRepository.getRecentStatuses()).thenAnswer((_) async => const Right([]));
      when(() => mockRepository.getViewedStatuses()).thenAnswer((_) async => const Right([]));
      when(() => mockRepository.getMyStatuses()).thenAnswer((_) async => Right([myStatus]));
      when(() => mockRepository.statusStream).thenAnswer((_) => const Stream.empty());
      when(() => mockRepository.statusViewerAddedStream).thenAnswer((_) => viewerController.stream);
      when(() => mockRepository.statusReactedStream).thenAnswer((_) => reactedController.stream);
      return StatusCubit(mockRepository);
    }

    blocTest<StatusCubit, StatusState>(
      'appends a viewer to myStatus when statusViewerAddedStream fires for it',
      build: buildCubit,
      act: (cubit) async {
        await cubit.loadRecentStatuses();
        viewerController.add((
          statusId: 'my-status',
          viewer: StatusViewer(userId: 'viewer-1', name: 'Viewer', avatarUrl: '', viewedAt: tNow),
        ));
        await Future.delayed(Duration.zero);
      },
      skip: 1, // StatusLoading
      expect: () => [
        isA<StatusLoaded>(), // initial load
        isA<StatusLoaded>().having(
          (s) => s.myStatuses.firstWhere((e) => e.id == 'my-status').viewers.map((v) => v.userId),
          'myStatus viewer ids',
          ['viewer-1'],
        ),
      ],
    );

    blocTest<StatusCubit, StatusState>(
      'ignores statusViewerAddedStream events for a different status id',
      build: buildCubit,
      act: (cubit) async {
        await cubit.loadRecentStatuses();
        viewerController.add((
          statusId: 'someone-elses-status',
          viewer: StatusViewer(userId: 'viewer-1', name: 'Viewer', avatarUrl: '', viewedAt: tNow),
        ));
        await Future.delayed(Duration.zero);
      },
      skip: 1, // StatusLoading
      expect: () => [
        isA<StatusLoaded>(), // initial load only - no further state
      ],
    );

    blocTest<StatusCubit, StatusState>(
      'appends a reaction to myStatus when statusReactedStream fires for it',
      build: buildCubit,
      act: (cubit) async {
        await cubit.loadRecentStatuses();
        reactedController.add((
          statusId: 'my-status',
          reaction: StatusReaction(userId: 'viewer-1', reaction: '❤️', createdAt: tNow),
        ));
        await Future.delayed(Duration.zero);
      },
      skip: 1, // StatusLoading
      expect: () => [
        isA<StatusLoaded>(), // initial load
        isA<StatusLoaded>().having(
          (s) => s.myStatuses.firstWhere((e) => e.id == 'my-status').reactions.map((r) => r.userId),
          'myStatus reaction ids',
          ['viewer-1'],
        ),
      ],
    );
  });
}
