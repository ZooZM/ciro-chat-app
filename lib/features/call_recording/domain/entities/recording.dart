import 'package:equatable/equatable.dart';

// FR-035: tracks where a recording is in the share pipeline
enum ShareStatus { idle, uploading, shared, failed }

class Recording extends Equatable {
  final String id;
  final String callRoomId;
  final String callRoomName;
  final String filePath;
  final String? galleryPath;
  final int durationMs;
  final bool hasVideo;
  final int sizeBytes;
  final DateTime createdAt;
  final String displayName;
  final ShareStatus shareStatus;
  final String? sharedMessageId;

  const Recording({
    required this.id,
    required this.callRoomId,
    required this.callRoomName,
    required this.filePath,
    this.galleryPath,
    required this.durationMs,
    required this.hasVideo,
    required this.sizeBytes,
    required this.createdAt,
    required this.displayName,
    this.shareStatus = ShareStatus.idle,
    this.sharedMessageId,
  });

  Recording copyWith({
    String? id,
    String? callRoomId,
    String? callRoomName,
    String? filePath,
    String? galleryPath,
    int? durationMs,
    bool? hasVideo,
    int? sizeBytes,
    DateTime? createdAt,
    String? displayName,
    ShareStatus? shareStatus,
    String? sharedMessageId,
  }) {
    return Recording(
      id: id ?? this.id,
      callRoomId: callRoomId ?? this.callRoomId,
      callRoomName: callRoomName ?? this.callRoomName,
      filePath: filePath ?? this.filePath,
      galleryPath: galleryPath ?? this.galleryPath,
      durationMs: durationMs ?? this.durationMs,
      hasVideo: hasVideo ?? this.hasVideo,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
      shareStatus: shareStatus ?? this.shareStatus,
      sharedMessageId: sharedMessageId ?? this.sharedMessageId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        callRoomId,
        filePath,
        galleryPath,
        durationMs,
        hasVideo,
        sizeBytes,
        createdAt,
        displayName,
        shareStatus,
        sharedMessageId,
      ];
}
