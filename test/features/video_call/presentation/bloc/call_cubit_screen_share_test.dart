import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/core/services/callkit_service.dart';
import 'package:ciro_chat_app/features/call_history/domain/entities/call_history_record.dart';
import 'package:ciro_chat_app/features/call_history/domain/repositories/call_history_repository.dart';
import 'package:ciro_chat_app/features/video_call/domain/repositories/video_call_repository.dart';
import 'package:ciro_chat_app/features/video_call/presentation/bloc/call_cubit.dart';

class MockSocketService extends Mock implements SocketService {}
class MockVideoCallRepository extends Mock implements VideoCallRepository {}
class MockCallKitService extends Mock implements CallKitService {}
class MockCallHistoryRepository extends Mock implements CallHistoryRepository {}

/// Stubs every setter that [CallCubit._bindSocketListeners] assigns at construction.
void _stubSocketSetters(MockSocketService s) {
  when(() => s.onIncomingCall = any()).thenReturn(null);
  when(() => s.onCallAccepted = any()).thenReturn(null);
  when(() => s.onCallRejected = any()).thenReturn(null);
  when(() => s.onCallHandledElsewhere = any()).thenReturn(null);
  when(() => s.onIncomingGroupCall = any()).thenReturn(null);
  when(() => s.onGroupCallParticipantJoined = any()).thenReturn(null);
  when(() => s.onGroupCallParticipantLeft = any()).thenReturn(null);
  when(() => s.onGroupCallRecordingStateChanged = any()).thenReturn(null);
  when(() => s.onScreenShareRejected = any()).thenReturn(null);
  when(() => s.onScreenShareStateChanged = any()).thenReturn(null);
}

CallActive _active({
  String chatRoomId = 'room1',
  bool isLocallySharingScreen = false,
  String activeSharerUserId = '',
  String activeSharerName = '',
  bool activeSharerHasAudio = false,
  Set<String> mutedScreenAudioBySharerId = const {},
}) =>
    CallActive(
      livekitToken: 'tok',
      livekitUrl: 'wss://lk.test',
      contactName: 'Alice',
      chatRoomId: chatRoomId,
      isLocallySharingScreen: isLocallySharingScreen,
      activeSharerUserId: activeSharerUserId,
      activeSharerName: activeSharerName,
      activeSharerHasAudio: activeSharerHasAudio,
      mutedScreenAudioBySharerId: mutedScreenAudioBySharerId,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Swallow flutter_ringtone_player platform calls — plugin isn't registered in tests.
  setUpAll(() {
    registerFallbackValue(CallHistoryRecord(
      id: 'fallback',
      contactUserId: 'fallback',
      contactName: 'Fallback',
      direction: CallDirection.outgoing,
      outcome: CallOutcome.answered,
      callType: CallType.voice,
      startedAt: 0,
    ));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_ringtone_player'),
      (_) async => null,
    );
  });

  late MockSocketService socket;
  late MockVideoCallRepository repo;
  late MockCallKitService callKit;
  late MockCallHistoryRepository historyRepo;

  setUp(() {
    socket = MockSocketService();
    repo = MockVideoCallRepository();
    callKit = MockCallKitService();
    historyRepo = MockCallHistoryRepository();
    _stubSocketSetters(socket);
    when(() => repo.onLocalScreenShareEndedExternally = any()).thenReturn(null);
    when(() => callKit.actions).thenAnswer((_) => const Stream<CallKitAction>.empty());
    when(() => historyRepo.add(any())).thenAnswer((_) async => const Right(unit));
  });

  CallCubit build() => CallCubit(socket, repo, callKit, historyRepo);

  // ── (a) startScreenShare happy path ────────────────────────────────────────

  blocTest<CallCubit, CallState>(
    '(a) startScreenShare happy path: emits sharing state and calls socket',
    build: build,
    seed: _active,
    setUp: () {
      when(() => repo.setScreenShareEnabled(true, withDeviceAudio: false))
          .thenAnswer((_) async => const Right(null));
      when(() => socket.emitScreenShareStateChanged(
            chatRoomId: any(named: 'chatRoomId'),
            userId: any(named: 'userId'),
            userName: any(named: 'userName'),
            isSharing: any(named: 'isSharing'),
            withAudio: any(named: 'withAudio'),
          )).thenReturn(null);
    },
    act: (c) => c.startScreenShare(
      withDeviceAudio: false,
      localUserId: 'u1',
      localUserName: 'User1',
    ),
    expect: () => [
      isA<CallActive>().having((s) => s.isLocallySharingScreen, 'isLocallySharingScreen', true),
    ],
    verify: (_) {
      verify(() => socket.emitScreenShareStateChanged(
            chatRoomId: 'room1',
            userId: 'u1',
            userName: 'User1',
            isSharing: true,
            withAudio: false,
          )).called(1);
    },
  );

  // ── (b) startScreenShare conflict — skips repo, emits side-event ───────────

  test('(b) startScreenShare conflict: conflict side-event emitted, repo not called', () async {
    final cubit = build()..emit(_active(activeSharerUserId: 'other-user'));

    // Set up stream expectation first, then drive the action.
    final streamFuture = expectLater(
      cubit.sideEvents,
      emits(isA<CallScreenShareConflict>()),
    );

    await cubit.startScreenShare(
      withDeviceAudio: false,
      localUserId: 'u1',
      localUserName: 'User1',
    );
    await streamFuture;

    verifyNever(() => repo.setScreenShareEnabled(any()));
    await cubit.close();
  });

  // ── (c) startScreenShare denied by OS → CallScreenShareDenied side-event ──

  test('(c) startScreenShare repo denied: CallScreenShareDenied side-event emitted', () async {
    when(() => repo.setScreenShareEnabled(true, withDeviceAudio: false))
        .thenAnswer((_) async => Left(const ScreenShareDeniedFailure()));

    final cubit = build()..emit(_active());

    final streamFuture = expectLater(
      cubit.sideEvents,
      emits(isA<CallScreenShareDenied>()),
    );

    await cubit.startScreenShare(
      withDeviceAudio: false,
      localUserId: 'u1',
      localUserName: 'User1',
    );
    await streamFuture;

    await cubit.close();
  });

  // ── (d) stopScreenShare emits cleanup state + socket stop event ────────────

  blocTest<CallCubit, CallState>(
    '(d) stopScreenShare: clears sharing state and emits socket isSharing:false',
    build: build,
    seed: () => _active(
      isLocallySharingScreen: true,
      activeSharerUserId: 'u1',
      activeSharerName: 'User1',
    ),
    setUp: () {
      when(() => repo.setScreenShareEnabled(false))
          .thenAnswer((_) async => const Right(null));
      when(() => socket.emitScreenShareStateChanged(
            chatRoomId: any(named: 'chatRoomId'),
            userId: any(named: 'userId'),
            userName: any(named: 'userName'),
            isSharing: any(named: 'isSharing'),
            withAudio: any(named: 'withAudio'),
          )).thenReturn(null);
    },
    act: (c) => c.stopScreenShare(localUserId: 'u1', localUserName: 'User1'),
    expect: () => [
      isA<CallActive>()
          .having((s) => s.isLocallySharingScreen, 'isLocallySharingScreen', false)
          .having((s) => s.activeSharerUserId, 'activeSharerUserId', ''),
    ],
    verify: (_) {
      verify(() => socket.emitScreenShareStateChanged(
            chatRoomId: 'room1',
            userId: 'u1',
            userName: 'User1',
            isSharing: false,
            withAudio: false,
          )).called(1);
    },
  );

  // ── (e) onScreenShareStateChanged updates activeSharer fields ──────────────

  test('(e) screenShareStateChanged for remote user updates activeSharer* fields', () async {
    // Capture the callback the cubit registers for onScreenShareStateChanged.
    late void Function(String, String, String, bool, bool) captured;
    when(() => socket.onScreenShareStateChanged = any()).thenAnswer((inv) {
      captured = inv.positionalArguments.first
          as void Function(String, String, String, bool, bool);
      return;
    });

    final cubit = build()..emit(_active());

    // Simulate backend broadcasting "remote-u started sharing"
    captured('room1', 'remote-u', 'Remote User', true, true);

    final s = cubit.state as CallActive;
    expect(s.activeSharerUserId, 'remote-u');
    expect(s.activeSharerName, 'Remote User');
    expect(s.activeSharerHasAudio, true);

    await cubit.close();
  });

  // ── (f) endCall while locally sharing → setScreenShareEnabled(false) first ─

  test('(f) endCall while locally sharing calls setScreenShareEnabled(false) before socket endCall', () async {
    when(() => repo.setScreenShareEnabled(false))
        .thenAnswer((_) async => const Right(null));
    when(() => socket.emitScreenShareStateChanged(
          chatRoomId: any(named: 'chatRoomId'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
          isSharing: any(named: 'isSharing'),
          withAudio: any(named: 'withAudio'),
        )).thenReturn(null);
    when(() => socket.endCall()).thenReturn(null);

    final cubit = build()
      ..emit(_active(
        isLocallySharingScreen: true,
        activeSharerUserId: 'u1',
        activeSharerName: 'User1',
      ));

    await cubit.endCall();

    verifyInOrder([
      () => repo.setScreenShareEnabled(false),
      () => socket.endCall(),
    ]);
    expect(cubit.state, isA<CallIdle>());

    await cubit.close();
  });
}
