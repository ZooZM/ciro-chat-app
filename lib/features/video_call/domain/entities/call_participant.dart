import 'package:equatable/equatable.dart';

/// Represents a participant currently in a group call.
class CallParticipant extends Equatable {
  final String userId;
  final String phoneNumber;
  final String displayName;
  final String avatarUrl;
  final bool isMicMuted;
  final bool isVideoOn;
  final bool isSpeaking;
  final DateTime joinedAt;

  const CallParticipant({
    required this.userId,
    required this.phoneNumber,
    this.displayName = '',
    this.avatarUrl = '',
    this.isMicMuted = false,
    this.isVideoOn = true,
    this.isSpeaking = false,
    required this.joinedAt,
  });

  CallParticipant copyWith({
    String? userId,
    String? phoneNumber,
    String? displayName,
    String? avatarUrl,
    bool? isMicMuted,
    bool? isVideoOn,
    bool? isSpeaking,
    DateTime? joinedAt,
  }) {
    return CallParticipant(
      userId: userId ?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  List<Object?> get props => [userId, phoneNumber, isMicMuted, isVideoOn, isSpeaking];
}

/// Whether a recording is in progress and who started it.
class RecordingState extends Equatable {
  final bool isRecording;
  final String? recorderId;

  const RecordingState({this.isRecording = false, this.recorderId});

  static const inactive = RecordingState();

  @override
  List<Object?> get props => [isRecording, recorderId];
}
