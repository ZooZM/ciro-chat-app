import 'package:equatable/equatable.dart';

/// Whether the call was placed by us or received.
enum CallDirection { incoming, outgoing }

/// Terminal outcome of a call (drives the red "missed" treatment).
enum CallOutcome { answered, missed, declined }

/// Media type of the call.
enum CallType { voice, video }

/// A single entry surfaced in the in-app Calls history screen (FR-VoIP-04/05).
/// Persisted in the `call_history` sqflite table (data-model.md).
class CallHistoryRecord extends Equatable {
  /// Local UUID; for 1:1 calls this is also the CallKit correlation id.
  final String id;

  /// Remote user id (1:1) or chat room id (group).
  final String contactUserId;
  final String contactName;
  final String? avatarUrl;

  /// Deterministic seed used to pick the initials-avatar background color.
  final int avatarColorSeed;

  final CallDirection direction;
  final CallOutcome outcome;
  final CallType callType;
  final bool isGroup;

  /// Epoch milliseconds; primary sort key (DESC).
  final int startedAt;

  /// 0 for missed/declined.
  final int durationSeconds;

  const CallHistoryRecord({
    required this.id,
    required this.contactUserId,
    required this.contactName,
    this.avatarUrl,
    this.avatarColorSeed = 0,
    required this.direction,
    required this.outcome,
    required this.callType,
    this.isGroup = false,
    required this.startedAt,
    this.durationSeconds = 0,
  });

  bool get isMissed => outcome == CallOutcome.missed;

  /// Up-to-two-letter initials derived from the contact name.
  String get initials {
    final parts = contactName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  List<Object?> get props => [
        id,
        contactUserId,
        contactName,
        avatarUrl,
        avatarColorSeed,
        direction,
        outcome,
        callType,
        isGroup,
        startedAt,
        durationSeconds,
      ];
}
