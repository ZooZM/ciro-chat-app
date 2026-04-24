# Research: Optimize Chat Lifecycle (Phase 2)

**Branch**: `003-optimize-chat-lifecycle` | **Date**: 2026-04-25

## R1: Group Chat Persistence Bug — Root Cause

**Decision**: The root cause is in `ChatLocalDataSourceImpl.saveMessage()` (lines 191–220). The SQL UPSERT for the `rooms` table does NOT include `type`, `participants`, or `admins` columns. When a message creates/updates a "ghost" room row, `type` defaults to `'PRIVATE'` (from the SQLite schema DEFAULT).

**Evidence**:
```sql
-- Current UPSERT in saveMessage() — MISSING type, participants, admins:
INSERT OR REPLACE INTO rooms
  (id, name, avatarUrl, phoneNumber, lastMessage, timestamp, unreadCount, isOnline, lastMessageSenderId, lastMessageStatus)
VALUES (...)
```

**Fix**: Extend the UPSERT to include `COALESCE((SELECT type FROM rooms WHERE id = ?), 'PRIVATE')` and similarly for `participants` and `admins`. This preserves existing values during message-driven upserts.

**Alternatives Considered**:
- *Option: Separate room creation from message saving* — Rejected because it requires refactoring the JIT room creation flow and breaks the current "message auto-creates room" pattern.

---

## R2: System Message Type — Frontend Gap

**Decision**: Add `MessageType.system` to the Flutter `MessageType` enum and a `case 'system':` branch to `messageTypeFromString()`. Render system messages as centered, styled event bubbles (no avatar, no alignment, no status ticks).

**Backend Evidence**: `MessageType.SYSTEM = 'system'` in `message.schema.ts:10`. Sentinel `senderId`: `ObjectId('000000000000000000000000')`. Event text lives in `content`.

**Rationale**: The backend already uses `SYSTEM` for group events (create, add, remove, leave, admin promotion). The frontend silently maps them to `text` and renders broken bubbles because the sender ID doesn't match any participant.

---

## R3: Location & Audio — Backend Schema Extension

**Decision**: Add `LOCATION = 'location'` and `AUDIO = 'audio'` to the backend `MessageType` enum. Also extend `MessageMetadata` with `latitude?`, `longitude?`, `address?` fields.

**Rationale**: Reusing `file` type with metadata differentiation was considered but rejected by the user in favor of explicit types for cleaner separation.

**Changes Required**:
1. `message.schema.ts` → Add `LOCATION` and `AUDIO` to `MessageType` enum
2. `MessageMetadata` → Add `latitude?: number`, `longitude?: number`, `address?: string`
3. `send-message.dto.ts` → Already supports `@IsOptional() @IsEnum(MessageType) type` — no changes needed
4. Flutter `message.dart` → Add `location`, `audio` to `MessageType` enum and `messageTypeFromString()`

---

## R4: Poll & Event — Backend Schema Extension

**Decision**: Add `POLL = 'poll'` and `EVENT = 'event'` to the backend `MessageType` enum. Extend `MessageMetadata` with:
- Poll: `question?: string`, `options?: string[]`, `votes?: Record<string, string[]>` (optionIndex → userId[])
- Event: `title?: string`, `dateTime?: string`, `description?: string`

**Rationale**: Poll is group-only. Both types use the existing flexible `metadata` bag pattern. The `SendMessageDto` already accepts arbitrary metadata.

**Poll Vote Mechanism**: Initial implementation stores votes in message metadata. A dedicated socket event (`vote_poll`) can be added later for real-time vote counting. For now, votes will be stored as part of the message metadata and updated via a REST endpoint.

---

## R5: Google Maps Integration

**Decision**: Use `google_maps_flutter` package for the location picker UI. Use Google Maps Static API for chat bubble thumbnails.

**Dependencies**:
- `google_maps_flutter: ^2.x` (add to `pubspec.yaml`)
- `geolocator: ^12.x` (for getting current position)
- `geocoding: ^3.x` (for reverse geocoding — lat/lng to address)
- `flutter_dotenv: ^5.x` (for `.env` file loading)

**Platform Setup**:
- Android: Add Google Maps API key to `AndroidManifest.xml`
- iOS: Add Google Maps API key to `AppDelegate.swift` and `Info.plist`
- Both: Add location permissions

**Thumbnail URL**: `https://maps.googleapis.com/maps/api/staticmap?center={lat},{lng}&zoom=15&size=300x200&markers=color:red%7C{lat},{lng}&key={API_KEY}`

---

## R6: Voice Note Stability — Known Issues

**Decision**: Audit and fix voice note lifecycle. Key areas:
1. `record` package — ensure `stop()` is always called before `dispose()`
2. `just_audio` / `audioplayers` — ensure only one player active at a time (singleton pattern)
3. `audio_waveforms` — ensure controller is disposed in widget `dispose()`

**Current State**: The app uses `record: ^6.2.0`, `just_audio: ^0.9.42`, and `audio_waveforms: ^2.0.2`. Potential state leak: if the user navigates away mid-recording, the recorder may not be stopped.

---

## R7: Existing Attachment Handlers — Gap Analysis

**Decision**: The following handlers already exist in `AttachmentSheetWidget`:
| Action | Handler | Status |
|--------|---------|--------|
| Gallery | `_handleGallery` → `ChatCubit.sendImageMessage` | ✅ Implemented |
| Document | `_handleDocument` → `ChatCubit.sendFileMessage` | ✅ Implemented |
| Contact | `_handleContact` → `ChatCubit.sendContactMessage` | ✅ Implemented |
| Camera | Missing handler | ❌ Needs implementation |
| Location | Missing handler | ❌ Needs implementation |
| Audio | Missing handler | ❌ Needs implementation |
| Poll | Missing handler | ❌ Needs implementation (group-only) |
| Event | Missing handler | ❌ Needs implementation |

**Camera**: Can reuse `image_picker` (already in pubspec) with `ImageSource.camera` instead of `ImageSource.gallery`.

---

## R8: Static/Mock Data Scan — Preliminary Findings

**Decision**: Key areas to audit:
1. `_mediaPreview()` in `chat_local_data_source.dart` — does not handle `system`, `location`, `audio`, `poll`, `event` types
2. `_buildMediaSection()` in `group_info_page.dart` — uses hardcoded `itemCount: 4` placeholder thumbnails
3. `_buildDescriptionTile()` in `group_info_page.dart` — static text "Add description for group" with no dynamic binding
4. `chat_screen.dart.bak` — orphan backup file should be deleted
5. Multiple `Colors.*` literals remain in `group_info_page.dart` and `attachment_sheet_widget.dart`