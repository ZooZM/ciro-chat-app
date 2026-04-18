import 'package:equatable/equatable.dart';

enum MessageStatus { pending, sent, delivered, read, error }

class Message extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;

  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.pending,
  });

  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      roomId: map['room_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      text: map['text'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.pending,
      ),
    );
  }

  @override
  List<Object?> get props => [id, roomId, senderId, text, timestamp, status];
}
