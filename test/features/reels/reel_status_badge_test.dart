import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_status.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/reel_status_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Stack(children: [child])));

void main() {
  testWidgets('renders nothing for a published reel', (tester) async {
    await tester.pumpWidget(_wrap(const ReelStatusBadge(status: ReelStatus.published)));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('renders the processing icon for a pending reel', (tester) async {
    await tester.pumpWidget(_wrap(const ReelStatusBadge(status: ReelStatus.pendingModeration)));
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
    expect(find.byIcon(Icons.block), findsNothing);
  });

  testWidgets('renders the removed icon for a rejected reel', (tester) async {
    await tester.pumpWidget(_wrap(const ReelStatusBadge(status: ReelStatus.rejected)));
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top), findsNothing);
  });
}
