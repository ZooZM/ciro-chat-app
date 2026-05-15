import 'package:equatable/equatable.dart';

class Recording extends Equatable {
  final String id;
  final String callRoomId;
  final String callRoomName;
  final String filePath;
  final int durationMs;
  final bool hasVideo;
  final int sizeBytes;
  final DateTime createdAt;
  final String displayName;

  const Recording({
    required this.id,
    required this.callRoomId,
    required this.callRoomName,
    required this.filePath,
    required this.durationMs,
    required this.hasVideo,
    required this.sizeBytes,
    required this.createdAt,
    required this.displayName,
  });

  Recording copyWith({
    String? id,
    String? callRoomId,
    String? callRoomName,
    String? filePath,
    int? durationMs,
    bool? hasVideo,
    int? sizeBytes,
    DateTime? createdAt,
    String? displayName,
  }) {
    return Recording(
      id: id ?? this.id,
      callRoomId: callRoomId ?? this.callRoomId,
      callRoomName: callRoomName ?? this.callRoomName,
      filePath: filePath ?? this.filePath,
      durationMs: durationMs ?? this.durationMs,
      hasVideo: hasVideo ?? this.hasVideo,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  List<Object?> get props => [id, callRoomId, filePath, durationMs, hasVideo, sizeBytes, createdAt, displayName];
}
