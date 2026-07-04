import 'dart:convert';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:equatable/equatable.dart';

enum MessageStatus { pending, sent, delivered, read, error }

enum MessageType {
  text,
  image,
  file,
  voiceNote,
  contact,
  system,
  location,
  audio,
  poll,
  event,
  video,
  /// 021-reels-video-feed: in-app reel share, rendered as a rich preview
  /// card (FR-021c). Metadata keys: reelId, thumbnailUrl, creatorName, deepLink.
  reelShare,
}

/// Maps a raw string from SQLite / socket payload to a [MessageType].
/// Falls back to [MessageType.text] for any unknown / null value.
MessageType messageTypeFromString(String? raw) {
  final normalized = raw?.trim().toLowerCase();
  switch (normalized) {
    case 'image':
      return MessageType.image;
    case 'file':
    case 'document':
      return MessageType.file;
    case 'voice_note':
    case 'voicenote':
      return MessageType.voiceNote;
    case 'audio':
      return MessageType.audio;
    case 'contact':
      return MessageType.contact;
    case 'system':
      return MessageType.system;
    case 'location':
      return MessageType.location;
    case 'poll':
      return MessageType.poll;
    case 'event':
      return MessageType.event;
    case 'video':
      return MessageType.video;
    case 'reel_share':
    case 'reelshare':
      return MessageType.reelShare;
    default:
      return MessageType.text;
  }
}

/// Returns the wire/SQL string for a [MessageType].
String messageTypeToString(MessageType type) {
  switch (type) {
    case MessageType.image:
      return 'image';
    case MessageType.file:
      return 'file';
    case MessageType.voiceNote:
      return 'voice_note';
    case MessageType.audio:
      return 'audio';
    case MessageType.contact:
      return 'contact';
    case MessageType.system:
      return 'system';
    case MessageType.location:
      return 'location';
    case MessageType.poll:
      return 'poll';
    case MessageType.event:
      return 'event';
    case MessageType.video:
      return 'video';
    case MessageType.reelShare:
      return 'reel_share';
    case MessageType.text:
      return 'text';
  }
}

class Message extends Equatable {
  final String id;
  final String clientMessageId;
  final String roomId;
  final String senderId;
  /// Phone number of the sender — used to resolve the display name in group chats.
  final String senderPhone;
  /// Registered display name of the sender (from User.name on the backend).
  /// Used as the fallback label in group bubbles when the phone is not in the
  /// local contacts ("+phone ~SenderName").
  final String senderName;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;

  /// Indicates the kind of media carried by this message.
  final MessageType type;

  /// CDN-relative path returned by POST /chat/upload.
  /// Combine with the Dio base URL to form the full URL.
  final String? fileUrl;

  /// Flexible metadata bag stored as JSON in SQLite.
  /// Keys vary by type:
  ///   image      : { mimeType }
  ///   file       : { fileName, fileSize, mimeType }
  ///   voice_note : { duration, mimeType }
  ///   contact    : { contactName, contactPhone }
  final Map<String, dynamic>? metadata;

  /// FR-022: True if this message has been soft-deleted ("This message was deleted").
  final bool isDeleted;

  /// US3: Returns the absolute URL for media files, resolving relative paths
  /// against the API base URL.
  String get resolvedFileUrl => UrlUtils.resolveMediaUrl(fileUrl);

  const Message({
    required this.id,
    required this.clientMessageId,
    required this.roomId,
    required this.senderId,
    this.senderPhone = '',
    this.senderName = '',
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.pending,
    this.type = MessageType.text,
    this.fileUrl,
    this.metadata,
    this.isDeleted = false,
  });

  Message copyWith({
    String? id,
    String? clientMessageId,
    String? roomId,
    String? senderId,
    String? senderPhone,
    String? senderName,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    MessageType? type,
    String? fileUrl,
    Map<String, dynamic>? metadata,
    bool? isDeleted,
  }) {
    return Message(
      id: id ?? this.id,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderPhone: senderPhone ?? this.senderPhone,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      metadata: metadata ?? this.metadata,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_message_id': clientMessageId,
      'room_id': roomId,
      'sender_id': senderId,
      'sender_phone': senderPhone,
      'sender_name': senderName,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
      'type': messageTypeToString(type),
      'file_url': fileUrl ?? '',
      'metadata': metadata != null ? jsonEncode(metadata) : '',
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? parsedMeta;
    final rawMeta = map['metadata'] as String?;
    if (rawMeta != null && rawMeta.isNotEmpty) {
      try {
        parsedMeta = jsonDecode(rawMeta) as Map<String, dynamic>;
      } catch (_) {
        parsedMeta = null;
      }
    }

    return Message(
      id: map['id'] ?? '',
      clientMessageId: map['client_message_id'] ?? map['id'] ?? '',
      roomId: map['room_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      senderPhone: map['sender_phone'] as String? ?? '',
      senderName: map['sender_name'] as String? ?? '',
      text: map['text'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.pending,
      ),
      type: messageTypeFromString(map['type'] as String?),
      fileUrl: (map['file_url'] as String?)?.isNotEmpty == true
          ? map['file_url'] as String
          : null,
      metadata: parsedMeta,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }
  factory Message.fromNetworkMap(Map<String, dynamic> map) {
    Map<String, dynamic>? parsedMeta;
    final metaDataField = map['metadata'];

    if (metaDataField is Map) {
      parsedMeta = Map<String, dynamic>.from(metaDataField);
    } else if (metaDataField is String && metaDataField.isNotEmpty) {
      try {
        parsedMeta = jsonDecode(metaDataField) as Map<String, dynamic>;
      } catch (_) {
        parsedMeta = null;
      }
    }
    final rawSender = map['senderId'];
    final String senderId;
    final String senderPhone;
    final String senderName;
    if (rawSender is Map) {
      senderId = (rawSender['_id'] ?? '').toString();
      senderPhone = (rawSender['phoneNumber'] ?? '').toString();
      senderName = (rawSender['name'] ?? '').toString();
    } else {
      senderId = (rawSender ?? '').toString();
      senderPhone = (map['senderPhone'] ?? '').toString();
      senderName = (map['senderName'] ?? '').toString();
    }
    return Message(
      id: map['_id'] ?? '',
      clientMessageId: map['clientMessageId'] ?? map['id'] ?? '',
      roomId: map['chatRoomId'] ?? '',
      senderId: senderId,
      senderPhone: senderPhone,
      senderName: senderName,
      text: map['content'] ?? '',
      timestamp: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.pending,
      ),
      type: messageTypeFromString(map['messageType'] as String?),
      fileUrl: (map['fileUrl'] as String?)?.isNotEmpty == true
          ? map['fileUrl'] as String
          : null,
      metadata: parsedMeta,
    );
  }
  @override
  List<Object?> get props => [
    id,
    clientMessageId,
    roomId,
    senderId,
    senderPhone,
    senderName,
    text,
    timestamp,
    status,
    type,
    fileUrl,
    metadata,
    isDeleted,
  ];
}
