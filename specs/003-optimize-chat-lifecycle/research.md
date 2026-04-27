# Research: Optimize Chat Lifecycle (Expanded)

**Date**: April 27, 2026
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