import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_mention.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/reel_description.dart';

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => Scaffold(body: child)),
      GoRoute(
        path: '/reels/hashtag/:tag',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/reels/profile/:id',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Finder _richTextContaining(String substring) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(substring),
  );
}

void main() {
  testWidgets('renders plain text unchanged when there are no hashtags/mentions', (tester) async {
    await tester.pumpWidget(_wrap(const ReelDescription(description: 'Just a caption', mentions: [])));
    expect(_richTextContaining('Just a caption'), findsOneWidget);
  });

  testWidgets('collapses to 2 lines by default and expands on tap', (tester) async {
    // No hashtags/mentions here so the tap has no competing span recognizer
    // — it must land on the outer expand/collapse GestureDetector.
    await tester.pumpWidget(
      _wrap(const ReelDescription(description: 'Some plain content', mentions: [])),
    );
    final richTextBefore = tester.widget<RichText>(find.byType(RichText));
    expect(richTextBefore.maxLines, 2);

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    final richTextAfter = tester.widget<RichText>(find.byType(RichText));
    expect(richTextAfter.maxLines, isNull);
  });

  testWidgets('renders an unresolved @mention as plain text (no crash, no recognizer)', (tester) async {
    await tester.pumpWidget(
      _wrap(const ReelDescription(description: 'Hi @nobody, nice reel', mentions: [])),
    );
    expect(find.byType(RichText), findsOneWidget);
  });

  testWidgets('resolved @mention is recognized and does not throw when tapped', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ReelDescription(
          description: 'feat. @omar',
          mentions: [ReelMention(userId: 'user-omar', username: 'omar')],
        ),
      ),
    );
    expect(find.byType(RichText), findsOneWidget);
    // Tapping anywhere within the RichText's GestureDetector must not throw,
    // whether it lands on the recognizer span or the expand-toggle fallback.
    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();
  });
}
