import '../../domain/entities/recording.dart';

class RecordingModel extends Recording {
  const RecordingModel({
    required super.id,
    required super.callRoomId,
    required super.callRoomName,
    required super.filePath,
    required super.durationMs,
    required super.hasVideo,
    required super.sizeBytes,
    required super.createdAt,
    required super.displayName,
  });

  factory RecordingModel.fromMap(Map<String, dynamic> map) {
    return RecordingModel(
      id: map['id'] as String,
      callRoomId: map['call_room_id'] as String,
      callRoomName: map['call_room_name'] as String,
      filePath: map['file_path'] as String,
      durationMs: map['duration_ms'] as int,
      hasVideo: (map['has_video'] as int) == 1,
      sizeBytes: map['size_bytes'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      displayName: map['display_name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'call_room_id': callRoomId,
      'call_room_name': callRoomName,
      'file_path': filePath,
      'duration_ms': durationMs,
      'has_video': hasVideo ? 1 : 0,
      'size_bytes': sizeBytes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'display_name': displayName,
    };
  }

  factory RecordingModel.fromEntity(Recording r) {
    return RecordingModel(
      id: r.id,
      callRoomId: r.callRoomId,
      callRoomName: r.callRoomName,
      filePath: r.filePath,
      durationMs: r.durationMs,
      hasVideo: r.hasVideo,
      sizeBytes: r.sizeBytes,
      createdAt: r.createdAt,
      displayName: r.displayName,
    );
  }
}
