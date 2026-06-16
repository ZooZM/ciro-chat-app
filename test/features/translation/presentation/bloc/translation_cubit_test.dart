import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ciro_chat_app/features/translation/domain/entities/caption.dart';
import 'package:ciro_chat_app/features/translation/domain/entities/translation_subscription.dart';
import 'package:ciro_chat_app/features/translation/domain/repositories/translation_repository.dart';
import 'package:ciro_chat_app/features/translation/presentation/bloc/translation_cubit.dart';
import 'package:ciro_chat_app/features/translation/presentation/bloc/translation_state.dart';

class MockTranslationRepository extends Mock implements TranslationRepository {}

class MockRoom extends Mock implements Room {}

void main() {
  late MockTranslationRepository repo;
  late MockRoom room;
  late StreamController<Caption> captionController;

  void Function(String speakerId, String targetLanguage, int remainingSeconds)? onSubscribed;
  void Function(String speakerId, String reason)? onDenied;
  void Function(String speakerId, String reason, bool transient)? onUnavailable;
  void Function()? reconnectListener;

  Caption caption({
    required String speakerId,
    required String text,
    CaptionType type = CaptionType.interim,
    String targetLanguage = 'en',
    String segmentId = 'seg-1',
    required int seq,
  }) {
    return Caption(
      speakerId: speakerId,
      text: text,
      type: type,
      sourceLanguage: 'es',
      targetLanguage: targetLanguage,
      segmentId: segmentId,
      seq: seq,
      ts: seq * 100,
    );
  }

  setUp(() {
    repo = MockTranslationRepository();
    room = MockRoom();
    captionController = StreamController<Caption>.broadcast();

    onSubscribed = null;
    onDenied = null;
    onUnavailable = null;
    reconnectListener = null;

    when(() => repo.attachRoom(room)).thenAnswer((_) => captionController.stream);

    when(() => repo.subscribe(
          roomId: any(named: 'roomId'),
          speakerId: any(named: 'speakerId'),
          targetLanguage: any(named: 'targetLanguage'),
        )).thenReturn(const Right(unit));
    when(() => repo.unsubscribe(
          roomId: any(named: 'roomId'),
          speakerId: any(named: 'speakerId'),
        )).thenReturn(const Right(unit));
    when(() => repo.changeLanguage(
          roomId: any(named: 'roomId'),
          speakerId: any(named: 'speakerId'),
          targetLanguage: any(named: 'targetLanguage'),
        )).thenReturn(const Right(unit));

    when(() => repo.onSubscribed = any()).thenAnswer((inv) {
      onSubscribed = inv.positionalArguments.first as void Function(String, String, int)?;
      return null;
    });
    when(() => repo.onUnsubscribed = any()).thenAnswer((_) => null);
    when(() => repo.onDenied = any()).thenAnswer((inv) {
      onDenied = inv.positionalArguments.first as void Function(String, String)?;
      return null;
    });
    when(() => repo.onUnavailable = any()).thenAnswer((inv) {
      onUnavailable = inv.positionalArguments.first as void Function(String, String, bool)?;
      return null;
    });
    when(() => repo.addReconnectListener(any())).thenAnswer((inv) {
      reconnectListener = inv.positionalArguments.first as void Function();
    });
    when(() => repo.removeReconnectListener(any())).thenReturn(null);
  });

  tearDown(() {
    captionController.close();
  });

  TranslationCubit build() => TranslationCubit(repo);

  group('caption ingestion (T015)', () {
    blocTest<TranslationCubit, TranslationState>(
      'in-order interim updates apply to captionNotifier(speakerId)',
      build: build,
      seed: () => const TranslationState(subscriptions: {
        'sp1': TranslationSubscription(
          speakerId: 'sp1',
          targetLanguage: 'en',
          status: TranslationStatus.active,
        ),
      }),
      act: (cubit) async {
        cubit.attachRoom(room, roomId: 'room1');
        captionController.add(caption(speakerId: 'sp1', text: 'Hello', seq: 1));
        await Future<void>.delayed(Duration.zero);
        captionController.add(caption(speakerId: 'sp1', text: 'Hello there', seq: 2));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const <TranslationState>[],
      verify: (cubit) {
        final value = cubit.captionNotifier('sp1').value;
        expect(value?.text, 'Hello there');
        expect(value?.seq, 2);
      },
    );

    blocTest<TranslationCubit, TranslationState>(
      'a final caption freezes the segment and a later lower-seq interim is dropped',
      build: build,
      seed: () => const TranslationState(subscriptions: {
        'sp1': TranslationSubscription(
          speakerId: 'sp1',
          targetLanguage: 'en',
          status: TranslationStatus.active,
        ),
      }),
      act: (cubit) async {
        cubit.attachRoom(room, roomId: 'room1');
        captionController.add(caption(speakerId: 'sp1', text: 'partial', seq: 1));
        await Future<void>.delayed(Duration.zero);
        captionController.add(
          caption(speakerId: 'sp1', text: 'final text.', seq: 2, type: CaptionType.final_),
        );
        await Future<void>.delayed(Duration.zero);
        captionController.add(caption(speakerId: 'sp1', text: 'stale partial', seq: 1));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const <TranslationState>[],
      verify: (cubit) {
        final value = cubit.captionNotifier('sp1').value;
        expect(value?.text, 'final text.');
        expect(value?.type, CaptionType.final_);
      },
    );

    blocTest<TranslationCubit, TranslationState>(
      'a lower-seq interim for an already higher-seq segment is dropped',
      build: build,
      seed: () => const TranslationState(subscriptions: {
        'sp1': TranslationSubscription(
          speakerId: 'sp1',
          targetLanguage: 'en',
          status: TranslationStatus.active,
        ),
      }),
      act: (cubit) async {
        cubit.attachRoom(room, roomId: 'room1');
        captionController.add(caption(speakerId: 'sp1', text: 'five', seq: 5));
        await Future<void>.delayed(Duration.zero);
        captionController.add(caption(speakerId: 'sp1', text: 'three', seq: 3));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const <TranslationState>[],
      verify: (cubit) {
        final value = cubit.captionNotifier('sp1').value;
        expect(value?.text, 'five');
        expect(value?.seq, 5);
      },
    );

    blocTest<TranslationCubit, TranslationState>(
      'a new segmentId always starts a new line',
      build: build,
      seed: () => const TranslationState(subscriptions: {
        'sp1': TranslationSubscription(
          speakerId: 'sp1',
          targetLanguage: 'en',
          status: TranslationStatus.active,
        ),
      }),
      act: (cubit) async {
        cubit.attachRoom(room, roomId: 'room1');
        captionController.add(
          caption(
            speakerId: 'sp1',
            text: 'first segment final',
            seq: 5,
            segmentId: 'seg-1',
            type: CaptionType.final_,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        captionController.add(
          caption(speakerId: 'sp1', text: 'second segment', seq: 1, segmentId: 'seg-2'),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const <TranslationState>[],
      verify: (cubit) {
        final value = cubit.captionNotifier('sp1').value;
        expect(value?.text, 'second segment');
        expect(value?.segmentId, 'seg-2');
      },
    );

    blocTest<TranslationCubit, TranslationState>(
      'latestActiveCaption tracks the most recent accepted caption across subscribed speakers',
      build: build,
      seed: () => const TranslationState(subscriptions: {
        'sp1': TranslationSubscription(
          speakerId: 'sp1',
          targetLanguage: 'en',
          status: TranslationStatus.active,
        ),
        'sp2': TranslationSubscription(
          speakerId: 'sp2',
          targetLanguage: 'en',
          status: TranslationStatus.active,
        ),
      }),
      act: (cubit) async {
        cubit.attachRoom(room, roomId: 'room1');
        captionController.add(caption(speakerId: 'sp1', text: 'from sp1', seq: 1));
        await Future<void>.delayed(Duration.zero);
        captionController.add(
          caption(speakerId: 'sp2', text: 'from sp2', seq: 1, segmentId: 'seg-x'),
        );
        await Future<void>.delayed(Duration.zero);
        // Mismatched targetLanguage — dropped, latestActiveCaption stays on sp2.
        captionController.add(
          caption(speakerId: 'sp1', text: 'wrong lang', seq: 2, targetLanguage: 'fr'),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const <TranslationState>[],
      verify: (cubit) {
        expect(cubit.latestActiveCaption.value?.speakerId, 'sp2');
        expect(cubit.latestActiveCaption.value?.text, 'from sp2');
      },
    );
  });

  group('subscription lifecycle (T024)', () {
    blocTest<TranslationCubit, TranslationState>(
      'subscribe() -> pending, then translation:subscribed -> active',
      build: build,
      act: (cubit) {
        cubit.attachRoom(room, roomId: 'room1');
        cubit.subscribe(speakerId: 'sp1', targetLanguage: 'en');
        onSubscribed?.call('sp1', 'en', 120);
      },
      expect: () => [
        isA<TranslationState>().having(
          (s) => s.subscriptions['sp1']?.status,
          'sp1 status',
          TranslationStatus.pending,
        ),
        isA<TranslationState>().having(
          (s) => s.subscriptions['sp1']?.status,
          'sp1 status',
          TranslationStatus.active,
        ),
      ],
      verify: (_) {
        verify(() => repo.subscribe(roomId: 'room1', speakerId: 'sp1', targetLanguage: 'en'))
            .called(1);
      },
    );

    blocTest<TranslationCubit, TranslationState>(
      'translation:denied -> denied',
      build: build,
      act: (cubit) {
        cubit.attachRoom(room, roomId: 'room1');
        cubit.subscribe(speakerId: 'sp1', targetLanguage: 'en');
        onDenied?.call('sp1', 'insufficient_credits');
      },
      expect: () => [
        isA<TranslationState>().having(
          (s) => s.subscriptions['sp1']?.status,
          'sp1 status',
          TranslationStatus.pending,
        ),
        isA<TranslationState>()
            .having(
              (s) => s.subscriptions['sp1']?.status,
              'sp1 status',
              TranslationStatus.denied,
            )
            .having(
              (s) => s.subscriptions['sp1']?.deniedReason,
              'sp1 deniedReason',
              'insufficient_credits',
            ),
      ],
    );

    blocTest<TranslationCubit, TranslationState>(
      'active -> translation_unavailable -> unavailable',
      build: build,
      act: (cubit) {
        cubit.attachRoom(room, roomId: 'room1');
        cubit.subscribe(speakerId: 'sp1', targetLanguage: 'en');
        onSubscribed?.call('sp1', 'en', 120);
        onUnavailable?.call('sp1', 'service_outage', true);
      },
      expect: () => [
        isA<TranslationState>().having(
          (s) => s.subscriptions['sp1']?.status,
          'sp1 status',
          TranslationStatus.pending,
        ),
        isA<TranslationState>().having(
          (s) => s.subscriptions['sp1']?.status,
          'sp1 status',
          TranslationStatus.active,
        ),
        isA<TranslationState>()
            .having(
              (s) => s.subscriptions['sp1']?.status,
              'sp1 status',
              TranslationStatus.unavailable,
            )
            .having(
              (s) => s.subscriptions['sp1']?.unavailableReason,
              'sp1 unavailableReason',
              'service_outage',
            ),
      ],
    );

    blocTest<TranslationCubit, TranslationState>(
      'changeLanguage() re-enters pending then active with the new language',
      build: build,
      act: (cubit) {
        cubit.attachRoom(room, roomId: 'room1');
        cubit.subscribe(speakerId: 'sp1', targetLanguage: 'en');
        onSubscribed?.call('sp1', 'en', 120);
        cubit.changeLanguage(speakerId: 'sp1', targetLanguage: 'ar');
        onSubscribed?.call('sp1', 'ar', 100);
      },
      expect: () => [
        isA<TranslationState>()
            .having((s) => s.subscriptions['sp1']?.status, 'status', TranslationStatus.pending)
            .having((s) => s.subscriptions['sp1']?.targetLanguage, 'targetLanguage', 'en'),
        isA<TranslationState>()
            .having((s) => s.subscriptions['sp1']?.status, 'status', TranslationStatus.active)
            .having((s) => s.subscriptions['sp1']?.targetLanguage, 'targetLanguage', 'en'),
        isA<TranslationState>()
            .having((s) => s.subscriptions['sp1']?.status, 'status', TranslationStatus.pending)
            .having((s) => s.subscriptions['sp1']?.targetLanguage, 'targetLanguage', 'ar'),
        isA<TranslationState>()
            .having((s) => s.subscriptions['sp1']?.status, 'status', TranslationStatus.active)
            .having((s) => s.subscriptions['sp1']?.targetLanguage, 'targetLanguage', 'ar'),
      ],
      verify: (_) {
        verify(() => repo.changeLanguage(roomId: 'room1', speakerId: 'sp1', targetLanguage: 'ar'))
            .called(1);
      },
    );

    test('unsubscribe() -> off, removing the entry and disposing the caption notifier', () async {
      final cubit = build();
      cubit.attachRoom(room, roomId: 'room1');
      cubit.subscribe(speakerId: 'sp1', targetLanguage: 'en');
      onSubscribed?.call('sp1', 'en', 120);

      final notifier = cubit.captionNotifier('sp1');
      captionController.add(caption(speakerId: 'sp1', text: 'hi', seq: 1));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.value?.text, 'hi');

      cubit.unsubscribe('sp1');

      expect(cubit.state.subscriptions.containsKey('sp1'), isFalse);
      expect(() => notifier.addListener(() {}), throwsFlutterError);
      expect(cubit.captionNotifier('sp1'), isNot(same(notifier)));

      verify(() => repo.unsubscribe(roomId: 'room1', speakerId: 'sp1')).called(1);

      await cubit.close();
    });

    test(
      'close() unsubscribes every pending/active/unavailable speaker and disposes notifiers',
      () async {
        final cubit = build();
        cubit.attachRoom(room, roomId: 'room1');

        cubit.subscribe(speakerId: 'sp1', targetLanguage: 'en');
        onSubscribed?.call('sp1', 'en', 120); // active

        cubit.subscribe(speakerId: 'sp2', targetLanguage: 'en'); // pending

        cubit.subscribe(speakerId: 'sp3', targetLanguage: 'en');
        onDenied?.call('sp3', 'insufficient_credits'); // denied — not live

        final latestNotifier = cubit.latestActiveCaption;
        final sp1Notifier = cubit.captionNotifier('sp1');

        await cubit.close();

        verify(() => repo.unsubscribe(roomId: 'room1', speakerId: 'sp1')).called(1);
        verify(() => repo.unsubscribe(roomId: 'room1', speakerId: 'sp2')).called(1);
        verifyNever(() => repo.unsubscribe(roomId: 'room1', speakerId: 'sp3'));

        expect(() => latestNotifier.addListener(() {}), throwsFlutterError);
        expect(() => sp1Notifier.addListener(() {}), throwsFlutterError);
      },
    );

    test(
      'FR-016: reconnect re-subscribes pending/active speakers with their last-selected language',
      () async {
        final cubit = build();
        cubit.attachRoom(room, roomId: 'room1');

        cubit.subscribe(speakerId: 'sp1', targetLanguage: 'en');
        onSubscribed?.call('sp1', 'en', 120); // active

        cubit.subscribe(speakerId: 'sp2', targetLanguage: 'fr'); // pending

        clearInteractions(repo);

        reconnectListener?.call();

        expect(cubit.state.subscriptions['sp1']?.status, TranslationStatus.pending);
        expect(cubit.state.subscriptions['sp2']?.status, TranslationStatus.pending);

        verify(() => repo.subscribe(roomId: 'room1', speakerId: 'sp1', targetLanguage: 'en'))
            .called(1);
        verify(() => repo.subscribe(roomId: 'room1', speakerId: 'sp2', targetLanguage: 'fr'))
            .called(1);

        await cubit.close();
      },
    );
  });
}
