import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
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

/// T019 — outcome mapping for each terminal path writes the correct
/// [CallHistoryRecord] (data-model.md outcome table).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  void Function(Map<String, dynamic>)? incomingCallCb;
  void Function(Map<String, dynamic>)? callAcceptedCb;
  void Function(Map<String, dynamic>)? callRejectedCb;
  void Function(Map<String, dynamic>)? incomingGroupCallCb;

  setUp(() {
    socket = MockSocketService();
    repo = MockVideoCallRepository();
    callKit = MockCallKitService();
    historyRepo = MockCallHistoryRepository();

    when(() => socket.onIncomingCall = any())
        .thenAnswer((i) => incomingCallCb = i.positionalArguments[0] as void Function(Map<String, dynamic>));
    when(() => socket.onCallAccepted = any())
        .thenAnswer((i) => callAcceptedCb = i.positionalArguments[0] as void Function(Map<String, dynamic>));
    when(() => socket.onCallRejected = any())
        .thenAnswer((i) => callRejectedCb = i.positionalArguments[0] as void Function(Map<String, dynamic>));
    when(() => socket.onCallHandledElsewhere = any()).thenReturn(null);
    when(() => socket.onIncomingGroupCall = any())
        .thenAnswer((i) => incomingGroupCallCb = i.positionalArguments[0] as void Function(Map<String, dynamic>));
    when(() => socket.onGroupCallParticipantJoined = any()).thenReturn(null);
    when(() => socket.onGroupCallParticipantLeft = any()).thenReturn(null);
    when(() => socket.onGroupCallRecordingStateChanged = any()).thenReturn(null);
    when(() => socket.onScreenShareRejected = any()).thenReturn(null);
    when(() => socket.onScreenShareStateChanged = any()).thenReturn(null);
    when(() => repo.onLocalScreenShareEndedExternally = any()).thenReturn(null);

    when(() => socket.requestCall(targetUserId: any(named: 'targetUserId'), isVideo: any(named: 'isVideo')))
        .thenReturn(null);
    when(() => socket.requestGroupCall(chatRoomId: any(named: 'chatRoomId'), isVideo: any(named: 'isVideo')))
        .thenReturn(null);
    when(() => socket.acceptCall(callerId: any(named: 'callerId'))).thenReturn(null);
    when(() => socket.rejectCall(callerId: any(named: 'callerId'))).thenReturn(null);
    when(() => socket.declineGroupCall(chatRoomId: any(named: 'chatRoomId'))).thenReturn(null);
    when(() => socket.endCall()).thenReturn(null);

    when(() => callKit.actions).thenAnswer((_) => const Stream<CallKitAction>.empty());
    when(() => callKit.showIncoming(
          callId: any(named: 'callId'),
          callerName: any(named: 'callerName'),
          callerAvatarUrl: any(named: 'callerAvatarUrl'),
          isVideo: any(named: 'isVideo'),
        )).thenAnswer((_) async {});
    when(() => callKit.startOutgoing(
          callId: any(named: 'callId'),
          calleeName: any(named: 'calleeName'),
          isVideo: any(named: 'isVideo'),
        )).thenAnswer((_) async {});
    when(() => callKit.setConnected(any())).thenAnswer((_) async {});
    when(() => callKit.endCall(any())).thenAnswer((_) async {});
    when(() => callKit.endAllCalls()).thenAnswer((_) async {});

    when(() => historyRepo.add(any())).thenAnswer((_) async => const Right(unit));
  });

  CallCubit build() => CallCubit(socket, repo, callKit, historyRepo);

  test('outgoing call answered then ended → outcome answered, direction outgoing', () async {
    final cubit = build();
    cubit.initiateCall(targetUserId: 'callee1', targetName: 'Bob', isVideo: false);

    callAcceptedCb!({'livekitToken': 'tok', 'livekitUrl': 'wss://lk'});
    await cubit.endCall();

    final captured = verify(() => historyRepo.add(captureAny())).captured.single as CallHistoryRecord;
    expect(captured.direction, CallDirection.outgoing);
    expect(captured.outcome, CallOutcome.answered);
    expect(captured.contactUserId, 'callee1');
    expect(captured.isGroup, false);
    await cubit.close();
  });

  test('outgoing call rejected by remote → outcome declined', () async {
    final cubit = build();
    cubit.initiateCall(targetUserId: 'callee1', targetName: 'Bob', isVideo: false);

    callRejectedCb!({});

    final captured = verify(() => historyRepo.add(captureAny())).captured.single as CallHistoryRecord;
    expect(captured.direction, CallDirection.outgoing);
    expect(captured.outcome, CallOutcome.declined);
    await cubit.close();
  });

  test('incoming call answered then ended → outcome answered, direction incoming', () async {
    final cubit = build();
    incomingCallCb!({
      'callerId': 'caller1',
      'callerName': 'Alice',
      'isVideo': false,
    });
    cubit.acceptCall();
    callAcceptedCb!({'livekitToken': 'tok', 'livekitUrl': 'wss://lk'});
    await cubit.endCall();

    final captured = verify(() => historyRepo.add(captureAny())).captured.single as CallHistoryRecord;
    expect(captured.direction, CallDirection.incoming);
    expect(captured.outcome, CallOutcome.answered);
    expect(captured.contactUserId, 'caller1');
    await cubit.close();
  });

  test('incoming call declined locally → outcome declined', () async {
    final cubit = build();
    incomingCallCb!({'callerId': 'caller1', 'callerName': 'Alice', 'isVideo': false});
    cubit.rejectCall();

    final captured = verify(() => historyRepo.add(captureAny())).captured.single as CallHistoryRecord;
    expect(captured.direction, CallDirection.incoming);
    expect(captured.outcome, CallOutcome.declined);
    await cubit.close();
  });

  test('incoming call timed out natively → outcome missed', () async {
    final cubit = build();
    incomingCallCb!({'callerId': 'caller1', 'callerName': 'Alice', 'isVideo': false});

    // Simulate the native CallKit timeout action directly (bypasses the empty
    // actions stream stub — exercises the same code path as _bindCallKitActions).
    await cubit.endCall(); // never connected → missed

    final captured = verify(() => historyRepo.add(captureAny())).captured.single as CallHistoryRecord;
    expect(captured.outcome, CallOutcome.missed);
    await cubit.close();
  });

  test('group call writes a history row marked isGroup, but never touches CallKit (R2)', () async {
    final cubit = build();
    incomingGroupCallCb!({
      'callerUserId': 'caller1',
      'callerName': 'Alice',
      'isVideo': false,
      'chatRoomId': 'room1',
      'groupName': 'Team',
    });
    cubit.declineGroupCall();

    final captured = verify(() => historyRepo.add(captureAny())).captured.single as CallHistoryRecord;
    expect(captured.isGroup, true);
    expect(captured.outcome, CallOutcome.declined);

    verifyNever(() => callKit.showIncoming(
          callId: any(named: 'callId'),
          callerName: any(named: 'callerName'),
          callerAvatarUrl: any(named: 'callerAvatarUrl'),
          isVideo: any(named: 'isVideo'),
        ));
    verifyNever(() => callKit.startOutgoing(
          callId: any(named: 'callId'),
          calleeName: any(named: 'calleeName'),
          isVideo: any(named: 'isVideo'),
        ));
    await cubit.close();
  });
}
