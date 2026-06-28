import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';

import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/domain/repositories/chat_repository.dart'; // Use repository
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/contacts/data/contacts_service.dart';
import 'package:ciro_chat_app/features/chat/domain/value_objects/voice_waveform.dart';

part 'chat_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MessageDraft — internal DTO used to decouple sendLocalMessage from raw text.
// ─────────────────────────────────────────────────────────────────────────────

class MessageDraft {
  final String text;
  final MessageType type;
  final String? fileUrl;
  final Map<String, dynamic>? metadata;

  const MessageDraft({
    required this.text,
    this.type = MessageType.text,
    this.fileUrl,
    this.metadata,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

@injectable
class ChatCubit extends Cubit<ChatState> {
  final ChatLocalDataSource _localDataSource;
  final SocketService _socketService;
  final AuthLocalDataSource _authLocalDataSource;
  final ChatRepository _chatRepository; // Use repository
  final ContactsService _contactsService;

  final _imagePicker = ImagePicker();

  StreamSubscription<List<Message>>? _roomStreamSub;
  String? _activeRoomId;
  bool _isDeliberatelyOpen = false;
  final Map<String, VoiceWaveformGeometry> _voiceWaveformCache = {};
  ChatSession? _pendingContact;
  String currentUserId = '';
  String currentUserPhone = '';
  bool isHydrationComplete = false;
  final _uuid = const Uuid();
  // Block state is owned by ChatState (ChatBlockUpdated / ChatRoomActive.blockedUserIds).
  // Do NOT add mutable block fields here — emit() is the single source of truth.

  // FR-018: Pagination state for infinite scroll.
  static const int _pageSize = 30;
  int _messageOffset = 0;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  final _typingUsersController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get typingUsersStream => _typingUsersController.stream;
  final Set<String> _currentTypingUsers = {};

  // Per-room typing state to support chat list indicators
  final Map<String, Set<String>> _typingUsersByRoom = {};
  final _roomTypingController =
      StreamController<Map<String, Set<String>>>.broadcast();
  Stream<Map<String, Set<String>>> get allTypingUsersStream =>
      _roomTypingController.stream;

  // US2: Client-side typing debouncing and auto-reset.
  Timer? _typingTimer;
  final Map<String, Timer> _incomingTypingTimers = {};

  final ValueNotifier<List<Message>> searchResults = ValueNotifier([]);

  // FR-038: rooms with an active group call → value is isVideo for that call
  final ValueNotifier<Map<String, bool>> activeCallRoomIds = ValueNotifier({});

  /// Returns the current typing users for a given room.
  /// Used by [TypingIndicatorWidget] on first build before any [TypingUpdate]
  /// state has been emitted.
  Set<String> typingUsersForRoom(String roomId) =>
      Set.unmodifiable(_typingUsersByRoom[roomId] ?? {});

  ChatCubit(
    this._localDataSource,
    this._socketService,
    this._authLocalDataSource,
    this._chatRepository, // Use repository
    this._contactsService,
  ) : super(ChatInitial()) {
    _initServices();
  }

  // ── Public streams ──────────────────────────────────────────────────────────

  Stream<List<ChatSession>> get recentChatsStream =>
      _localDataSource.watchRecentChats();

  Stream<List<ChatSession>> get watchLocalContacts =>
      _localDataSource.watchContacts();

  // ── Initialisation ──────────────────────────────────────────────────────────

  Future<void> _onUserStatusChanged(String userId, bool isOnline) async {
    await _localDataSource.updateUserOnlineStatus(userId, isOnline);
  }

  Future<void> _initServices() async {
    currentUserId = await _authLocalDataSource.getUserId() ?? '';
    currentUserPhone = await _authLocalDataSource.getUserPhone() ?? '';
    await _localDataSource.initDB();

    _socketService.addUserStatusListener(_onUserStatusChanged);
    // Fetch block list — emit into state; no mutable field.
    final blockListResult = await _chatRepository.getBlockList();
    blockListResult.fold(
      (f) => debugPrint('[ChatCubit] Failed to fetch block list: ${f.message}'),
      (list) {
        if (list.isNotEmpty) emit(ChatBlockUpdated(list));
      },
    );

    // ── Sender-side status promotions ─────────────────────────────────────────

    _socketService.onMessageSent = (clientMessageId, createdAt) {
      handleMessageStatusUpdate(
        clientMessageId,
        MessageStatus.sent,
        createdAt: createdAt,
      );
    };

    _socketService.onMessageDelivered = (clientMessageIds) {
      for (final id in clientMessageIds) {
        handleMessageStatusUpdate(id, MessageStatus.delivered);
      }
    };

    _socketService.onMessageRead = (
      clientMessageIds, {
      int? readByCount,
      int? participantCount,
    }) {
      // INV-2: For GROUP rooms, only promote to 'read' when all members have read.
      // readByCount and participantCount are present only for GROUP rooms.
      // For private chats (no counts), promote immediately (existing behaviour).
      final shouldPromote = readByCount == null ||
          participantCount == null ||
          readByCount >= participantCount;
      if (shouldPromote) {
        for (final id in clientMessageIds) {
          handleMessageStatusUpdate(id, MessageStatus.read);
        }
      }
    };

    _socketService.addReconnectListener(() {
      debugPrint(
        '[ChatCubit] Socket reconnected — triggering REST status sync + pending replay + missed-message recovery',
      );
      syncStatusesFromRest().ignore();
      syncPendingMessages().ignore();
      _syncMissedMessages().ignore();
    });

    // FR-022: Recipient receives a "delete for everyone" notification.
    _socketService.onMessageDeleted = (clientMessageId) {
      _handleDeletedMessage(clientMessageId).ignore();
    };

    _socketService.onChatRoomUpdated = _onChatRoomUpdated;
    _socketService.onNewChatRoom = _onNewChatRoom;

    // FR-038: track active group calls so JoinCallAppBarAction can show/hide
    _socketService.onGroupCallActive = (data) {
      final roomId = data['chatRoomId']?.toString() ?? '';
      if (roomId.isEmpty) return;
      final isVideo = data['isVideo'] == true;
      activeCallRoomIds.value = {...activeCallRoomIds.value, roomId: isVideo};
    };
    _socketService.onGroupCallEnded = (data) {
      final roomId = data['chatRoomId']?.toString() ?? '';
      if (roomId.isEmpty) return;
      final updated = Map<String, bool>.from(activeCallRoomIds.value)..remove(roomId);
      activeCallRoomIds.value = updated;
    };

    _socketService.onUserTyping = (roomId, userId, phoneNumber, isTyping) {
      final identifier = phoneNumber.isNotEmpty ? phoneNumber : userId;
      if (identifier.isEmpty) return;

      // 1. Update per-room map
      final roomTypers = _typingUsersByRoom[roomId] ?? {};
      if (isTyping) {
        roomTypers.add(identifier);
      } else {
        roomTypers.remove(identifier);
      }
      _typingUsersByRoom[roomId] = roomTypers;
      _roomTypingController.add(Map.from(_typingUsersByRoom));

      // 2. Update active room stream if matches
      if (roomId == _activeRoomId) {
        if (isTyping) {
          _currentTypingUsers.add(identifier);
        } else {
          _currentTypingUsers.remove(identifier);
        }
        _typingUsersController.add(Set.from(_currentTypingUsers));

        // 3. Emit TypingUpdate so BlocBuilder widgets can react WITHOUT
        //    rebuilding the heavy message list (use buildWhen to filter).
        emit(
          TypingUpdate(
            roomId: roomId,
            typingUsers: Set.from(_currentTypingUsers),
          ),
        );
      }
    };

    // ── Recipient-side: incoming message ──────────────────────────────────────

    _socketService.onNewMessage = (data) async {
      final clientMsgId = data['clientMessageId'] ?? _uuid.v4();
      final mongoId = data['_id'] ?? data['id'] ?? _uuid.v4();
      final incomingRoomId = data['chatRoomId'] as String? ?? '';

      // FR-031: If the user has left this room (no local record), ignore
      // any further socket traffic for it.
      //
      // For a brand-new room, the 'newChatRoom' event (which inserts the room
      // locally via _onNewChatRoom) and this 'newMessage' event arrive back
      // to back from the server. _onNewChatRoom is fire-and-forget, so its
      // local save can still be in flight when this handler runs — without a
      // short retry window the very first message in a new room gets
      // mistaken for traffic on a left room and silently dropped.
      if (incomingRoomId.isNotEmpty) {
        ChatSession? knownRoom = await _localDataSource.getRoomById(
          incomingRoomId,
        );
        for (var attempt = 0; knownRoom == null && attempt < 5; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          knownRoom = await _localDataSource.getRoomById(incomingRoomId);
        }
        if (knownRoom == null) {
          debugPrint('[ChatCubit] FR-031: ignoring message for unknown/left room $incomingRoomId');
          return;
        }
      }

      // FR-019: Dedup check — skip if this clientMessageId is already in
      // the current in-memory message list (prevents duplicates on reconnect).
      if (state is ChatRoomActive) {
        final msgs = (state as ChatRoomActive).messages;
        if (msgs.any((m) => m.clientMessageId == clientMsgId)) {
          debugPrint(
            '[ChatCubit] Dedup: $clientMsgId already in state, skipping.',
          );
          return;
        }
      }

      final rawType = data['type'] as String? ?? data['messageType'] as String?;
      final incomingFileUrl = data['fileUrl'] as String?;

      // Smart inference if backend stripped the type string
      MessageType inferredType = messageTypeFromString(rawType);
      if (inferredType == MessageType.text &&
          incomingFileUrl != null &&
          incomingFileUrl.isNotEmpty) {
        if (incomingFileUrl.contains('.m4a') ||
            incomingFileUrl.contains('.mp3')) {
          inferredType = MessageType.voiceNote;
        } else if (incomingFileUrl.contains('.jpg') ||
            incomingFileUrl.contains('.png') ||
            incomingFileUrl.contains('.jpeg')) {
          inferredType = MessageType.image;
        } else {
          inferredType = MessageType.file;
        }
      }

      // Backend now populates senderId with { _id, name, phoneNumber } so the
      // live socket payload matches the REST shape. Handle both — fall back to
      // a bare string for older deployments.
      final rawSender = data['senderId'];
      final String senderId;
      final String senderPhone;
      final String senderName;
      if (rawSender is Map) {
        senderId = (rawSender['_id'] ?? '').toString();
        senderPhone = (rawSender['phoneNumber'] ?? data['senderPhone'] ?? '').toString();
        senderName = (rawSender['name'] ?? '').toString();
      } else {
        senderId = (rawSender ?? '').toString();
        senderPhone = (data['senderPhone'] ?? '').toString();
        senderName = (data['senderName'] ?? '').toString();
      }

      final incoming = Message(
        id: mongoId,
        clientMessageId: clientMsgId,
        roomId: data['chatRoomId'] ?? 'unknown',
        senderId: senderId,
        senderPhone: senderPhone,
        senderName: senderName,
        text: data['content'] ?? '',
        timestamp: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
        status: MessageStatus.delivered,
        type: inferredType,
        fileUrl: incomingFileUrl,
        metadata: data['metadata'] is Map
            ? Map<String, dynamic>.from(data['metadata'] as Map)
            : null,
      );

      final isActiveRoom = incoming.roomId == _activeRoomId;
      await _localDataSource.saveMessage(
        incoming,
        incrementUnread: !isActiveRoom,
      );

      _socketService.markDelivered(
        roomId: incoming.roomId,
        messageIds: [incoming.clientMessageId],
      );

      if (isActiveRoom && _isDeliberatelyOpen) {
        _socketService.markRead(
          roomId: incoming.roomId,
          messageIds: [incoming.clientMessageId],
        );
        await _localDataSource.updateMessageStatus(
          incoming.clientMessageId,
          MessageStatus.read,
        );
      } else if (isActiveRoom && !_isDeliberatelyOpen) {
        debugPrint('[ChatCubit] Suppressed auto-markRead for ${incoming.clientMessageId} in ${incoming.roomId} (deliberateOpen=false)');
      }
    };

    // Cold-boot: REST sync + pending replay after socket settles.
    Future.delayed(const Duration(seconds: 1), () {
      syncStatusesFromRest().ignore();
      syncPendingMessages().ignore();
    });
  }

  // ── Room lifecycle ──────────────────────────────────────────────────────────

  void openRoom(
    String roomId, {
    ChatSession? contact,
    ChatSession? room,
  }) async {
    // FR-018: Reset pagination state on room open.
    _messageOffset = 0;
    _hasMoreMessages = true;
    _isLoadingMore = false;

    if (roomId.isEmpty) {
      _pendingContact = contact;
      _activeRoomId = null;
      emit(const ChatRoomActive('', []));
      return;
    }

    if (_activeRoomId == roomId) return;

    _pendingContact = null;
    _activeRoomId = roomId;
    _isDeliberatelyOpen = true;
    _roomStreamSub?.cancel();
    _localDataSource.resetUnreadCount(roomId);

    // ── 1. Local-First: Load from SQLite immediately ──────────────────────────
    final localMessages = await _localDataSource.getRoomMessages(roomId);
    if (localMessages.isNotEmpty) {
      emit(ChatRoomActive(roomId, localMessages));
    } else {
      // Only show spinner if we have absolutely nothing locally.
      emit(ChatLoading());
    }

    // ── 2. Real-time Subscription ─────────────────────────────────────────────
    _roomStreamSub = _localDataSource.watchRoomMessages(roomId).listen((
      messages,
    ) {
      if (_activeRoomId == roomId) {
        emit(ChatRoomActive(roomId, messages));
      }
    }, onError: (e) => emit(ChatError(e.toString())));

    // ── 3. Background Sync ────────────────────────────────────────────────────
    // Compare local tip with server state (if provided) or just fetch.
    bool needsSync = true;
    if (room != null &&
        room.lastMessageId.isNotEmpty &&
        localMessages.isNotEmpty) {
      // Find the ID of the newest message in our list.
      // (getRoomMessages returns them reversed, so first is newest)
      final localLastMsgId = localMessages.first.id;
      if (localLastMsgId == room.lastMessageId) {
        needsSync = false;
        debugPrint(
          '[ChatCubit] Room $roomId is already up-to-date (tip matches)',
        );
      }
    }

    if (needsSync) {
      debugPrint('[ChatCubit] Room $roomId background sync started');
      _chatRepository
          .fetchRoomMessages(roomId)
          .then((res) {
            res.fold(
              (failure) =>
                  debugPrint('[ChatCubit] Background sync failed: $failure'),
              (newMsgs) async {
                if (newMsgs.isEmpty) return;
                for (final msg in newMsgs.reversed) {
                  await _localDataSource.saveMessage(
                    msg,
                    incrementUnread: false,
                  );
                }
                debugPrint('[ChatCubit] Background sync complete for $roomId');
              },
            );
          })
          .catchError((e) {
            debugPrint('[ChatCubit] Background sync error: $e');
          });
    }

    await markRoomMessagesRead(roomId);
  }

  // ── FR-018: Infinite scroll pagination ─────────────────────────────────────

  /// Loads the next page of older messages and prepends them to the state.
  Future<void> loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    final roomId = _activeRoomId;
    if (roomId == null || roomId.isEmpty) return;
    if (state is! ChatRoomActive) return;

    _isLoadingMore = true;
    final activeState = state as ChatRoomActive;
    emit(activeState.copyWith(isLoadingMore: true));

    _messageOffset += _pageSize;
    final olderMessages = await _localDataSource.getRoomMessages(
      roomId,
      limit: _pageSize,
      offset: _messageOffset,
    );

    _isLoadingMore = false;
    if (olderMessages.isEmpty || olderMessages.length < _pageSize) {
      _hasMoreMessages = false;
    }

    if (state is ChatRoomActive) {
      final currentState = state as ChatRoomActive;
      // Prepend older messages (they come oldest-first from the reversed query).
      final merged = [...olderMessages, ...currentState.messages];
      // T009 — BN-03: record expanded window so _dispatchUpdateForRoom never
      // narrows the list back to 30 when a new message or status update arrives.
      _localDataSource.setRoomDisplayLimit(roomId, merged.length);
      emit(
        currentState.copyWith(
          messages: merged,
          isLoadingMore: false,
          hasMoreMessages: _hasMoreMessages,
        ),
      );
    }
  }

  void closeRoom() {
    if (_activeRoomId != null) {
      _localDataSource.closeRoomStream(_activeRoomId!);
      _roomStreamSub?.cancel();
      _activeRoomId = null;
    }
    _isDeliberatelyOpen = false;
    _pendingContact = null;
    _currentTypingUsers.clear();
    _typingUsersController.add({});
    _voiceWaveformCache.clear();
  }

  /// Clears the deliberate-open flag without tearing down the active room.
  /// Called from main.dart's lifecycle observer on paused / inactive /
  /// detached / hidden. Idempotent.
  void suspendDeliberateOpen() {
    _isDeliberatelyOpen = false;
  }

  Future<void> markRoomMessagesRead(String roomId) async {
    if (!_isDeliberatelyOpen) {
      debugPrint('[ChatCubit] Suppressed markRoomMessagesRead for $roomId (deliberateOpen=false)');
      return;
    }
    final messages = await _localDataSource.getRoomMessages(roomId);
    final idsToMark = <String>[];
    for (final msg in messages) {
      if (msg.senderId != currentUserId &&
          (msg.status == MessageStatus.delivered ||
              msg.status == MessageStatus.sent)) {
        idsToMark.add(msg.clientMessageId);
        await _localDataSource.updateMessageStatus(msg.id, MessageStatus.read);
      }
    }
    if (idsToMark.isNotEmpty) {
      _socketService.markRead(roomId: roomId, messageIds: idsToMark);
    }
    debugPrint(
      '[ChatCubit] Marked ${idsToMark.length} messages as read in $roomId',
    );
  }

  void notifyTyping({required bool isTyping}) {
    if (_activeRoomId == null) return;

    if (isTyping) {
      // 1. Debouncing: Only emit if we weren't already typing.
      final wasTyping = _typingTimer?.isActive ?? false;
      if (!wasTyping) {
        _socketService.emitTyping(_activeRoomId!, true);
      }

      // 2. (Re)start the 3-second auto-reset timer.
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        notifyTyping(isTyping: false);
      });
    } else {
      // 3. Explicit stop: Cancel timer and emit stop event.
      _typingTimer?.cancel();
      _typingTimer = null;
      _socketService.emitTyping(_activeRoomId!, false);
    }
  }

  /// Returns the saved contact name for [phoneNumber] if it exists in the
  /// local contacts table; otherwise returns an empty string so callers can
  /// fall back to a server-provided display name + phone format.
  Future<String> getLocalContactName(String phoneNumber) async {
    if (phoneNumber.isEmpty) return '';
    final contacts = await _localDataSource.watchContacts().first;
    for (final contact in contacts) {
      if (contact.phoneNumber == phoneNumber) {
        return contact.name;
      }
    }
    return '';
  }

  // ── JIT room guard (shared by all send methods) ─────────────────────────────

  /// Ensures a real backend room exists before any message can be sent.
  /// No-ops if [_activeRoomId] is already set.
  /// Returns false and emits [ChatError] if JIT creation fails.
  Future<bool> _ensureRoom(ChatSession? pendingContact) async {
    if (_activeRoomId != null) return true;
    if (pendingContact == null) {
      debugPrint(
        '[ChatCubit] sendMessage: no active room and no pending contact',
      );
      return false;
    }

    final targetUserId = pendingContact.contactUserId;
    if (targetUserId.isEmpty) {
      emit(const ChatError('Cannot create room: missing target user ID'));
      return false;
    }

    final result = await _chatRepository.createPrivateChatRoom(targetUserId);
    return result.fold(
      (failure) {
        debugPrint('Error creating private room: $failure');
        emit(ChatError(failure.message));
        return false;
      },
      (roomId) async {
        _activeRoomId = roomId;
        _pendingContact = null;

        _socketService.joinRoom(roomId);
        // FR-021: No artificial delay — socket join is synchronous registration.

        _localDataSource.resetUnreadCount(roomId);
        _roomStreamSub?.cancel();
        _roomStreamSub = _localDataSource
            .watchRoomMessages(roomId)
            .listen(
              (messages) => emit(ChatRoomActive(roomId, messages)),
              onError: (e) => emit(ChatError(e.toString())),
            );

        debugPrint('[ChatCubit] JIT room created: $roomId');
        return true;
      },
    );
  }

  // ── sendLocalMessage ────────────────────────────────────────────────────────

  /// Core send method. Accepts a [MessageDraft] for all message types.
  /// For text messages call with [MessageDraft(text: '…')].
  ///
  /// The [draft.fileUrl] and [draft.metadata] are already resolved by the
  /// specialized send methods BEFORE calling here (post-upload).
  Future<void> sendLocalMessage(MessageDraft draft) async {
    final pendingContact = _pendingContact;

    final roomCreated = await _ensureRoom(pendingContact);
    if (!roomCreated) return;

    final roomId = _activeRoomId!;
    final msgId = _uuid.v4();

    final newMsg = Message(
      id: msgId,
      clientMessageId: msgId,
      roomId: roomId,
      senderId: currentUserId.isNotEmpty ? currentUserId : 'me',
      text: draft.text,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      type: draft.type,
      fileUrl: draft.fileUrl,
      metadata: draft.metadata,
    );

    await _localDataSource.saveMessage(
      newMsg,
      roomName: pendingContact?.name ?? '',
      roomAvatarUrl: pendingContact?.avatarUrl ?? '',
      roomPhoneNumber: pendingContact?.phoneNumber ?? '',
    );

    _socketService.sendMessage(
      roomId: roomId,
      messageId: msgId,
      text: draft.text,
      type: messageTypeToString(draft.type),
      fileUrl: draft.fileUrl,
      metadata: draft.metadata,
    );
  }

  // ── sendCameraMessage ───────────────────────────────────────────────────────

  /// Opens the camera, uploads the captured image, then sends it.
  Future<void> sendCameraMessage(BuildContext context) async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;

    final pendingContact = _pendingContact;
    final roomCreated = await _ensureRoom(pendingContact);
    if (!roomCreated) return;

    final roomId = _activeRoomId!;
    final msgId = _uuid.v4();

    final optimistic = Message(
      id: msgId,
      clientMessageId: msgId,
      roomId: roomId,
      senderId: currentUserId.isNotEmpty ? currentUserId : 'me',
      text: '📷 Uploading…',
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      type: MessageType.image,
      metadata: {'localPath': picked.path},
    );
    await _localDataSource.saveMessage(
      optimistic,
      roomName: pendingContact?.name ?? '',
      roomAvatarUrl: pendingContact?.avatarUrl ?? '',
      roomPhoneNumber: pendingContact?.phoneNumber ?? '',
    );

    try {
      final uploadResult = await _chatRepository.uploadFile(File(picked.path));
      await uploadResult.fold(
        (failure) async {
          await _localDataSource.updateMessageStatus(
            msgId,
            MessageStatus.error,
          );
        },
        (serverMeta) async {
          final fileUrl = serverMeta['fileUrl'] as String? ?? '';
          final meta = {
            'localPath': picked.path,
            'mimeType': serverMeta['mimeType'] ?? 'image/jpeg',
            'fileName': serverMeta['fileName'] ?? picked.name,
            'fileSize': serverMeta['fileSize'] ?? 0,
          };

          await _localDataSource.updateMessageMedia(msgId, fileUrl, meta);

          _socketService.sendMessage(
            roomId: roomId,
            messageId: msgId,
            text: '📷 Photo',
            type: 'image',
            fileUrl: fileUrl,
            metadata: meta,
          );
        },
      );
    } catch (e) {
      await _localDataSource.updateMessageStatus(msgId, MessageStatus.error);
    }
  }

  // ── sendImageMessage ────────────────────────────────────────────────────────

  /// Opens the gallery, uploads the picked image, then sends it.
  /// Shows an optimistic "📷 Uploading…" bubble while the upload is in-flight.
  Future<void> sendImageMessage(BuildContext context) async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final pendingContact = _pendingContact;
    final roomCreated = await _ensureRoom(pendingContact);
    if (!roomCreated) return;

    final roomId = _activeRoomId!;
    final msgId = _uuid.v4();

    // 1. Optimistic placeholder bubble.
    final optimistic = Message(
      id: msgId,
      clientMessageId: msgId,
      roomId: roomId,
      senderId: currentUserId.isNotEmpty ? currentUserId : 'me',
      text: '📷 Uploading…',
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      type: MessageType.image,
      metadata: {'localPath': picked.path},
    );
    await _localDataSource.saveMessage(
      optimistic,
      roomName: pendingContact?.name ?? '',
      roomAvatarUrl: pendingContact?.avatarUrl ?? '',
      roomPhoneNumber: pendingContact?.phoneNumber ?? '',
    );

    // 2. Upload — the repository returns Either<Failure, Map>.
    // We use a local variable instead of throw-to-catch so the typed Failure
    // message (from the domain layer) reaches the UI — not a raw exception string.
    final uploadResult = await _chatRepository.uploadFile(File(picked.path));
    Failure? uploadFailure;
    await uploadResult.fold(
      (failure) async {
        debugPrint('[ChatCubit] Image upload failed: ${failure.message}');
        uploadFailure = failure;
        await _localDataSource.updateMessageStatus(msgId, MessageStatus.error);
      },
      (serverMeta) async {
        final fileUrl = serverMeta['fileUrl'] as String? ?? '';
        final meta = {
          'localPath': picked.path,
          'mimeType': serverMeta['mimeType'] ?? 'image/jpeg',
          'fileName': serverMeta['fileName'] ?? picked.name,
          'fileSize': serverMeta['fileSize'] ?? 0,
        };

        // 3. Patch the optimistic bubble with the real fileUrl.
        await _localDataSource.updateMessageMedia(msgId, fileUrl, meta);

        // 4. Transmit via socket — omit local-device paths; CDN URLs only.
        _socketService.sendMessage(
          roomId: roomId,
          messageId: msgId,
          text: '📷 Photo',
          type: 'image',
          fileUrl: fileUrl,
          metadata: {
            'mimeType': serverMeta['mimeType'] ?? 'image/jpeg',
            'fileName': serverMeta['fileName'] ?? picked.name,
            'fileSize': serverMeta['fileSize'] ?? 0,
          },
        );
        debugPrint('[ChatCubit] Image sent: $fileUrl');
      },
    );

    if (uploadFailure != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image upload failed: ${uploadFailure!.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── sendVideoMessage ────────────────────────────────────────────────────────

  Future<void> sendVideoMessage(BuildContext context) async {
    final pickedFile = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final filePath = pickedFile.path;

    final pendingContact = _pendingContact;
    final roomCreated = await _ensureRoom(pendingContact);
    if (!roomCreated) return;

    final roomId = _activeRoomId!;
    final msgId = _uuid.v4();

    // Generate thumbnail locally
    String? thumbPath;
    try {
      final tempDir = await getTemporaryDirectory();
      thumbPath = await VideoThumbnail.thumbnailFile(
        video: filePath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 400,
        quality: 75,
      );
    } catch (e) {
      debugPrint('[ChatCubit] Thumbnail generation failed: $e');
    }

    final optimistic = Message(
      id: msgId,
      clientMessageId: msgId,
      roomId: roomId,
      senderId: currentUserId.isNotEmpty ? currentUserId : 'me',
      text: '🎬 Video',
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      type: MessageType.video,
      metadata: {
        'localPath': filePath,
        if (thumbPath != null) 'localThumbPath': thumbPath,
      },
    );

    await _localDataSource.saveMessage(
      optimistic,
      roomName: pendingContact?.name ?? '',
      roomAvatarUrl: pendingContact?.avatarUrl ?? '',
      roomPhoneNumber: pendingContact?.phoneNumber ?? '',
    );

    // Upload Video — Either<Failure, Map> from the repository.
    // Use a local Failure? variable; no throw-to-catch anti-pattern.
    final uploadResult = await _chatRepository.uploadFile(File(filePath));
    Failure? uploadFailure;
    await uploadResult.fold(
      (failure) async {
        debugPrint('[ChatCubit] Video upload failed: ${failure.message}');
        uploadFailure = failure;
        await _localDataSource.updateMessageStatus(msgId, MessageStatus.error);
      },
      (serverMeta) async {
        final fileUrl = serverMeta['fileUrl'] as String? ?? '';

        // Upload Thumbnail (best-effort — non-blocking failure).
        String thumbUrl = '';
        if (thumbPath != null && File(thumbPath).existsSync()) {
          final thumbUpload = await _chatRepository.uploadFile(File(thumbPath));
          thumbUpload.fold(
            (l) =>
                debugPrint('[ChatCubit] Thumbnail upload failed: ${l.message}'),
            (r) => thumbUrl = r['fileUrl'] as String? ?? '',
          );
        }

        final meta = {
          'localPath': filePath,
          if (thumbPath != null) 'localThumbPath': thumbPath,
          if (thumbUrl.isNotEmpty) 'thumbnailUrl': thumbUrl,
          'mimeType': serverMeta['mimeType'] ?? 'video/mp4',
          'fileName': serverMeta['fileName'] ?? pickedFile.name,
          'fileSize': serverMeta['fileSize'] ?? 0,
        };

        await _localDataSource.updateMessageMedia(msgId, fileUrl, meta);

        // Transmit via socket — omit local-device paths; CDN URLs only.
        _socketService.sendMessage(
          roomId: roomId,
          messageId: msgId,
          text: '🎬 Video',
          type: 'video',
          fileUrl: fileUrl,
          metadata: {
            if (thumbUrl.isNotEmpty) 'thumbnailUrl': thumbUrl,
            'mimeType': serverMeta['mimeType'] ?? 'video/mp4',
            'fileName': serverMeta['fileName'] ?? pickedFile.name,
            'fileSize': serverMeta['fileSize'] ?? 0,
          },
        );
        debugPrint('[ChatCubit] Video sent: $fileUrl');
      },
    );

    if (uploadFailure != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video upload failed: ${uploadFailure!.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── sendFileMessage ─────────────────────────────────────────────────────────

  /// Opens the OS file picker, uploads the file, then sends it.
  Future<void> sendFileMessage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;

    final pickedFile = result.files.single;
    final filePath = pickedFile.path!;

    final pendingContact = _pendingContact;
    final roomCreated = await _ensureRoom(pendingContact);
    if (!roomCreated) return;

    final roomId = _activeRoomId!;
    final msgId = _uuid.v4();

    // 1. Optimistic placeholder.
    final optimistic = Message(
      id: msgId,
      clientMessageId: msgId,
      roomId: roomId,
      senderId: currentUserId.isNotEmpty ? currentUserId : 'me',
      text: '📎 Uploading…',
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      type: MessageType.file,
      metadata: {
        'localPath': filePath,
        'fileName': pickedFile.name,
        'fileSize': pickedFile.size,
      },
    );
    await _localDataSource.saveMessage(
      optimistic,
      roomName: pendingContact?.name ?? '',
      roomAvatarUrl: pendingContact?.avatarUrl ?? '',
      roomPhoneNumber: pendingContact?.phoneNumber ?? '',
    );

    // 2. Upload — repository returns Either<Failure, Map>.
    final uploadResult = await _chatRepository.uploadFile(File(filePath));
    Failure? uploadFailure;
    await uploadResult.fold(
      (failure) async {
        debugPrint('[ChatCubit] File upload failed: ${failure.message}');
        uploadFailure = failure;
        await _localDataSource.updateMessageStatus(msgId, MessageStatus.error);
      },
      (serverMeta) async {
        final fileUrl = serverMeta['fileUrl'] as String? ?? '';
        final meta = {
          'localPath': filePath,
          'fileName': serverMeta['fileName'] ?? pickedFile.name,
          'fileSize': serverMeta['fileSize'] ?? pickedFile.size,
          'mimeType': serverMeta['mimeType'] ?? 'application/octet-stream',
        };

        // 3. Patch bubble.
        await _localDataSource.updateMessageMedia(msgId, fileUrl, meta);

        // 4. Transmit.
        _socketService.sendMessage(
          roomId: roomId,
          messageId: msgId,
          text: '📎 File',
          type: 'file',
          fileUrl: fileUrl,
          metadata: meta,
        );
        debugPrint('[ChatCubit] File sent: $fileUrl');
      },
    );

    if (uploadFailure != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File upload failed: ${uploadFailure!.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── sendContactMessage ──────────────────────────────────────────────────────

  /// Sends a contact card. No upload needed — metadata is built locally.
  Future<void> sendContactMessage(Contact contact) async {
    final contactName = contact.displayName;
    final contactPhone = contact.phones.isNotEmpty
        ? contact.phones.first.number
        : '';

    await sendLocalMessage(
      MessageDraft(
        text: '👤 $contactName',
        type: MessageType.contact,
        metadata: {'contactName': contactName, 'contactPhone': contactPhone},
      ),
    );
  }

  // ── sendLocationMessage ─────────────────────────────────────────────────────

  Future<void> sendLocationMessage(
    double lat,
    double lng,
    String address,
  ) async {
    await sendLocalMessage(
      MessageDraft(
        text: '📍 Location',
        type: MessageType.location,
        metadata: {'latitude': lat, 'longitude': lng, 'address': address},
      ),
    );
  }

  // ── sendAudioMessage ────────────────────────────────────────────────────────

  Future<void> sendAudioMessage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;

    final pickedFile = result.files.single;
    final filePath = pickedFile.path!;

    final pendingContact = _pendingContact;
    final roomCreated = await _ensureRoom(pendingContact);
    if (!roomCreated) return;

    final roomId = _activeRoomId!;
    final msgId = _uuid.v4();

    final optimistic = Message(
      id: msgId,
      clientMessageId: msgId,
      roomId: roomId,
      senderId: currentUserId.isNotEmpty ? currentUserId : 'me',
      text: '🎵 Audio',
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      type: MessageType.audio,
      metadata: {'localPath': filePath, 'fileName': pickedFile.name},
    );
    await _localDataSource.saveMessage(
      optimistic,
      roomName: pendingContact?.name ?? '',
      roomAvatarUrl: pendingContact?.avatarUrl ?? '',
      roomPhoneNumber: pendingContact?.phoneNumber ?? '',
    );

    try {
      final uploadResult = await _chatRepository.uploadFile(File(filePath));
      await uploadResult.fold(
        (failure) async {
          await _localDataSource.updateMessageStatus(
            msgId,
            MessageStatus.error,
          );
        },
        (serverMeta) async {
          final fileUrl = serverMeta['fileUrl'] as String? ?? '';
          final meta = {
            'localPath': filePath,
            'fileName': serverMeta['fileName'] ?? pickedFile.name,
          };

          await _localDataSource.updateMessageMedia(msgId, fileUrl, meta);

          _socketService.sendMessage(
            roomId: roomId,
            messageId: msgId,
            text: '🎵 Audio',
            type: 'audio',
            fileUrl: fileUrl,
            metadata: meta,
          );
        },
      );
    } catch (e) {
      await _localDataSource.updateMessageStatus(msgId, MessageStatus.error);
    }
  }

  // ── sendPollMessage ─────────────────────────────────────────────────────────

  Future<void> sendPollMessage(String question, List<String> options) async {
    await sendLocalMessage(
      MessageDraft(
        text: '📊 Poll',
        type: MessageType.poll,
        metadata: {'question': question, 'options': options},
      ),
    );
  }

  // ── sendEventMessage ────────────────────────────────────────────────────────

  Future<void> sendEventMessage(
    String title,
    DateTime dateTime,
    String description,
  ) async {
    await sendLocalMessage(
      MessageDraft(
        text: '📅 Event',
        type: MessageType.event,
        metadata: {
          'title': title,
          'dateTime': dateTime.toIso8601String(),
          'description': description,
        },
      ),
    );
  }

  // ── sendVoiceNote ───────────────────────────────────────────────────────────

  /// Uploads a pre-recorded voice file at [localPath] and sends it.
  /// Pass [durationSeconds] if known from the recorder.
  Future<void> sendVoiceNote(
    BuildContext context,
    String localPath, {
    int durationSeconds = 0,
    List<double> waveformSamples = const [],
  }) async {
    final pendingContact = _pendingContact;
    final roomCreated = await _ensureRoom(pendingContact);
    if (!roomCreated) return;

    final roomId = _activeRoomId!;
    final msgId = _uuid.v4();

    // 1. Optimistic placeholder.
    final optimistic = Message(
      id: msgId,
      clientMessageId: msgId,
      roomId: roomId,
      senderId: currentUserId.isNotEmpty ? currentUserId : 'me',
      text: '🎤 Uploading…',
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      type: MessageType.voiceNote,
      metadata: {
        'localPath': localPath,
        'duration': durationSeconds,
        if (waveformSamples.isNotEmpty) 'waveformSamples': waveformSamples,
      },
    );
    await _localDataSource.saveMessage(
      optimistic,
      roomName: pendingContact?.name ?? '',
      roomAvatarUrl: pendingContact?.avatarUrl ?? '',
      roomPhoneNumber: pendingContact?.phoneNumber ?? '',
    );

    // 2. Upload — repository returns Either<Failure, Map>.
    final uploadResult = await _chatRepository.uploadFile(File(localPath));
    Failure? uploadFailure;
    await uploadResult.fold(
      (failure) async {
        debugPrint('[ChatCubit] Voice note upload failed: ${failure.message}');
        uploadFailure = failure;
        await _localDataSource.updateMessageStatus(msgId, MessageStatus.error);
      },
      (serverMeta) async {
        final fileUrl = serverMeta['fileUrl'] as String? ?? '';
        final meta = {
          'localPath': localPath,
          'duration': durationSeconds,
          'mimeType': serverMeta['mimeType'] ?? 'audio/m4a',
          'fileName': serverMeta['fileName'] ?? 'voice_note.m4a',
          'fileSize': serverMeta['fileSize'] ?? 0,
          if (waveformSamples.isNotEmpty) 'waveformSamples': waveformSamples,
        };

        // 3. Patch bubble.
        await _localDataSource.updateMessageMedia(msgId, fileUrl, meta);

        // 4. Transmit.
        // Transmit via socket — omit local-device path; CDN URLs only.
        _socketService.sendMessage(
          roomId: roomId,
          messageId: msgId,
          text: '🎤 Voice note',
          type: 'voice_note',
          fileUrl: fileUrl,
          metadata: {
            'duration': durationSeconds,
            'mimeType': serverMeta['mimeType'] ?? 'audio/m4a',
            'fileName': serverMeta['fileName'] ?? 'voice_note.m4a',
            'fileSize': serverMeta['fileSize'] ?? 0,
            if (waveformSamples.isNotEmpty) 'waveformSamples': waveformSamples,
          },
        );
        debugPrint('[ChatCubit] Voice note sent: $fileUrl');
      },
    );

    if (uploadFailure != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice note upload failed: ${uploadFailure!.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Contact sync ────────────────────────────────────────────────────────────

  Future<bool> silentSyncContacts() async {
    try {
      final myPhoneNumber = await _authLocalDataSource.getUserPhone() ?? '';

      String userCountryCode = '+20';
      if (myPhoneNumber.isNotEmpty && myPhoneNumber.startsWith('+')) {
        if (myPhoneNumber.startsWith('+20')) {
          userCountryCode = '+20';
        } else if (myPhoneNumber.length >= 4) {
          userCountryCode = myPhoneNumber.substring(0, 4);
        }
      }

      final contacts = await _contactsService.syncContacts(
        defaultCountryCode: userCountryCode,
      );
      await _localDataSource.upsertContacts(contacts);
      return true;
    } catch (e) {
      debugPrint('[ChatCubit] silentSyncContacts failed: $e');
      if (e.toString().toLowerCase().contains('permission')) return false;
      return true;
    }
  }

  // ── Network ─────────────────────────────────────────────────────────────────

  void connectNetwork(String jwtToken) async {
    _socketService.connect(jwtToken);
    await hydrateRooms();
  }

  // ── REST status sync ─────────────────────────────────────────────────────────

  Future<void> syncStatusesFromRest() async {
    try {
      final stuck = await _localDataSource.getStuckMessages();
      if (stuck.isEmpty) {
        debugPrint('[ChatCubit] REST sync: no stuck messages');
        return;
      }

      final ids = stuck.map((m) => m.clientMessageId).toList();
      debugPrint(
        '[ChatCubit] REST sync: checking ${ids.length} stuck message(s)',
      );

      final result = await _chatRepository.syncMessageStatuses(ids);
      await result.fold(
        (failure) {
          debugPrint('[ChatCubit] REST sync failed: $failure');
          // Handle failure, maybe emit an error state or log it
        },
        (statuses) async {
          if (statuses.isEmpty) return;

          const rankOf = {'pending': 0, 'sent': 1, 'delivered': 2, 'read': 3};

          for (final msg in stuck) {
            final serverStatusStr = statuses[msg.clientMessageId];
            if (serverStatusStr == null) continue;

            final serverStatus = MessageStatus.values.firstWhere(
              (e) => e.name == serverStatusStr,
              orElse: () => msg.status,
            );

            final currentRank = rankOf[msg.status.name] ?? 0;
            final newRank = rankOf[serverStatus.name] ?? 0;
            if (newRank > currentRank) {
              await _localDataSource.updateMessageStatus(msg.id, serverStatus);
              debugPrint(
                '[ChatCubit] REST sync: ${msg.id} → ${serverStatus.name}',
              );
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[ChatCubit] REST sync failed: $e');
    }
  }

  // ── Offline message recovery ─────────────────────────────────────────────────

  Future<void> _syncMissedMessages() async {
    try {
      final result = await _chatRepository.fetchRooms();
      await result.fold(
        (failure) {
          debugPrint('[ChatCubit] Missed-message sync: fetchRooms failed: $failure');
        },
        (rooms) async {
          for (final room in rooms) {
            final localTs = await _localDataSource.getLastMessageTimestamp(room.id);
            final serverTs = room.timestamp;
            if (localTs != null && !serverTs.isAfter(localTs)) continue;

            final msgResult = await _chatRepository.fetchRoomMessages(room.id);
            msgResult.fold(
              (f) => debugPrint('[ChatCubit] Missed-message fetch failed for ${room.id}: $f'),
              (msgs) async {
                // Messages picked up here arrived while we were backgrounded
                // and never passed through onNewMessage's live socket path —
                // the only other place that emits markDelivered. Without this,
                // the sender's tick never promotes past "sent" until we
                // eventually mark the room read, jumping straight to "seen".
                final deliveredIds = <String>[];
                for (final msg in msgs.reversed) {
                  await _localDataSource.saveMessage(msg, incrementUnread: true);
                  if (msg.senderId != currentUserId) {
                    deliveredIds.add(msg.clientMessageId);
                  }
                }
                if (deliveredIds.isNotEmpty) {
                  _socketService.markDelivered(
                    roomId: room.id,
                    messageIds: deliveredIds,
                  );
                }
                debugPrint('[ChatCubit] Recovered ${msgs.length} message(s) for ${room.id}');
              },
            );
          }
        },
      );
    } catch (e) {
      debugPrint('[ChatCubit] Missed-message sync error: $e');
    }
  }

  // ── Pending replay ──────────────────────────────────────────────────────────

  Future<void> syncPendingMessages() async {
    final pending = await _localDataSource.getPendingMessages();
    if (pending.isEmpty) return;

    debugPrint('[ChatCubit] Syncing ${pending.length} pending message(s)…');

    for (final msg in pending) {
      if (!_socketService.isConnected) {
        debugPrint('[ChatCubit] Socket offline — stopping pending sync early');
        break;
      }
      // Skip media messages that are still uploading (fileUrl not yet set).
      if (msg.type != MessageType.text &&
          (msg.fileUrl == null || msg.fileUrl!.isEmpty)) {
        debugPrint('[ChatCubit] Skipping in-flight upload: ${msg.id}');
        continue;
      }

      _socketService.sendMessage(
        roomId: msg.roomId,
        messageId: msg.clientMessageId,
        text: msg.text,
        type: messageTypeToString(msg.type),
        fileUrl: msg.fileUrl,
        metadata: msg.metadata,
      );

      debugPrint('[ChatCubit] Re-sent pending: ${msg.id}');
    }
  }

  // ── resendMessage ───────────────────────────────────────────────────────────

  /// Retries sending a failed message.
  Future<void> resendMessage(String clientMessageId) async {
    final msg = await _localDataSource.getMessageById(clientMessageId);
    if (msg == null || msg.status != MessageStatus.error) return;

    // Update status to pending
    await _localDataSource.updateMessageStatus(msg.id, MessageStatus.pending);

    // Update the local state if the room is active
    if (state is ChatRoomActive) {
      final activeState = state as ChatRoomActive;
      if (activeState.roomId == msg.roomId) {
        final messages = List<Message>.from(activeState.messages);
        final index = messages.indexWhere(
          (m) => m.clientMessageId == clientMessageId,
        );
        if (index != -1) {
          messages[index] = messages[index].copyWith(
            status: MessageStatus.pending,
          );
          emit(activeState.copyWith(messages: messages));
        }
      }
    }

    try {
      // Re-emit via socket
      if (msg.type == MessageType.text ||
          (msg.fileUrl != null && msg.fileUrl!.isNotEmpty)) {
        _socketService.sendMessage(
          roomId: msg.roomId,
          messageId: msg.clientMessageId,
          text: msg.text,
          type: messageTypeToString(msg.type),
          fileUrl: msg.fileUrl,
          metadata: msg.metadata,
        );
        debugPrint('[ChatCubit] Re-sent message: ${msg.id}');
      } else {
        // If media message and it failed before/during upload, we would need to re-upload.
        // For simplicity in this US, we retry via socket or mark as error if it lacks fileUrl.
        // If re-upload is needed, we should fetch localPath from metadata and upload.
        final localPath = msg.metadata?['localPath'] as String?;
        if (localPath != null && File(localPath).existsSync()) {
          final uploadResult = await _chatRepository.uploadFile(
            File(localPath),
          );
          await uploadResult.fold(
            (failure) async {
              await _localDataSource.updateMessageStatus(
                msg.id,
                MessageStatus.error,
              );
              handleMessageStatusUpdate(
                msg.clientMessageId,
                MessageStatus.error,
              );
            },
            (serverMeta) async {
              final fileUrl = serverMeta['fileUrl'] as String? ?? '';
              final meta = Map<String, dynamic>.from(msg.metadata ?? {});
              meta['mimeType'] = serverMeta['mimeType'] ?? meta['mimeType'];
              meta['fileName'] = serverMeta['fileName'] ?? meta['fileName'];
              meta['fileSize'] = serverMeta['fileSize'] ?? meta['fileSize'];

              await _localDataSource.updateMessageMedia(msg.id, fileUrl, meta);
              _socketService.sendMessage(
                roomId: msg.roomId,
                messageId: msg.clientMessageId,
                text: msg.text,
                type: messageTypeToString(msg.type),
                fileUrl: fileUrl,
                metadata: meta,
              );
            },
          );
        } else {
          debugPrint(
            '[ChatCubit] Cannot resend media message: no fileUrl and no localPath',
          );
          await _localDataSource.updateMessageStatus(
            msg.id,
            MessageStatus.error,
          );
          handleMessageStatusUpdate(msg.clientMessageId, MessageStatus.error);
        }
      }
    } catch (e) {
      debugPrint('[ChatCubit] resendMessage failed: $e');
      await _localDataSource.updateMessageStatus(msg.id, MessageStatus.error);
      handleMessageStatusUpdate(msg.clientMessageId, MessageStatus.error);
    }
  }

  // ── hydrateRooms ─────────────────────────────────────────────────────────────

  Future<void> hydrateRooms() async {
    try {
      // US9: Added 5-second timeout to prevent app hang on slow/unreachable network.
      final result = await _chatRepository.fetchRooms().timeout(
        const Duration(seconds: 5),
      );

      await result.fold(
        (failure) {
          debugPrint('[ChatCubit] Hydration failed (repository): $failure');
        },
        (rooms) async {
          for (final room in rooms) {
            await _localDataSource.saveRoom(room);
          }
          debugPrint(
            '[ChatCubit] Hydrated ${rooms.length} room(s) into SQLite',
          );
        },
      );
    } catch (e) {
      debugPrint('[ChatCubit] Hydration failed or timed out: $e');
    } finally {
      // Always complete hydration to allow user to see local data.
      isHydrationComplete = true;
      emit(ChatInitial());
    }
  }

  // ── getRoomById ──────────────────────────────────────────────────────────────

  Future<ChatSession?> getRoomById(String roomId) =>
      _localDataSource.getRoomById(roomId);

  // ── reset ────────────────────────────────────────────────────────────────────

  void reset() {
    _roomStreamSub?.cancel();
    _activeRoomId = null;
    _isDeliberatelyOpen = false;
    _voiceWaveformCache.clear();
    currentUserId = '';
    isHydrationComplete = false;
    emit(ChatInitial());
  }

  /// Uploads [file] via the chat file endpoint and returns the server-relative
  /// URL on success, or null on failure. Used by CreateGroupPage for avatar upload.
  Future<String?> uploadGroupAvatar(File file) async {
    final result = await _chatRepository.uploadFile(file);
    return result.fold((_) => null, (meta) {
      final raw = meta['fileUrl'] as String?;
      if (raw == null || raw.isEmpty) return null;
      // Backend createGroup DTO uses @IsUrl() which requires an absolute URL.
      return UrlUtils.resolveMediaUrl(raw);
    });
  }

  Future<void> createGroup(
    String groupName,
    List<String> participants, {
    String? avatarUrl,
  }) async {
    emit(ChatLoading()); // Indicate that group creation is in progress
    final result = await _chatRepository.createGroup(
      groupName,
      participants,
      avatarUrl,
    );
    result.fold(
      (failure) {
        debugPrint('[ChatCubit] Group creation failed: $failure');
        emit(ChatError(failure.message));
      },
      (chatRoomData) async {
        // chatRoomData contains the newly created room's details including ID
        final newRoom = ChatSession.fromJson(
          chatRoomData,
          currentUserId, // Assuming currentUserId is phone number
        );
        await _localDataSource.saveRoom(newRoom);
        _socketService.joinRoom(newRoom.id);
        openRoom(newRoom.id); // Navigate to the new group chat
      },
    );
  }

  Future<void> addParticipants(String roomId, List<String> userPhones) async {
    final result = await _chatRepository.addParticipants(roomId, userPhones);
    result.fold(
      (failure) => emit(ChatError(failure.message)),
      (_) => hydrateRooms(), // Refresh local state to reflect new participants
    );
  }

  Future<void> removeParticipant(String roomId, String participantId) async {
    final result = await _chatRepository.removeParticipant(
      roomId,
      participantId,
    );
    result.fold(
      (failure) => emit(ChatError(failure.message)),
      (_) => hydrateRooms(), // Refresh local state to reflect removal
    );
  }

  Future<void> leaveGroup(String roomId) async {
    final result = await _chatRepository.leaveGroup(roomId);
    result.fold((failure) => emit(ChatError(failure.message)), (newAdmin) async {
      // If a new admin was promoted, update the room's admins list in SQLite
      // so any other participant on this device sees the correct state.
      if (newAdmin != null && newAdmin.isNotEmpty) {
        final room = await _localDataSource.getRoomById(roomId);
        if (room != null) {
          await _localDataSource.saveRoom(room.copyWith(admins: [newAdmin]));
        }
      }
      await _localDataSource.deleteRoom(roomId);
      hydrateRooms();
    });
  }

  Future<void> updateGroupName(String roomId, String name) async {
    final result = await _chatRepository.updateGroup(roomId, name: name);
    result.fold(
      (failure) => emit(ChatError(failure.message)),
      (_) async {
        // Optimistic update: patch local SQLite row before server echo.
        final room = await _localDataSource.getRoomById(roomId);
        if (room != null) {
          await _localDataSource.saveRoom(room.copyWith(name: name));
        }
      },
    );
  }

  Future<void> updateGroupAvatar(String roomId, String avatarUrl) async {
    final result = await _chatRepository.updateGroup(
      roomId,
      avatarUrl: avatarUrl,
    );
    result.fold(
      (failure) => emit(ChatError(failure.message)),
      (_) async {
        final room = await _localDataSource.getRoomById(roomId);
        if (room != null) {
          await _localDataSource.saveRoom(room.copyWith(avatarUrl: avatarUrl));
        }
      },
    );
  }

  /// Called when the backend broadcasts `chatRoomUpdated` (e.g. admin changed
  /// group name or avatar). Updates local SQLite so the stream re-emits.
  void _onChatRoomUpdated(Map<String, dynamic> data) async {
    final roomId = data['roomId'] as String?;
    if (roomId == null || roomId.isEmpty) return;
    final room = await _localDataSource.getRoomById(roomId);
    if (room == null) return;

    final newName = data['name'] as String?;
    final newAvatar = data['avatarUrl'] as String?;
    final updated = room.copyWith(
      name: newName ?? room.name,
      avatarUrl: newAvatar ?? room.avatarUrl,
    );
    await _localDataSource.saveRoom(updated);
  }

  /// Called when the backend notifies that the current user has been added to
  /// a brand-new chat room (e.g. someone created a group including them).
  /// Parses the room, saves it locally so the chat list updates immediately,
  /// and joins the socket room so subsequent messages arrive in real time.
  void _onNewChatRoom(Map<String, dynamic> data) async {
    final raw = data['room'];
    if (raw is! Map) return;
    try {
      final json = Map<String, dynamic>.from(raw);
      final room = ChatSession.fromJson(json, currentUserPhone);
      if (room.id.isEmpty) return;
      await _localDataSource.saveRoom(room);
      _socketService.joinRoom(room.id);
    } catch (e) {
      debugPrint('[ChatCubit] _onNewChatRoom parse error: $e');
    }
  }

  /// Returns true if a group call is currently active for [roomId].
  bool hasActiveCall(String roomId) => activeCallRoomIds.value.containsKey(roomId);

  @override
  Future<void> close() {
    _socketService.removeUserStatusListener(_onUserStatusChanged);
    _roomStreamSub?.cancel();
    _typingTimer?.cancel();
    for (final t in _incomingTypingTimers.values) {
      t.cancel();
    }
    _incomingTypingTimers.clear();
    _typingUsersController.close();
    _roomTypingController.close();
    activeCallRoomIds.dispose();
    searchResults.dispose();
    return super.close();
  }

  // ── Status promotion engine ──────────────────────────────────────────────────

  int getStatusWeight(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return 0;
      case MessageStatus.sent:
        return 1;
      case MessageStatus.delivered:
        return 2;
      case MessageStatus.read:
        return 3;
      default:
        return -1;
    }
  }

  void handleMessageStatusUpdate(
    String clientMessageId,
    MessageStatus incomingStatus, {
    DateTime? createdAt,
  }) async {
    final incomingWeight = getStatusWeight(incomingStatus);

    if (state is ChatRoomActive) {
      final activeState = state as ChatRoomActive;
      final currentMessages = activeState.messages;

      final messageIndex = currentMessages.indexWhere(
        (m) => m.clientMessageId == clientMessageId,
      );

      if (messageIndex != -1) {
        final currentMessage = currentMessages[messageIndex];
        final currentWeight = getStatusWeight(currentMessage.status);

        if (incomingWeight > currentWeight) {
          await _localDataSource.updateMessageStatus(
            clientMessageId,
            incomingStatus,
            createdAt: createdAt,
          );

          final updatedMessages = List<Message>.from(currentMessages);
          updatedMessages[messageIndex] = currentMessage.copyWith(
            status: incomingStatus,
            timestamp: createdAt ?? currentMessage.timestamp,
          );
          // Use copyWith for a surgical state update — only the messages list
          // reference changes, so BlocBuilder rebuilds only the message list.
          emit(activeState.copyWith(messages: updatedMessages));
        }
        return;
      }
    }

    // Fallback: not in active room view.
    final currentStatusDB = await _localDataSource.getMessageStatus(
      clientMessageId,
    );
    if (currentStatusDB != null) {
      final currentWeightDB = getStatusWeight(currentStatusDB);
      if (incomingWeight > currentWeightDB) {
        await _localDataSource.updateMessageStatus(
          clientMessageId,
          incomingStatus,
          createdAt: createdAt,
        );
      }
    }
  }

  // ── Waveform Cache ──────────────────────────────────────────────────────────

  Future<List<double>?> getWaveformCache(String messageId) {
    return _localDataSource.getWaveformCache(messageId);
  }

  Future<void> saveWaveformCache(String messageId, List<double> samples) {
    return _localDataSource.saveWaveformCache(messageId, samples);
  }

  // ── In-Memory Waveform Cache (per conversation session, FR-010) ─────────────
  // Feature 010: Cache waveform geometry in memory to prevent re-extraction
  // on parent-list rebuilds. Cleared when room closes.

  VoiceWaveformGeometry? getSessionWaveformCache(String messageId) {
    return _voiceWaveformCache[messageId];
  }

  void cacheSessionWaveform(VoiceWaveformGeometry geometry) {
    _voiceWaveformCache[geometry.messageId] = geometry;
    debugPrint('[ChatCubit] Cached waveform for message ${geometry.messageId}');
  }

  // ── Block Management ────────────────────────────────────────────────────────
  // Block state is owned exclusively by the Cubit's emitted state:
  //   - ChatRoomActive.blockedUserIds  (carried while in an active room)
  //   - ChatBlockUpdated               (surgical emit after block/unblock)
  // Do NOT read from mutable fields here — always read from state.

  /// Returns true if [targetUserId] is in the current blocked list.
  /// Reads from the current emitted state — no mutable field dependency.
  bool isUserBlocked(String targetUserId) {
    if (state is ChatRoomActive) {
      return (state as ChatRoomActive).blockedUserIds.contains(targetUserId);
    }
    if (state is ChatBlockUpdated) {
      return (state as ChatBlockUpdated).blockedUserIds.contains(targetUserId);
    }
    return false;
  }

  /// Reads the current blocked list from state (safe fallback to empty).
  List<String> get _currentBlockedIds {
    if (state is ChatRoomActive) {
      return (state as ChatRoomActive).blockedUserIds;
    }
    if (state is ChatBlockUpdated) {
      return (state as ChatBlockUpdated).blockedUserIds;
    }
    return const [];
  }

  Future<bool> blockUser(String targetUserId) async {
    final result = await _chatRepository.blockUser(targetUserId);
    return result.fold(
      (failure) {
        debugPrint('[ChatCubit] Failed to block user: ${failure.message}');
        return false;
      },
      (_) {
        final updated = [..._currentBlockedIds];
        if (!updated.contains(targetUserId)) updated.add(targetUserId);
        // Surgical emit: update ChatRoomActive if active, else emit ChatBlockUpdated.
        if (state is ChatRoomActive) {
          emit((state as ChatRoomActive).copyWith(blockedUserIds: updated));
        } else {
          emit(ChatBlockUpdated(updated));
        }
        return true;
      },
    );
  }

  Future<bool> unblockUser(String targetUserId) async {
    final result = await _chatRepository.unblockUser(targetUserId);
    return result.fold(
      (failure) {
        debugPrint('[ChatCubit] Failed to unblock user: ${failure.message}');
        return false;
      },
      (_) {
        final updated = _currentBlockedIds
            .where((id) => id != targetUserId)
            .toList();
        if (state is ChatRoomActive) {
          emit((state as ChatRoomActive).copyWith(blockedUserIds: updated));
        } else {
          emit(ChatBlockUpdated(updated));
        }
        return true;
      },
    );
  }

  // ── Search & Media ────────────────────────────────────────────────────────

  Future<void> searchMessages(String query) async {
    if (_activeRoomId == null || query.isEmpty) {
      searchResults.value = [];
      return;
    }
    final results = await _localDataSource.searchMessages(
      _activeRoomId!,
      query,
    );
    searchResults.value = results;
  }

  void clearSearch() {
    searchResults.value = [];
  }

  Future<List<Message>> getSharedMedia(String roomId) async {
    return _localDataSource.getSharedMedia(roomId);
  }

  Future<List<Message>> getSharedLinks(String roomId) async {
    return _localDataSource.getSharedLinks(roomId);
  }

  Future<List<Message>> getSharedDocs(String roomId) async {
    return _localDataSource.getSharedDocs(roomId);
  }

  Future<Map<String, int>> getMediaCount(String roomId) async {
    return _localDataSource.getMediaCount(roomId);
  }

  // ── FR-022: Message Deletion ─────────────────────────────────────────────

  /// Deletes a message locally only ("Delete for me").
  Future<void> deleteMessageForMe(String clientMessageId) async {
    await _localDataSource.markMessageDeleted(clientMessageId);
    // Stream refresh is triggered inside markMessageDeleted.
  }

  /// Deletes a message for everyone — emits socket event and marks locally.
  /// Only works within 1 hour of the message timestamp.
  Future<void> deleteMessageForEveryone(String clientMessageId) async {
    // Optimistic local update first.
    await _localDataSource.markMessageDeleted(clientMessageId);
    // Emit socket event so the server + recipient are notified.
    _socketService.deleteMessageForEveryone(clientMessageId);
  }

  /// Called when we receive a `messageDeleted` socket event from the server.
  /// Marks the message as deleted in local DB and updates state.
  Future<void> _handleDeletedMessage(String clientMessageId) async {
    await _localDataSource.markMessageDeleted(clientMessageId);
    // Stream watcher will auto-emit new state.
  }
}
