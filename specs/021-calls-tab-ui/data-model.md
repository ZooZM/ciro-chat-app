# Data Model: Calls Tab UI

**Feature**: 021-calls-tab-ui  
**Date**: 2026-07-04

## Entities

### CallHistoryRecord (existing — no changes)

Already defined in `lib/features/call_history/domain/entities/call_history_record.dart`.

| Field | Type | Description |
|-------|------|-------------|
| id | String | Local UUID; CallKit correlation id for 1:1 calls |
| contactUserId | String | Remote user id (1:1) or chat room id (group) |
| contactName | String | Display name of the contact |
| avatarUrl | String? | Optional profile image URL |
| avatarColorSeed | int | Deterministic seed for initials-avatar background color |
| direction | CallDirection | `incoming` or `outgoing` |
| outcome | CallOutcome | `answered`, `missed`, or `declined` |
| callType | CallType | `voice` or `video` |
| isGroup | bool | Whether this is a group call |
| startedAt | int | Epoch milliseconds; primary sort key (DESC) |
| durationSeconds | int | Duration; 0 for missed/declined |

**Computed Properties**:
- `isMissed` → `outcome == CallOutcome.missed`
- `initials` → two-letter initials from `contactName`

### MockContact (new — mock data only)

Used exclusively by the Select Contact screen. Not persisted.

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique identifier |
| name | String | Display name |
| avatarUrl | String? | Optional avatar URL (null for initials-only) |
| initials | String | Two-letter initials derived from name |
| avatarColorSeed | int | Color palette index |

### CallDetailEntry (new — mock data only)

Used by the Call Information screen for the date-grouped call log section.

| Field | Type | Description |
|-------|------|-------------|
| direction | CallDirection | `incoming` or `outgoing` |
| time | String | Formatted time string (e.g., "9:16 PM") |
| status | String | Status label (e.g., "Not answer", "Answered", "2 min") |
| callType | CallType | `voice` or `video` |

## Mock Data Sets

### mockCallHistory
A `List<CallHistoryRecord>` with 8+ entries matching the screenshots:
- Test (missed incoming video, Today 1:10 AM)
- Ahmed Khaled (missed incoming voice, Yesterday 2:12 PM)
- Layla Ibrahim (outgoing video, Yesterday 2:12 PM)
- Yara Mostafa (outgoing voice, Yesterday 6:30 PM)
- Amr Mohamed (outgoing voice, Yesterday 8:42 PM)
- Omar Hassan (outgoing voice, Yesterday 8:42 PM)
- Mahmoud Reda (outgoing video, Yesterday 8:42 PM)
- Tamer Ahmed (outgoing voice, Yesterday 6:30 PM)

### mockContacts
A `List<MockContact>` with entries for both "Frequently contacted" and "contact" sections:
- Frequently contacted: Layla Ibrahim, Yara Mostafa, Amr Mohamed
- Contact: Amr Mohamed, Omar Hassan, Mahmoud Reda, Tamer Ahmed, Yara Mostafa

## State Transitions

No state machines needed. The Select Contact screen uses simple `bool isSelected` per contact, managed by local `StatefulWidget` state. Only one contact can be selected at a time.
