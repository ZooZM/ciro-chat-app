import 'dart:convert';
import 'package:equatable/equatable.dart';

enum MessageStatus { pending, sent, delivered, read, error }

enum MessageType { text, image, file, voiceNote, contact }

/// Maps a raw string from SQLite / socket payload to a [MessageType].
/// Falls back to [MessageType.text] for any unknown / null value.
MessageType messageTypeFromString(String? raw) {
  switch (raw) {
    case 'image':
      return MessageType.image;
    case 'file':
      return MessageType.file;
    case 'voice_note':
      return MessageType.voiceNote;
    case 'contact':
      return MessageType.contact;
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
    case MessageType.contact:
      return 'contact';
    case MessageType.text:
      return 'text';
  }
}

class Message extends Equatable {
  final String id;
  final String clientMessageId;
  final String roomId;
  final String senderId;
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

  const Message({
    required this.id,
    required this.clientMessageId,
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.pending,
    this.type = MessageType.text,
    this.fileUrl,
    this.metadata,
  });

  Message copyWith({
    String? id,
    String? clientMessageId,
    String? roomId,
    String? senderId,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    MessageType? type,
    String? fileUrl,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_message_id': clientMessageId,
      'room_id': roomId,
      'sender_id': senderId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
      'type': messageTypeToString(type),
      'file_url': fileUrl ?? '',
      'metadata': metadata != null ? jsonEncode(metadata) : '',
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
    );
  }

  @override
  List<Object?> get props => [
        id,
        clientMessageId,
        roomId,
        senderId,
        text,
        timestamp,
        status,
        type,
        fileUrl,
        metadata,
      ];
}
