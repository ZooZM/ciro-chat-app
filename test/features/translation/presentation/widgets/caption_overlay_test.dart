import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ciro_chat_app/features/translation/domain/entities/caption.dart';
import 'package:ciro_chat_app/features/translation/domain/repositories/translation_repository.dart';
import 'package:ciro_chat_app/features/translation/presentation/bloc/translation_cubit.dart';
import 'package:ciro_chat_app/features/translation/presentation/widgets/caption_banner.dart';
import 'package:ciro_chat_app/features/translation/presentation/widgets/caption_overlay.dart';
import 'package:ciro_chat_app/features/video_call/presentation/bloc/call_cubit.dart';

class MockTranslationRepository extends Mock implements TranslationRepository {}

class MockCallCubit extends MockCubit<CallState> implements CallCubit {}

void main() {
  late MockTranslationRepository repo;
  late MockCallCubit callCubit;
  late TranslationCubit cubit;
  late int gridBuildCount;

  Caption caption({required String text, required CaptionType type, required int seq}) {
    return Caption(
      speakerId: 'sp1',
      text: text,
      type: type,
      sourceLanguage: 'es',
      targetLanguage: 'en',
      segmentId: 'seg-1',
      seq: seq,
      ts: seq * 100,
    );
  }

  setUp(() {
    repo = MockTranslationRepository();
    callCubit = MockCallCubit();

    when(() => repo.onSubscribed = any()).thenAnswer((_) => null);
    when(() => repo.onUnsubscribed = any()).thenAnswer((_) => null);
    when(() => repo.onDenied = any()).thenAnswer((_) => null);
    when(() => repo.onUnavailable = any()).thenAnswer((_) => null);
    when(() => repo.addReconnectListener(any())).thenAnswer((_) {});
    when(() => repo.removeReconnectListener(any())).thenReturn(null);

    cubit = TranslationCubit(repo);
    gridBuildCount = 0;

    whenListen(callCubit, const Stream<CallState>.empty(), initialState: const CallIdle());
  });

  tearDown(() async {
    await cubit.close();
  });

  Widget buildHarness() {
    return MaterialApp(
      home: BlocProvider<TranslationCubit>.value(
        value: cubit,
        child: Scaffold(
          body: Column(
            children: [
              // Stand-in for the call screen's video-grid subtree: it must
              // NOT rebuild when a caption ValueNotifier updates
              // (FR-007/FR-015/SC-007).
              BlocBuilder<CallCubit, CallState>(
                bloc: callCubit,
                builder: (context, state) {
                  gridBuildCount++;
                  return const Text('video-grid');
                },
              ),
              CaptionOverlay(caption: cubit.captionNotifier('sp1')),
              CaptionBanner(caption: cubit.captionNotifier('sp1'), participants: const []),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets(
    'caption updates rebuild CaptionOverlay/CaptionBanner without rebuilding the video grid (T022)',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      expect(gridBuildCount, 1);

      // interim
      cubit.captionNotifier('sp1').value = caption(
        text: 'Hola',
        type: CaptionType.interim,
        seq: 1,
      );
      await tester.pump();
      expect(find.text('Hola'), findsOneWidget);
      expect(gridBuildCount, 1);

      // interim (corrected)
      cubit.captionNotifier('sp1').value = caption(
        text: 'Hola mundo',
        type: CaptionType.interim,
        seq: 2,
      );
      await tester.pump();
      expect(find.text('Hola mundo'), findsOneWidget);
      expect(gridBuildCount, 1);

      // final — also drives the CaptionBanner fallback
      final finalCaption = caption(text: 'Hola mundo.', type: CaptionType.final_, seq: 3);
      cubit.captionNotifier('sp1').value = finalCaption;
      await tester.pump();
      expect(find.text('Hola mundo.'), findsWidgets); // CaptionOverlay and CaptionBanner both have it
      expect(find.text('sp1: Hola mundo.'), findsOneWidget); // CaptionBanner
      expect(gridBuildCount, 1);
    },
  );
}
