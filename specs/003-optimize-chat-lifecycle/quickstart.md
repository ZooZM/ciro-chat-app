# Quickstart: Optimize Chat Lifecycle (P2P Focus Update)

**Date**: April 30, 2026 (Updated)

## Prerequisites

- Flutter SDK 3.x installed
- Android emulator or device connected
- NestJS backend running at configured URL
- `.env` file with `GOOGLE_MAPS_API_KEY` at project root
- Backend codebase at `E:\zeyad\chat-app-backend` accessible for FR-021 and FR-022 changes

## New Dependencies to Add

```yaml
# pubspec.yaml — add if not already present
dependencies:
  video_player: ^2.8.0        # US12: Video message playback
  video_thumbnail: ^0.5.3     # US12: Generate video thumbnails
```

## Quick Implementation Order (P2P Focus)

### Priority P0 — Critical Bug Fixes (Ship First)

1. **Phase A** (FR-019 — Idempotency): Fix `saveMessage()` dedup by `clientMessageId`, fix `updateMessageStatus()` to query by `clientMessageId`, add monotonic status guard
2. **Phase A** (FR-020 — Scoped Status): Add `last_message_id` + `last_message_sender_id` to rooms schema, scope tick icons to sender only
3. **Phase B** (FR-018 — Pagination): Add `limit`/`offset` to `getRoomMessages()`, implement `loadMoreMessages()` in ChatCubit, add scroll listener

### Priority P1 — Important Features

4. **Phase C** (FR-021 — Atomic JIT): Backend atomic resolve endpoint, remove 300ms delay hack
5. **Phase D** (FR-022 — Deletion): Add `is_deleted` column, implement dual-mode delete, new socket events
6. **Phase G** (FR-025 — Waveform): Sender-side extraction at record time, include in socket payload, receiver renders from cache

### Priority P2 — UI Enhancements

7. **Phase E** (FR-023 — UI Refactor): Poll/Event creation dialogs and message bubbles matching WhatsApp reference images
8. **Phase F** (FR-024 — Media Screen): SharedMediaScreen with 3 tabs, navigation from ChatInfoScreen

### Already Completed (Previous Phases)

- [x] US11: Waveform cache storage in metadata (R1)
- [x] US12: Video message send/receive + MediaGalleryViewer
- [x] US13: Resend failed messages
- [x] US14: Block/unblock user (backend + frontend)
- [x] US15: In-chat search
- [x] US16: ChatInfoScreen real data
- [x] US17: Splash preload
- [x] C1: Audio crash on back-press — `PopScope` + skip `PlayerController.dispose()`
- [x] D1: Location crash — `LocationService` in `core/services/`
- [x] F1: ChatInfoScreen hardcoded colors — migrated to `AppColors`/`AppConstants`

## SQLite Migrations Required

```sql
-- Migration 1: Message deletion support (FR-022)
ALTER TABLE messages ADD COLUMN is_deleted INTEGER DEFAULT 0;

-- Migration 2: Scoped inbox status (FR-020)
ALTER TABLE rooms ADD COLUMN last_message_id TEXT DEFAULT '';
ALTER TABLE rooms ADD COLUMN last_message_sender_id TEXT DEFAULT '';
```

## Backend Changes Required

| Change | File | FR |
|--------|------|----|
| Update resolve endpoint to accept `firstMessage` | `chat.controller.ts`, `chat.service.ts` | FR-021 |
| Add `isDeleted: Boolean` to message schema | `message.schema.ts` | FR-022 |
| Add `deleteForEveryone` socket handler | `chat.gateway.ts` | FR-022 |
| Broadcast `messageDeleted` event | `chat.gateway.ts` | FR-022 |

## Verification

```bash
# Run static analysis
flutter analyze

# Check for remaining hardcoded values
grep -rn "Colors\." lib/features/chat/
grep -rn "Color(0x" lib/features/chat/

# Check for TODO/FIXME markers
grep -rn "TODO\|FIXME\|HACK\|XXX" lib/features/chat/

# Verify no Future.delayed hacks remain
grep -rn "Future.delayed" lib/features/chat/

# Verify idempotency — no ConflictAlgorithm.replace on messages
grep -rn "ConflictAlgorithm.replace" lib/features/chat/
```
