import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ciro_chat_app/features/video_call/domain/repositories/video_call_repository.dart';
import 'package:ciro_chat_app/features/video_call/presentation/bloc/video_call_cubit.dart';

class MockVideoCallRepository extends Mock implements VideoCallRepository {}
class MockRoom extends Mock implements Room {}

void main() {
  late VideoCallCubit cubit;
  late MockVideoCallRepository mockRepository;
  late MockRoom mockRoom;

  setUp(() {
    mockRepository = MockVideoCallRepository();
    mockRoom = MockRoom();
    cubit = VideoCallCubit(mockRepository);
  });

  tearDown(() {
    cubit.close();
  });

  const tWsUrl = 'ws://localhost:7880';
  const tToken = 'token';

  group('VideoCallCubit', () {
    test('initial state should be VideoCallInitial', () {
      expect(cubit.state, const VideoCallInitial());
    });

    test(
      'emits [VideoCallConnecting, VideoCallConnected] when joinRoom is successful',
      () async {
        // arrange
        when(() => mockRepository.connect(any(), any()))
            .thenAnswer((_) async => mockRoom);
        
        final expectedStates = [
          const VideoCallConnecting(),
          VideoCallConnected(mockRoom),
        ];
        
        // assert later
        expectLater(cubit.stream, emitsInOrder(expectedStates));
        
        // act
        await cubit.joinRoom(tWsUrl, tToken);
        
        // verify
        verify(() => mockRepository.connect(tWsUrl, tToken)).called(1);
      },
    );

    test(
      'emits [VideoCallConnecting, VideoCallError] when joinRoom fails',
      () async {
        // arrange
        when(() => mockRepository.connect(any(), any()))
            .thenThrow(Exception('Connection failed'));
        
        final expectedStates = [
          const VideoCallConnecting(),
          const VideoCallError('Exception: Connection failed'),
        ];
        
        // assert later
        expectLater(cubit.stream, emitsInOrder(expectedStates));
        
        // act
        await cubit.joinRoom(tWsUrl, tToken);
      },
    );

    test(
      'emits [VideoCallDisconnected] when leaveRoom is called',
      () async {
        // arrange
        when(() => mockRepository.disconnect()).thenAnswer((_) async => {});
        
        final expectedStates = [
          const VideoCallDisconnected(),
        ];
        
        // assert later
        expectLater(cubit.stream, emitsInOrder(expectedStates));
        
        // act
        await cubit.leaveRoom();
        
        // verify
        verify(() => mockRepository.disconnect()).called(1);
      },
    );

    test('muteMic calls repository toggleMic', () async {
      when(() => mockRepository.toggleMic(any())).thenAnswer((_) async => {});
      
      await cubit.muteMic(true);
      
      verify(() => mockRepository.toggleMic(false)).called(1);
    });

    test('disableCamera calls repository toggleCamera', () async {
      when(() => mockRepository.toggleCamera(any())).thenAnswer((_) async => {});
      
      await cubit.disableCamera(true);
      
      verify(() => mockRepository.toggleCamera(false)).called(1);
    });
  });
}
