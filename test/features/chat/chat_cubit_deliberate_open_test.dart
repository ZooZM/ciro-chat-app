import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:ciro_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:ciro_chat_app/features/contacts/data/contacts_service.dart';

import '../auth/mocks.dart';

class MockChatLocalDataSourceForTest extends Mock implements ChatLocalDataSource {}
class MockChatRepository extends Mock implements ChatRepository {}
class MockContactsServiceForTest extends Mock implements ContactsService {}

void main() {
  late ChatCubit chatCubit;
  late MockSocketService mockSocketService;
  late MockChatLocalDataSourceForTest mockLocalDataSource;
  late MockChatRepository mockRepository;
  late MockContactsServiceForTest mockContactsService;
  late MockAuthLocalDataSource mockAuthLocalDataSource;

  setUp(() {
    mockSocketService = MockSocketService();
    mockLocalDataSource = MockChatLocalDataSourceForTest();
    mockRepository = MockChatRepository();
    mockContactsService = MockContactsServiceForTest();
    mockAuthLocalDataSource = MockAuthLocalDataSource();

    // Default mock behaviors
    when(() => mockLocalDataSource.getRoomMessages(any())).thenAnswer((_) async => []);
    when(() => mockLocalDataSource.watchRoomMessages(any())).thenAnswer((_) => Stream.empty());
    when(() => mockLocalDataSource.resetUnreadCount(any())).thenAnswer((_) async => {});
    when(() => mockLocalDataSource.closeRoomStream(any())).thenAnswer((_) async => {});
    when(() => mockLocalDataSource.saveMessage(any(), incrementUnread: any(named: 'incrementUnread'))).thenAnswer((_) async => {});
    when(() => mockLocalDataSource.updateMessageStatus(any(), any())).thenAnswer((_) async => {});

    chatCubit = ChatCubit(
      mockLocalDataSource,
      mockSocketService,
      mockAuthLocalDataSource,
      mockRepository,
      mockContactsService,
    );
  });

  tearDown(() {
    chatCubit.close();
  });

  group('ChatCubit Deliberate-Open Gate Tests', () {
    // T-DO-1: Fresh ChatCubit, openRoom sets flag and marks as read
    test('T-DO-1: openRoom() sets flag to true and triggers markRead', () async {
      // Setup: mock room with delivered message
      final testMessage = Message(
        id: 'msg-1',
        clientMessageId: 'client-1',
        roomId: 'R1',
        senderId: 'other-user',
        text: 'Hello',
        status: MessageStatus.delivered,
        timestamp: DateTime.now(),
      );

      when(() => mockLocalDataSource.getRoomMessages('R1'))
          .thenAnswer((_) async => [testMessage]);

      // Act: open the room
      chatCubit.openRoom('R1');
      await Future.delayed(Duration.zero); // Allow async operations to complete

      // Assert: markRead should be called (deliberate-open gate is true after openRoom)
      verify(() => mockSocketService.markRead(
        roomId: 'R1',
        messageIds: any(named: 'messageIds'),
      )).called(greaterThan(0));
    });

    // T-DO-2: closeRoom sets flag to false
    test('T-DO-2: closeRoom() clears flag and tears down room', () async {
      // Setup: open a room
      when(() => mockLocalDataSource.getRoomMessages('R1'))
          .thenAnswer((_) async => []);

      chatCubit.openRoom('R1');
      await Future.delayed(Duration.zero);

      // Act: close the room
      chatCubit.closeRoom();

      // Assert: data source should be instructed to close
      verify(() => mockLocalDataSource.closeRoomStream('R1')).called(1);
    });

    // T-DO-3: suspendDeliberateOpen clears flag but keeps activeRoomId
    test('T-DO-3: suspendDeliberateOpen() clears flag without closing room', () async {
      // Setup: open a room
      when(() => mockLocalDataSource.getRoomMessages('R1'))
          .thenAnswer((_) async => []);

      chatCubit.openRoom('R1');
      await Future.delayed(Duration.zero);

      // Act: suspend (don't close)
      chatCubit.suspendDeliberateOpen();

      // Assert: closeRoomStream should NOT be called (room stays open)
      verifyNever(() => mockLocalDataSource.closeRoomStream(any()));
    });

    // T-DO-4: Auto-mark works when flag is true
    test('T-DO-4: markRoomMessagesRead() emits markRead when flag is true', () async {
      // Setup: open a room (flag is true)
      when(() => mockLocalDataSource.getRoomMessages('R1'))
          .thenAnswer((_) async => []);

      chatCubit.openRoom('R1');
      await Future.delayed(Duration.zero);
      clearInteractions(mockSocketService);

      // Setup: messages to mark
      final testMessage = Message(
        id: 'msg-1',
        clientMessageId: 'client-1',
        roomId: 'R1',
        senderId: 'other-user',
        text: 'Hello',
        status: MessageStatus.delivered,
        timestamp: DateTime.now(),
      );

      when(() => mockLocalDataSource.getRoomMessages('R1'))
          .thenAnswer((_) async => [testMessage]);

      // Act: mark messages as read (flag is true)
      await chatCubit.markRoomMessagesRead('R1');

      // Assert: markRead should be called
      verify(() => mockSocketService.markRead(
        roomId: 'R1',
        messageIds: any(named: 'messageIds'),
      )).called(1);
    });

    // T-DO-5: Auto-mark suppressed when flag is false
    test('T-DO-5: markRoomMessagesRead() is suppressed when flag is false', () async {
      // Setup: open then suspend
      when(() => mockLocalDataSource.getRoomMessages('R1'))
          .thenAnswer((_) async => []);

      chatCubit.openRoom('R1');
      await Future.delayed(Duration.zero);
      chatCubit.suspendDeliberateOpen();
      clearInteractions(mockSocketService);

      // Setup: messages to mark
      final testMessage = Message(
        id: 'msg-1',
        clientMessageId: 'client-1',
        roomId: 'R1',
        senderId: 'other-user',
        text: 'Hello',
        status: MessageStatus.delivered,
        timestamp: DateTime.now(),
      );

      when(() => mockLocalDataSource.getRoomMessages('R1'))
          .thenAnswer((_) async => [testMessage]);

      // Act: try to mark messages as read (flag is false)
      await chatCubit.markRoomMessagesRead('R1');

      // Assert: markRead should NOT be called (suppressed by guard)
      verifyNever(() => mockSocketService.markRead(
        roomId: 'R1',
        messageIds: any(named: 'messageIds'),
      ));
    });

    // T-DO-6: Re-opening restores flag and re-emits read
    test('T-DO-6: Re-opening room restores flag and calls markRead again', () async {
      // Setup: open, suspend
      when(() => mockLocalDataSource.getRoomMessages('R1'))
          .thenAnswer((_) async => []);

      chatCubit.openRoom('R1');
      await Future.delayed(Duration.zero);
      chatCubit.suspendDeliberateOpen();
      clearInteractions(mockSocketService);

      // Act: re-open the room
      chatCubit.openRoom('R1');
      await Future.delayed(Duration.zero);

      // Assert: markRead should be called again (flag restored to true)
      verify(() => mockSocketService.markRead(
        roomId: 'R1',
        messageIds: any(named: 'messageIds'),
      )).called(greaterThan(0));
    });
  });
}
