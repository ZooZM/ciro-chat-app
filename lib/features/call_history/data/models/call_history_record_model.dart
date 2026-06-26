import '../../domain/entities/call_history_record.dart';

/// DTO mapping [CallHistoryRecord] to/from the `call_history` sqflite row.
class CallHistoryRecordModel extends CallHistoryRecord {
  const CallHistoryRecordModel({
    required super.id,
    required super.contactUserId,
    required super.contactName,
    super.avatarUrl,
    super.avatarColorSeed,
    required super.direction,
    required super.outcome,
    required super.callType,
    super.isGroup,
    required super.startedAt,
    super.durationSeconds,
  });

  factory CallHistoryRecordModel.fromEntity(CallHistoryRecord r) =>
      CallHistoryRecordModel(
        id: r.id,
        contactUserId: r.contactUserId,
        contactName: r.contactName,
        avatarUrl: r.avatarUrl,
        avatarColorSeed: r.avatarColorSeed,
        direction: r.direction,
        outcome: r.outcome,
        callType: r.callType,
        isGroup: r.isGroup,
        startedAt: r.startedAt,
        durationSeconds: r.durationSeconds,
      );

  factory CallHistoryRecordModel.fromMap(Map<String, dynamic> map) =>
      CallHistoryRecordModel(
        id: map['id'] as String,
        contactUserId: map['contact_user_id'] as String? ?? '',
        contactName: map['contact_name'] as String? ?? 'Unknown',
        avatarUrl: map['avatar_url'] as String?,
        avatarColorSeed: (map['avatar_color_seed'] as int?) ?? 0,
        direction: _directionFrom(map['direction'] as String?),
        outcome: _outcomeFrom(map['outcome'] as String?),
        callType: _typeFrom(map['call_type'] as String?),
        isGroup: (map['is_group'] as int?) == 1,
        startedAt: (map['started_at'] as int?) ?? 0,
        durationSeconds: (map['duration_seconds'] as int?) ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'contact_user_id': contactUserId,
        'contact_name': contactName,
        'avatar_url': avatarUrl,
        'avatar_color_seed': avatarColorSeed,
        'direction': direction.name,
        'outcome': outcome.name,
        'call_type': callType.name,
        'is_group': isGroup ? 1 : 0,
        'started_at': startedAt,
        'duration_seconds': durationSeconds,
      };

  static CallDirection _directionFrom(String? v) =>
      v == 'outgoing' ? CallDirection.outgoing : CallDirection.incoming;

  static CallOutcome _outcomeFrom(String? v) => switch (v) {
        'answered' => CallOutcome.answered,
        'declined' => CallOutcome.declined,
        _ => CallOutcome.missed,
      };

  static CallType _typeFrom(String? v) =>
      v == 'video' ? CallType.video : CallType.voice;
}
