import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ciro_chat_app/main.dart' as app;

/// Run as either side of the call:
///   --dart-define=ROLE=host   (creates the group, starts the call, opens the
///                              CC sheet on the guest's tile)
///   --dart-define=ROLE=guest  (waits for the incoming group call and joins)
///
/// Host-only:
///   --dart-define=GROUP_NAME=Translation E2E
///   --dart-define=PEER_PHONE=+201500000002   (guest's full phone number, as
///                              shown in the create-group contact list)
const _role = String.fromEnvironment('ROLE', defaultValue: 'host');
const _groupName = String.fromEnvironment(
  'GROUP_NAME',
  defaultValue: 'Translation E2E',
);
const _peerPhone = String.fromEnvironment(
  'PEER_PHONE',
  defaultValue: '+201500000002',
);

/// Pump real frames for [total], allowing async/socket/LiveKit work to
/// progress without using pumpAndSettle (which never settles while a call's
/// duration timer or video texture keeps scheduling frames).
Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 500);
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    await Future<void>.delayed(step);
  }
}

/// Polls [finder] by pumping real frames until it matches or [timeout] elapses.
Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  const step = Duration(milliseconds: 500);
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return true;
    await Future<void>.delayed(step);
  }
  return finder.evaluate().isNotEmpty;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('translation group call ($_role)', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(
      find.byType(BottomNavigationBar),
      findsOneWidget,
      reason: 'expected an already-authenticated session (run login_test first)',
    );

    if (_role == 'guest') {
      final joined = await _waitFor(
        tester,
        find.text('Join'),
        timeout: const Duration(seconds: 90),
      );
      expect(joined, isTrue, reason: 'incoming group call screen never appeared');
      await tester.tap(find.text('Join'));
      await _pumpFor(tester, const Duration(seconds: 5));

      // Stay connected so the host can interact with this participant's tile.
      await _pumpFor(tester, const Duration(seconds: 120));
      return;
    }

    // ── host ────────────────────────────────────────────────────────────
    // Seed the peer as a device contact so the backend's sync-contacts step
    // can match it (fresh simulators have an empty address book). Privacy
    // permissions are pre-granted via `xcrun simctl privacy grant all`.
    final existing = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final alreadyThere = existing.any(
      (c) => c.phones.any((p) => p.number.contains('1500000002')),
    );
    if (!alreadyThere) {
      await FlutterContacts.create(
        Contact(
          name: const Name(first: 'Guest', last: 'User'),
          phones: [Phone(number: _peerPhone)],
        ),
      );
    }

    await tester.tap(find.byIcon(Icons.group_add));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.enterText(find.byType(TextField).first, _groupName);
    await tester.pumpAndSettle();

    final peerFound = await _waitFor(
      tester,
      find.textContaining(_peerPhone),
      timeout: const Duration(seconds: 30),
    );
    expect(
      peerFound,
      isTrue,
      reason:
          'peer contact $_peerPhone not found in create-group list — '
          'check simulator contact seeding / backend sync',
    );
    await tester.tap(find.textContaining(_peerPhone).first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await _pumpFor(tester, const Duration(seconds: 8));

    final groupOpened = await _waitFor(
      tester,
      find.text(_groupName),
      timeout: const Duration(seconds: 15),
    );
    expect(groupOpened, isTrue, reason: 'new group "$_groupName" not in chat list');
    await tester.tap(find.text(_groupName).first);
    await _pumpFor(tester, const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.call_outlined));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Video Call'));
    await _pumpFor(tester, const Duration(seconds: 10));

    final ccVisible = await _waitFor(
      tester,
      find.byIcon(Icons.closed_caption),
      timeout: const Duration(seconds: 90),
    );
    expect(
      ccVisible,
      isTrue,
      reason: 'remote participant CC icon never appeared — guest may not have joined',
    );

    await tester.tap(find.byIcon(Icons.closed_caption).first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Live Translation'), findsOneWidget);
    await tester.tap(find.text('Enable live captions'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply'));
    await _pumpFor(tester, const Duration(seconds: 2));

    // Observe whatever the backend reports back for the new subscription.
    String outcome = 'no caption/badge/snackbar observed within timeout';
    const step = Duration(milliseconds: 500);
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(step);
      if (find.text('Translation unavailable').evaluate().isNotEmpty) {
        outcome = 'unavailable badge shown';
        break;
      }
      final denied = find.textContaining('Translation unavailable:');
      if (denied.evaluate().isNotEmpty) {
        outcome = 'denied snackbar: ${tester.widget<Text>(denied.first).data}';
        break;
      }
      if (find.textContaining('Translation request was denied').evaluate().isNotEmpty) {
        outcome = 'denied snackbar: unknown reason';
        break;
      }
      await Future<void>.delayed(step);
    }
    debugPrint('TRANSLATION OUTCOME ($_role): $outcome');

    // Give the guest time to finish its 120s hold before this process exits.
    await _pumpFor(tester, const Duration(seconds: 30));
  });
}
