import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/status/data/models/status_audience_contact_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_model.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_audience_contact.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/data/repositories/status_repository_impl.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_privacy.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.dart';

void main() {
  late StatusRepositoryImpl repository;
  late MockStatusLocalDataSource mockLocalDataSource;
  late MockStatusRemoteDataSource mockRemoteDataSource;
  late MockAuthLocalDataSource mockAuthLocalDataSource;
  late MockSocketService mockSocketService;
  late MockChatLocalDataSource mockChatLocalDataSource;

  setUpAll(() {
    registerFallbackValue(
      StatusModel(
        id: 'fallback',
        authorName: 'a',
        authorAvatar: '',
        timestamp: DateTime(2026),
        expiresAt: DateTime(2026),
      ),
    );
    registerFallbackValue(
      Message(
        id: '',
        clientMessageId: '',
        roomId: '',
        senderId: '',
        senderPhone: '',
        senderName: '',
        text: '',
        timestamp: DateTime(2026),
        status: MessageStatus.pending,
        type: MessageType.text,
      ),
    );
  });

  StatusEntity buildDraft({
    StatusContentType contentType = StatusContentType.text,
    StatusPrivacy privacy = StatusPrivacy.public,
    List<String> audience = const [],
    String clientStatusId = 'client-1',
  }) {
    final now = DateTime(2026, 6, 10);
    return StatusEntity(
      id: clientStatusId,
      authorName: 'Author',
      authorAvatar: '',
      timestamp: now,
      expiresAt: now.add(const Duration(hours: 24)),
      isMine: true,
      contentType: contentType,
      textContent: contentType == StatusContentType.text ? 'hello' : null,
      mediaUrl: contentType == StatusContentType.text ? null : '/tmp/file.jpg',
      privacy: privacy,
      clientStatusId: clientStatusId,
      audience: audience,
    );
  }

  setUp(() {
    // UrlUtils.resolveMediaUrl reads AppConstants.apiBaseUrl, which falls
    // back to dotenv — initialize it with an empty env so the fallback
    // default URL is used instead of throwing NotInitializedError.
    dotenv.loadFromString(envString: '', isOptional: true);
    SharedPreferences.setMockInitialValues({});
    mockLocalDataSource = MockStatusLocalDataSource();
    mockRemoteDataSource = MockStatusRemoteDataSource();
    mockAuthLocalDataSource = MockAuthLocalDataSource();
    mockSocketService = MockSocketService();
    mockChatLocalDataSource = MockChatLocalDataSource();

    when(() => mockRemoteDataSource.onStatusUploaded)
        .thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
    when(() => mockSocketService.isConnectedNotifier).thenReturn(ValueNotifier<bool>(false));
    when(() => mockAuthLocalDataSource.getUserId()).thenAnswer((_) async => 'user-1');
    when(() => mockLocalDataSource.cacheStatus(any())).thenAnswer((_) async {});
    when(() => mockLocalDataSource.updateSyncStatus(
          any(),
          any(),
          newId: any(named: 'newId'),
          mediaUrl: any(named: 'mediaUrl'),
        )).thenAnswer((_) async {});

    repository = StatusRepositoryImpl(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      authLocalDataSource: mockAuthLocalDataSource,
      socketService: mockSocketService,
      chatLocalDataSource: mockChatLocalDataSource,
    );
  });

  group('uploadStatus', () {
    test('text status: caches optimistically and stays pending until socket ACK', () async {
      final draft = buildDraft();
      when(() => mockRemoteDataSource.uploadStatus(any())).thenAnswer((_) async => null);

      final result = await repository.uploadStatus(draft);

      expect(result, equals(const Right<Failure, void>(null)));
      verify(() => mockLocalDataSource.cacheStatus(any())).called(1);
      verifyNever(() => mockLocalDataSource.updateSyncStatus(
            any(),
            any(),
            newId: any(named: 'newId'),
            mediaUrl: any(named: 'mediaUrl'),
          ));
    });

    test('media status: marks synced with server id on successful REST ACK', () async {
      final draft = buildDraft(contentType: StatusContentType.image);
      when(() => mockRemoteDataSource.uploadStatus(any())).thenAnswer((_) async => {
            'id': 'server-123',
            'clientStatusId': 'client-1',
            'mediaUrl': '/status/media/server-123/file.jpg',
          });

      final result = await repository.uploadStatus(draft);

      expect(result, equals(const Right<Failure, void>(null)));
      verify(() => mockLocalDataSource.updateSyncStatus(
            'client-1',
            'synced',
            newId: 'server-123',
            mediaUrl: any(named: 'mediaUrl', that: contains('/status/media/server-123/file.jpg')),
          )).called(1);
    });

    test('no connectivity: leaves status pending for offline-queue replay', () async {
      final draft = buildDraft();
      when(() => mockRemoteDataSource.uploadStatus(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/status/upload'),
      ));

      final result = await repository.uploadStatus(draft);

      expect(result, equals(const Right<Failure, void>(null)));
      verifyNever(() => mockLocalDataSource.updateSyncStatus(any(), 'error', newId: any(named: 'newId')));
    });

    test('4xx rejection: marks status as error and surfaces ServerFailure', () async {
      final draft = buildDraft();
      when(() => mockRemoteDataSource.uploadStatus(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/status/upload'),
        response: Response(requestOptions: RequestOptions(path: '/status/upload'), statusCode: 400),
      ));

      final result = await repository.uploadStatus(draft);

      expect(result, isA<Left<Failure, void>>());
      verify(() => mockLocalDataSource.updateSyncStatus('client-1', 'error')).called(1);
    });
  });

  group('getDefaultAudience (T052)', () {
    const tContacts = [
      StatusAudienceContact(userId: 'u1', name: 'Alice', phoneNumber: '+1', avatarUrl: ''),
      StatusAudienceContact(userId: 'u2', name: 'Bob', phoneNumber: '+2', avatarUrl: ''),
    ];

    test('caches the fetched audience to SharedPreferences on success', () async {
      when(() => mockRemoteDataSource.getDefaultAudience()).thenAnswer((_) async => tContacts
          .map((c) => StatusAudienceContactModel(
                userId: c.userId,
                name: c.name,
                phoneNumber: c.phoneNumber,
                avatarUrl: c.avatarUrl,
              ))
          .toList());

      final result = await repository.getDefaultAudience();

      expect(result, isA<Right<Failure, List<StatusAudienceContact>>>());
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('status_default_audience');
      expect(cached, isNotNull);
      expect(cached, contains('u1'));
      expect(cached, contains('u2'));
    });

    test('falls back to cached audience when the remote call fails', () async {
      SharedPreferences.setMockInitialValues({
        'status_default_audience':
            '[{"userId":"u1","name":"Alice","phoneNumber":"+1","avatarUrl":""}]',
      });
      when(() => mockRemoteDataSource.getDefaultAudience()).thenThrow(Exception('offline'));

      final result = await repository.getDefaultAudience();

      result.fold(
        (failure) => fail('expected cached fallback, got failure: $failure'),
        (contacts) {
          expect(contacts, hasLength(1));
          expect(contacts.first.userId, 'u1');
        },
      );
    });

    test('returns ServerFailure when remote fails and no cache exists', () async {
      when(() => mockRemoteDataSource.getDefaultAudience()).thenThrow(Exception('offline'));

      final result = await repository.getDefaultAudience();

      expect(result, isA<Left<Failure, List<StatusAudienceContact>>>());
    });
  });

  group('reply (T047)', () {
    test('saves the returned chat message into local chat history', () async {
      final messageJson = {
        '_id': 'm1',
        'clientMessageId': 'c1',
        'chatRoomId': 'room1',
        'senderId': 'user-1',
        'content': 'hi',
        'createdAt': DateTime(2026, 6, 10).toIso8601String(),
        'status': 'sent',
        'messageType': 'text',
      };
      when(() => mockRemoteDataSource.reply(any(), any())).thenAnswer((_) async => messageJson);
      when(() => mockChatLocalDataSource.saveMessage(any())).thenAnswer((_) async {});

      final result = await repository.reply('status1', 'hi');

      expect(result, equals(const Right<Failure, void>(null)));
      verify(() => mockChatLocalDataSource.saveMessage(any())).called(1);
    });

    test('returns ServerFailure when the remote reply call fails', () async {
      when(() => mockRemoteDataSource.reply(any(), any())).thenThrow(Exception('boom'));

      final result = await repository.reply('status1', 'hi');

      expect(result, isA<Left<Failure, void>>());
    });
  });
}
