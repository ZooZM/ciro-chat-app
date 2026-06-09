# Research: Optimize Chat Lifecycle (Expanded)

**Date**: April 30, 2026 (Updated)
**Feature**: [spec.md](spec.md)

## R1: Audio Waveform Caching Strategy

**Decision**: Store extracted waveform samples as `List<double>` in the message's SQLite `metadata` JSON column under the key `waveformSamples`.

**Rationale**: The `audio_waveforms` package's `PlayerController.extractWaveformData()` returns `List<double>`. Storing this in the existing `metadata` column avoids schema migration and keeps the data co-located with the message. SQLite JSON storage is efficient for lists of 100-200 floats.

**Alternatives considered**:
- Separate SQLite table for waveforms → rejected (over-engineering, adds JOIN complexity)
- File-based cache → rejected (harder to manage lifecycle, no auto-cleanup on message delete)
- Hive key-value → rejected (constitution mandates SQLite for relational data)

## R2: Video Message Implementation

**Decision**: Use `image_picker` for video selection (already a dependency for camera), `video_player` for playback, and the existing `POST /chat/upload` endpoint for upload. Thumbnail generated client-side using `video_thumbnail` package.

**Rationale**: `image_picker` already handles gallery selection for images; adding `MediaType.video` is a configuration change. `video_player` is the official Flutter team package. Server-side thumbnail generation would require `ffmpeg` on the backend — unnecessary complexity.

**Alternatives considered**:
- `chewie` for playback → viable but adds another dependency; `video_player` is sufficient for inline play
- Server-side thumbnail → rejected (requires backend ffmpeg, adds latency)
- `file_picker` for video → rejected (image_picker already supports video)

## R3: Resend Failed Messages

**Decision**: Reuse the existing `sendLocalMessage()` flow with the original `clientMessageId`. The idempotency guarantee on the backend (duplicate `clientMessageId` is rejected) ensures no double-sends.

**Rationale**: The message is already persisted in SQLite with status `error`. Resending just needs to: (1) update status to `pending`, (2) re-emit via socket with the same payload. The backend's idempotency check via `clientMessageId` prevents duplicates even if the original was partially processed.

**Alternatives considered**:
- Create a new message with new `clientMessageId` → rejected (could cause duplicates if original was partially delivered)
- Queue-based retry with exponential backoff → over-engineering for user-initiated retry

## R4: Block User Architecture

**Decision**: Backend stores `blockedUsers: ObjectId[]` on the User schema. REST endpoints for CRUD. Socket gateway checks block list before delivering messages. Frontend syncs block list on login and caches in memory.

**Rationale**: Storing on the User schema is simpler than a separate `BlockRelationship` collection. The block check in the socket gateway prevents real-time message delivery. REST endpoints allow the frontend to manage blocks without socket dependency.

**Alternatives considered**:
- Separate `blocks` MongoDB collection → viable for scale but unnecessary for current user count
- Socket-only block management → rejected (no offline support)
- Client-side filtering → rejected (blocked user's messages still consume bandwidth)

## R5: In-Chat Search

**Decision**: SQLite `LIKE` query on the `text` column filtered by `roomId`. Results displayed in a search bar overlay at the top of the chat room.

**Rationale**: Messages are already stored in SQLite. A `LIKE '%query%'` query is sufficient for conversations up to 10,000 messages (SC-015 target). FTS5 (full-text search) is available in sqflite but adds complexity — defer to a future optimization if performance is insufficient.

**Alternatives considered**:
- SQLite FTS5 → deferred (LIKE is sufficient for current scale)
- Server-side search → rejected (adds latency, requires network)
- In-memory search of loaded messages → rejected (only loaded messages are in memory, not full history)

## R6: Splash Preload Strategy

**Decision**: After `AuthCubit.verifyAuthStatus()` resolves with an authenticated state, call `ChatCubit.loadRecentChats()` before navigating to home. Use `Future.wait()` to parallelize auth check and chat load.

**Rationale**: The splash screen already waits for auth verification. Adding chat list load in parallel ensures the home screen has data immediately. The splash animation (900ms) provides natural loading time.

**Alternatives considered**:
- Lazy load on home screen → current behavior, causes visible loading spinner
- Background isolate → over-engineering for a single SQLite query
- Pre-fetch in main() before runApp → too early, DI not initialized

## R7: PlayerController.dispose() Bug

**Decision**: Do NOT call `PlayerController.dispose()`. Clean up Dart-side references only (listeners, subscriptions). Rely on GC finalization for native resource cleanup.

**Rationale**: The `audio_waveforms` package's `dispose()` method calls `stopWaveformExtraction()` via a platform channel created in the root zone. When the native `MediaCodec` is already released, this throws `PlatformException("codec is released already")` which cannot be caught by any Dart mechanism (`try/catch`, `runZonedGuarded`, `.catchError()`). Active playback is stopped by `VoiceNoteController.stopCurrent()` via `PopScope` before navigation.

**Alternatives considered**:
- `try/catch` → doesn't catch async platform channel errors
- `runZonedGuarded` → platform channel runs in root zone, bypasses child zones
- `.catchError()` → `dispose()` returns `void`, not `Future`
- Fork the package → too much maintenance burden

---

## R8: Infinite Scroll Pagination Pattern (NEW — FR-018)

**Decision**: Offset-based pagination with `LIMIT 30 OFFSET ?` on the `messages` table, ordered by `timestamp DESC`. The `ChatCubit` maintains `_messageOffset`, `_hasMoreMessages`, and `_isLoadingMore` state. The `ChatRoomScreen`'s `ScrollController` triggers `loadMoreMessages()` when `extentAfter < 200px`.

**Rationale**: WhatsApp uses a similar windowed approach — the newest messages are loaded first, and scrolling up lazy-loads older messages. Offset-based pagination is simpler than cursor-based for SQLite (no need to track a cursor timestamp). The 30-message batch size balances UI responsiveness with memory usage.

**Alternatives considered**:
- Cursor-based pagination (by timestamp) → slightly more robust for concurrent writes, but overkill for local SQLite where writes are serialized
- Load all messages, virtualize rendering → rejected (10,000 messages would consume too much memory)
- `StreamBuilder` with dynamic query → complex to implement incremental appends

**WhatsApp behavior reference**: WhatsApp loads ~30 messages initially, shows a loading spinner at the top when scrolling up, and appends older messages. The scroll position is preserved (no jump). Messages are always ordered newest-at-bottom.

## R9: Message Idempotency & Status Monotonicity (NEW — FR-019)

**Decision**: Implement a two-layer idempotency guard:
1. **Insert dedup**: Before `INSERT OR REPLACE`, check `SELECT id FROM messages WHERE client_message_id = ?`. If exists, return early.
2. **Status monotonicity**: Define rank map `{pending: 0, sent: 1, delivered: 2, read: 3}`. Before updating status, fetch current rank. If incoming rank ≤ current rank, skip.
3. **Query by clientMessageId**: All `updateMessageStatus()` calls use `WHERE client_message_id = ?` instead of `WHERE id = ?`.

**Rationale**: `ConflictAlgorithm.replace` (the current strategy) is dangerous because it silently overwrites existing rows, including any status that may have already been promoted. The dedup guard prevents this. Monotonic status ensures a `read` message never regresses to `delivered` during reconnect replays.

**Alternatives considered**:
- `INSERT OR IGNORE` → only prevents insert conflicts but doesn't protect status
- Timestamp-based dedup → fragile (clock skew between devices)
- Server-side dedup only → doesn't protect against socket replay on reconnect

## R10: Scoped Inbox Status Ticks (NEW — FR-020)

**Decision**: Add `last_message_id` and `last_message_sender_id` columns to the `rooms` table. In `updateMessageStatus()`, only update `rooms.lastMessageStatus` if the message being updated matches `rooms.last_message_id`. In `ChatTileWidget`, only render tick icons when `lastMessageSenderId == currentUserId`.

**Rationale**: WhatsApp only shows delivery ticks for the user's own messages. Showing ticks for received messages is confusing ("why does their message have a blue tick?"). Scoping the room status to the latest message prevents old message reads from overwriting the inbox preview.

**Alternatives considered**:
- Track status per-message only (no room-level) → requires joining messages table for every inbox render, too expensive
- Always show ticks → not WhatsApp behavior, confusing UX

## R11: Atomic JIT Room Creation (NEW — FR-021)

**Decision**: Modify the backend `POST /chat/private/resolve` endpoint to accept an optional `firstMessage` field in the request body. When present, the server atomically: (1) creates/resolves the room, (2) joins the caller's socket to the room channel, (3) persists the first message, (4) emits it to the recipient. Returns `{ roomId, message? }`.

**Rationale**: The current `_ensureRoom()` flow uses `Future.delayed(300ms)` as a timing hack to wait for socket room join. This is brittle — if the server takes >300ms, the first message is lost. The atomic approach eliminates the race condition entirely by doing everything server-side.

**Alternatives considered**:
- Socket acknowledgment callback (wait for `roomJoined` event) → requires socket ACK protocol change, still two network calls
- Increase delay to 1s → band-aid, doesn't fix the root cause
- Client-side retry if first message fails → adds complexity, still races

**Backend implementation notes**:
- The resolve endpoint already creates/returns rooms. Adding message persistence is a ~20-line change.
- The socket `joinRoom` can be called server-side via `socket.join(roomId)` in the gateway.
- The message is persisted via the existing `ChatService.createMessage()`.

## R12: Dual-Mode Message Deletion (NEW — FR-022)

**Decision**: Implement both "Delete for Me" (local-only) and "Delete for Everyone" (socket event). Add `is_deleted INTEGER DEFAULT 0` column to SQLite `messages` table. Add `isDeleted: Boolean` to MongoDB message schema.

**Rationale**: WhatsApp's delete system is table-stakes for user trust. "Delete for Me" is already partially implemented (local SQLite delete). "Delete for Everyone" requires a new socket event and a soft-delete flag rather than hard-delete (so the placeholder "This message was deleted" can be shown).

**Alternatives considered**:
- Hard delete on backend → rejected (other party would see a gap in conversation with no explanation)
- Time limit of 7 days (like Telegram) → rejected (WhatsApp uses 1 hour, spec says 1 hour)
- No time limit → rejected (could be used to retract messages days later, not WhatsApp behavior)

## R13: Voice Waveform Sender-Side Extraction (NEW — FR-025)

**Decision**: Extract waveform data (50 samples) immediately after recording stops, before calling `sendVoiceNote()`. Include `waveformSamples` in the message metadata. Transmit via socket. Receiver stores in SQLite on arrival and renders directly — never calls `extractWaveformData()`.

**Rationale**: The current implementation extracts waveform data on every `_VoiceBubble` widget build if cached data is not found. For received messages without a local file, this means downloading the file AND extracting waveform — causing a visible delay. The sender already has the file locally and can extract instantly. Transmitting the data via socket means the receiver never needs to extract.

**Alternatives considered**:
- Server-side extraction → rejected (requires ffmpeg/audio processing on backend)
- Pre-extract on message arrival → still requires file download before extraction
- Use placeholder waveform → poor UX, not WhatsApp behavior

## R14: Shared Media Screen (NEW — FR-024)

**Decision**: New `SharedMediaScreen` page with `TabBarView` (3 tabs: Media, Links, Docs). Media tab uses a 4-column `GridView.builder`. Links and Docs tabs use `ListView.builder`. Data sourced from 3 new SQLite queries on the `messages` table. No loading spinner — instant render from local cache.

**Rationale**: WhatsApp's media screen is a critical feature for finding shared content. The current `ChatInfoScreen` shows a horizontal thumbnail strip but doesn't navigate anywhere. The tabbed layout matches `images_ui/media_screen.jpeg`.

**Alternatives considered**:
- Embedded media grid in ChatInfoScreen → too crowded, not WhatsApp behavior
- Separate screens per tab → unnecessary fragmentation
- Server-side media index → rejected (all media is already in local SQLite)