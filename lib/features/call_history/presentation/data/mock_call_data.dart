import 'package:flutter/material.dart';
import '../../domain/entities/call_history_record.dart';

const List<Color> kAvatarPalette = [
  Color(0xFFE91E63), // Pink
  Color(0xFF9C27B0), // Purple
  Color(0xFF673AB7), // Deep Purple
  Color(0xFF3F51B5), // Indigo
  Color(0xFF2196F3), // Blue
  Color(0xFF03A9F4), // Light Blue
  Color(0xFF00BCD4), // Cyan
  Color(0xFF009688), // Teal
  Color(0xFF4CAF50), // Green
  Color(0xFF8BC34A), // Light Green
  Color(0xFFCDDC39), // Lime
  Color(0xFFFFEB3B), // Yellow
  Color(0xFFFFC107), // Amber
  Color(0xFFFF9800), // Orange
  Color(0xFFFF5722), // Deep Orange
  Color(0xFF795548), // Brown
  Color(0xFF9E9E9E), // Grey
  Color(0xFF607D8B), // Blue Grey
];

class MockContact {
  final String id;
  final String name;
  final String? avatarUrl;
  final int avatarColorSeed;

  const MockContact({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.avatarColorSeed,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class CallDetailEntry {
  final CallDirection direction;
  final String time;
  final String status;
  final CallType callType;

  const CallDetailEntry({
    required this.direction,
    required this.time,
    required this.status,
    required this.callType,
  });
}

// ---------------------------------------------------------------------------
// Mock Data Sets
// ---------------------------------------------------------------------------

final int _now = DateTime.now().millisecondsSinceEpoch;
final int _oneHour = 3600000;
final int _oneDay = 86400000;

final List<CallHistoryRecord> mockCallHistory = [
  CallHistoryRecord(
    id: 'msg_1',
    contactUserId: 'u_1',
    contactName: 'Test',
    avatarColorSeed: 12, // Yellowish
    direction: CallDirection.incoming,
    outcome: CallOutcome.missed,
    callType: CallType.video,
    startedAt: _now - _oneHour * 22, // roughly "Today 1:10 AM"
  ),
  CallHistoryRecord(
    id: 'msg_2',
    contactUserId: 'u_2',
    contactName: 'Ahmed Khaled',
    avatarColorSeed: 16, // Greyish
    direction: CallDirection.incoming,
    outcome: CallOutcome.missed,
    callType: CallType.voice,
    startedAt: _now - _oneDay - _oneHour * 9, // roughly "Yesterday 2:12 PM"
  ),
  CallHistoryRecord(
    id: 'msg_3',
    contactUserId: 'u_3',
    contactName: 'Layla Ibrahim',
    avatarColorSeed: 0, // Pink
    direction: CallDirection.outgoing,
    outcome: CallOutcome.answered,
    callType: CallType.video,
    startedAt: _now - _oneDay - _oneHour * 9,
  ),
  CallHistoryRecord(
    id: 'msg_4',
    contactUserId: 'u_4',
    contactName: 'Yara Mostafa',
    avatarColorSeed: 4, // Blue
    direction: CallDirection.outgoing,
    outcome: CallOutcome.answered,
    callType: CallType.voice,
    startedAt: _now - _oneDay - _oneHour * 5,
  ),
  CallHistoryRecord(
    id: 'msg_5',
    contactUserId: 'u_5',
    contactName: 'Amr Mohamed',
    avatarColorSeed: 1, // Purple
    direction: CallDirection.outgoing,
    outcome: CallOutcome.answered,
    callType: CallType.voice,
    startedAt: _now - _oneDay - _oneHour * 3,
  ),
  CallHistoryRecord(
    id: 'msg_6',
    contactUserId: 'u_6',
    contactName: 'Omar Hassan',
    avatarColorSeed: 8, // Green
    direction: CallDirection.outgoing,
    outcome: CallOutcome.answered,
    callType: CallType.voice,
    startedAt: _now - _oneDay - _oneHour * 3,
  ),
  CallHistoryRecord(
    id: 'msg_7',
    contactUserId: 'u_7',
    contactName: 'Mahmoud Reda',
    avatarColorSeed: 14, // Deep Orange
    direction: CallDirection.outgoing,
    outcome: CallOutcome.answered,
    callType: CallType.video,
    startedAt: _now - _oneDay - _oneHour * 3,
  ),
  CallHistoryRecord(
    id: 'msg_8',
    contactUserId: 'u_8',
    contactName: 'Tamer Ahmed',
    avatarColorSeed: 7, // Teal
    direction: CallDirection.outgoing,
    outcome: CallOutcome.answered,
    callType: CallType.voice,
    startedAt: _now - _oneDay - _oneHour * 5,
  ),
];

const List<MockContact> mockFrequentContacts = [
  MockContact(id: 'u_3', name: 'Layla Ibrahim', avatarColorSeed: 0),
  MockContact(id: 'u_4', name: 'Yara Mostafa', avatarColorSeed: 4),
  MockContact(id: 'u_5', name: 'Amr Mohamed', avatarColorSeed: 1),
];

const List<MockContact> mockAllContacts = [
  MockContact(id: 'u_5', name: 'Amr Mohamed', avatarColorSeed: 1),
  MockContact(id: 'u_6', name: 'Omar Hassan', avatarColorSeed: 8),
  MockContact(id: 'u_7', name: 'Mahmoud Reda', avatarColorSeed: 14),
  MockContact(id: 'u_8', name: 'Tamer Ahmed', avatarColorSeed: 7),
  MockContact(id: 'u_4', name: 'Yara Mostafa', avatarColorSeed: 4),
];

final Map<String, List<CallDetailEntry>> mockCallDetails = {
  'u_1': [
    const CallDetailEntry(
      direction: CallDirection.incoming,
      time: '1:10 AM',
      status: 'Not answer',
      callType: CallType.video,
    ),
  ],
  'u_3': [
    const CallDetailEntry(
      direction: CallDirection.outgoing,
      time: '2:12 PM',
      status: '2 min',
      callType: CallType.video,
    ),
  ],
};

List<CallDetailEntry> getMockCallDetails(String userId) {
  return mockCallDetails[userId] ??
      [
        const CallDetailEntry(
          direction: CallDirection.outgoing,
          time: '10:00 AM',
          status: '5 min',
          callType: CallType.voice,
        ),
      ];
}
