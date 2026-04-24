import 'dart:async';
import 'dart:io';
import 'package:fpdart/fpdart.dart'; // Import for Either
import 'package:ciro_chat_app/core/error/failures.dart'; // Import for Failure
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';

import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/domain/repositories/chat_repository.dart'; // Use repository
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/contacts/data/contacts_service.dart';

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
  ChatSession? _pendingContact;
  String currentUserId = '';
  String currentUserPhone = '';
  bool isHydrationComplete = false;
  final _uuid = const Uuid();

  final _typingUsersController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get typingUsersStream => _typingUsersController.stream;
  final Set<String> _currentTypingUsers = {};

  // Per-room typing state to support chat list indicators
  final Map<String, Set<String>> _typingUsersByRoom = {};
  final _roomTypingController =
      StreamController<Map<String, Set<String>>>.broadcast();
  Stream<Map<String, Set<String>>> get allTypingUsersStream =>
      _roomTypingController.stream;

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

  Future<void> _initServices() async {
    currentUserId = await _authLocalDataSource.getUserId() ?? '';
    currentUserPhone = await _authLocalDataSource.getUserPhone() ?? '';
    await _localDataSource.initDB();

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

    _socketService.onMessageRead = (clientMessageIds) {
      for (final id in clientMessageIds) {
        handleMessageStatusUpdate(id, MessageStatus.read);
      }
    };

    _socketService.onReconnected = () {
      debugPrint(
        '[ChatCubit] Socket reconnected — triggering REST status sync + pending replay',
      );
      syncStatusesFromRest().ignore();
      syncPendingMessages().ignore();
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

      final incoming = Message(
        id: mongoId,
        clientMessageId: clientMsgId,
        roomId: data['chatRoomId'] ?? 'unknown',
        senderId: data['senderId'] ?? '',
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

      if (isActiveRoom) {
        _socketService.markRead(
          roomId: incoming.roomId,
          messageIds: [incoming.clientMessageId],
        );
        await _localDataSource.updateMessageStatus(
          incoming.id,
          MessageStatus.read,
        );
      }
    };

    // Cold-boot: REST sync + pending replay after socket settles.
    Future.delayed(const Duration(seconds: 1), () {
      syncStatusesFromRest().ignore();
      syncPendingMessages().ignore();
    });
  }

  // ── Room lifecycle ──────────────────────────────────────────────────────────

  void openRoom(String roomId, {ChatSession? contact}) {
    if (roomId.isEmpty) {
      _pendingContact = contact;
      _activeRoomId = null;
      emit(ChatRoomActive('', const []));
      return;
    }
    if (_activeRoomId == roomId) return;

    _pendingContact = null;
    _activeRoomId = roomId;
    _roomStreamSub?.cancel();
    _localDataSource.resetUnreadCount(roomId);
    emit(ChatLoading());

    _roomStreamSub = _localDataSource
        .watchRoomMessages(roomId)
        .listen(
          (messages) => emit(ChatRoomActive(roomId, messages)),
          onError: (e) => emit(ChatError(e.toString())),
        );
  }

  void closeRoom() {
    if (_activeRoomId != null) {
      _localDataSource.closeRoomStream(_activeRoomId!);
      _roomStreamSub?.cancel();
      _activeRoomId = null;
    }
    _pendingContact = null;
    _currentTypingUsers.clear();
    _typingUsersController.add({});
  }

  Future<void> markRoomMessagesRead(String roomId) async {
    final messages = await _localDataSource.getRoomMessages(roomId);
    final idsToMark = <String>[];
    for (final msg in messages) {
      if (msg.senderId != currentUserId &&
          msg.status == MessageStatus.delivered) {
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
    if (_activeRoomId != null) {
      _socketService.emitTyping(_activeRoomId!, isTyping);
    }
  }

  Future<String> getLocalContactName(String phoneNumber) async {
    final contacts = await _localDataSource.watchContacts().first;
    for (final contact in contacts) {
      if (contact.phoneNumber == phoneNumber) {
        return contact.name;
      }
    }
    return phoneNumber;
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
        await Future.delayed(const Duration(milliseconds: 300));

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

    try {
      // 2. Upload.
      final uploadResult = await _chatRepository.uploadFile(File(picked.path));
      await uploadResult.fold(
        (failure) async {
          debugPrint('[ChatCubit] Image upload failed: $failure');
          await _localDataSource.updateMessageStatus(
            msgId,
            MessageStatus.error,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image upload failed: ${failure.message}'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          throw Exception('Upload failed'); // Propagate to outer catch
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

          // 4. Transmit via socket.
          _socketService.sendMessage(
            roomId: roomId,
            messageId: msgId,
            text: '📷 Photo',
            type: 'image',
            fileUrl: fileUrl,
            metadata: meta,
          );
          debugPrint('[ChatCubit] Image sent: $fileUrl');
        },
      );
    } catch (e) {
      debugPrint('[ChatCubit] Image upload failed: $e');
      await _localDataSource.updateMessageStatus(msgId, MessageStatus.error);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
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

    try {
      // 2. Upload.
      final uploadResult = await _chatRepository.uploadFile(File(filePath));
      await uploadResult.fold(
        (failure) async {
          debugPrint('[ChatCubit] File upload failed: $failure');
          await _localDataSource.updateMessageStatus(
            msgId,
            MessageStatus.error,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File upload failed: ${failure.message}'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          throw Exception('Upload failed'); // Propagate to outer catch
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
    } catch (e) {
      debugPrint('[ChatCubit] File upload failed: $e');
      await _localDataSource.updateMessageStatus(msgId, MessageStatus.error);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File upload failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── sendContactMessage ──────────────────────────────────────────────────────

  /// Sends a contact card. No upload needed — metadata is built locally.
  Future<void> sendContactMessage(Contact contact) async {
    final contactName = contact.displayName;
    final contactPhone = contact.phones.isNotEmpty
        ? (contact.phones.first.number ?? '')
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
      metadata: {'localPath': localPath, 'duration': durationSeconds},
    );
    await _localDataSource.saveMessage(
      optimistic,
      roomName: pendingContact?.name ?? '',
      roomAvatarUrl: pendingContact?.avatarUrl ?? '',
      roomPhoneNumber: pendingContact?.phoneNumber ?? '',
    );

    try {
      // 2. Upload.
      final uploadResult = await _chatRepository.uploadFile(File(localPath));
      await uploadResult.fold(
        (failure) async {
          debugPrint('[ChatCubit] Voice note upload failed: $failure');
          await _localDataSource.updateMessageStatus(
            msgId,
            MessageStatus.error,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Voice note upload failed: ${failure.message}'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          throw Exception('Upload failed'); // Propagate to outer catch
        },
        (serverMeta) async {
          final fileUrl = serverMeta['fileUrl'] as String? ?? '';
          final meta = {
            'localPath': localPath,
            'duration': durationSeconds,
            'mimeType': serverMeta['mimeType'] ?? 'audio/m4a',
            'fileName': serverMeta['fileName'] ?? 'voice_note.m4a',
            'fileSize': serverMeta['fileSize'] ?? 0,
          };

          // 3. Patch bubble.
          await _localDataSource.updateMessageMedia(msgId, fileUrl, meta);

          // 4. Transmit.
          _socketService.sendMessage(
            roomId: roomId,
            messageId: msgId,
            text: '🎤 Voice note',
            type: 'voice_note',
            fileUrl: fileUrl,
            metadata: meta,
          );
          debugPrint('[ChatCubit] Voice note sent: $fileUrl');
        },
      );
    } catch (e) {
      debugPrint('[ChatCubit] Voice note upload failed: $e');
      await _localDataSource.updateMessageStatus(msgId, MessageStatus.error);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice note upload failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
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

  // ── hydrateRooms ─────────────────────────────────────────────────────────────

  Future<void> hydrateRooms() async {
    try {
      final result = await _chatRepository.fetchRooms();
      await result.fold(
        (failure) {
          debugPrint('[ChatCubit] Hydration silent fail: $failure');
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
      debugPrint('[ChatCubit] Hydration silent fail: $e');
    } finally {
      isHydrationComplete = true;
      emit(ChatInitial());
    }
  }

  // ── reset ────────────────────────────────────────────────────────────────────

  void reset() {
    _roomStreamSub?.cancel();
    _activeRoomId = null;
    currentUserId = '';
    isHydrationComplete = false;
    emit(ChatInitial());
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
    result.fold((failure) => emit(ChatError(failure.message)), (_) async {
      await _localDataSource.deleteRoom(roomId);
      hydrateRooms();
    });
  }

  @override
  Future<void> close() {
    _roomStreamSub?.cancel();
    _socketService.disconnect();
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
      final currentRoomId = activeState.roomId;
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
    @override
    Future<void> close() {
      _roomStreamSub?.cancel();
      _typingUsersController.close();
      _roomTypingController.close();
      return super.close();
    }
  }
}
