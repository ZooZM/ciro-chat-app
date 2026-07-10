import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/report_reason.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/report_reasons_sheet.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

void main() {
  late MockReelsRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(ReportReason.spam);
  });

  setUp(() {
    mockRepository = MockReelsRepository();
    getIt.registerSingleton<ReelsRepository>(mockRepository);
  });

  tearDown(() {
    getIt.unregister<ReelsRepository>();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showReportReasonsSheet(context, 'reel-1'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder submitButton() => find.widgetWithText(ElevatedButton, 'reels.report_submit');

  group('ReportReasonsSheet (FR-068/FR-069, v4)', () {
    testWidgets('submit is disabled until a reason is selected', (tester) async {
      await pumpSheet(tester);
      final button = tester.widget<ElevatedButton>(submitButton());
      expect(button.onPressed, isNull);
    });

    testWidgets('selecting a preset reason enables submit; tapping it reports with no customReason', (tester) async {
      when(() => mockRepository.reportReel(any(), any(), customReason: any(named: 'customReason')))
          .thenAnswer((_) async => const Right(false));

      await pumpSheet(tester);
      await tester.tap(find.text('reels.report_reason_spam'));
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(submitButton());
      expect(button.onPressed, isNotNull);

      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      verify(() => mockRepository.reportReel('reel-1', ReportReason.spam, customReason: null)).called(1);
    });

    testWidgets('selecting Other keeps submit disabled until non-empty text is entered', (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.text('reels.report_reason_other'));
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(submitButton()).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(submitButton()).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'a real reason');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(submitButton()).onPressed, isNotNull);
    });

    testWidgets('submits the trimmed custom reason for "other"', (tester) async {
      when(() => mockRepository.reportReel(any(), any(), customReason: any(named: 'customReason')))
          .thenAnswer((_) async => const Right(false));

      await pumpSheet(tester);
      await tester.tap(find.text('reels.report_reason_other'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  a real reason  ');
      await tester.pumpAndSettle();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      verify(() => mockRepository.reportReel('reel-1', ReportReason.other, customReason: 'a real reason'))
          .called(1);
    });

    testWidgets('shows a distinct notice and keeps the sheet open on a 429', (tester) async {
      when(() => mockRepository.reportReel(any(), any(), customReason: any(named: 'customReason')))
          .thenAnswer((_) async => const Left(RateLimitedFailure()));

      await pumpSheet(tester);
      await tester.tap(find.text('reels.report_reason_spam'));
      await tester.pumpAndSettle();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text('reels.report_rate_limited'), findsOneWidget);
      // Sheet stays open on failure (only success pops it).
      expect(find.byType(TextField), findsNothing); // spam selected, not other — sanity: sheet content still there
      expect(submitButton(), findsOneWidget);
    });
  });
}
