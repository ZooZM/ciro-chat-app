# Implementation Plan: Voice-Bubble Waveform Stability (010)

**Goal**: Cache voice-message waveforms so they compute once and don't rebuild on new messages, typing, playback state changes, etc.

**Priority**: P1 (user-facing performance + user complaint match)

**Scope**: Two user stories
- **US1**: Waveforms stable across new message arrivals, typing changes, input bar resizes
- **US2**: Waveforms stable across playback state changes (play/pause/seek)

**Out of Scope**:
- Input-bar recording waveform (live animation, intentionally excluded per FR-011)
- Cross-session persistence (recompute allowed on next conversation open, in-session reuse required)
- Disk storage of waveform data

---

## Architecture

### Problem Analysis

Today's symptom: Voice waveforms flicker or visibly redraw when a new message arrives.

Root cause: Voice-message bubbles (or their parent list) are being rebuilt/repainted excessively, triggering waveform extraction and re-render on every list rebuild.

### Design

1. **Waveform Geometry** (static, computed once)
   - Extracted waveform samples → stored as a list of bar heights
   - Computed on first display of the voice message
   - Immutable; never changes for that message

2. **Voice Message Bubble** (two layers)
   - Geometry layer: renders cached waveform (static)
   - Playback layer: renders progress indicator + play/pause button (dynamic)
   - These layers are independent; playback state changes only update layer 2

3. **Waveform Cache** (per conversation session)
   - Scoped to the open ChatCubit / room
   - Maps message ID → computed waveform geometry
   - Lives in memory; cleared when room closes
   - Bounded size (optional LRU if 10+ voice messages in a room)

4. **Extraction Logic** (unchanged, but cached)
   - Message arrives (sender-provided waveform samples via metadata, or extract from audio file)
   - On first bubble mount/display: compute geometry once
   - Store in cache
   - On every render thereafter: use cached geometry

---

## Implementation Phases

### Phase 1: Foundation (Waveform Cache Infrastructure)

**Files to create/modify**:
- `lib/features/chat/domain/value_objects/voice_waveform.dart` — `VoiceWaveformGeometry` class (immutable, hashable)
- `lib/features/chat/presentation/bloc/chat_cubit.dart` — add `_waveformCache` field + `getCachedWaveform()`, `cacheWaveform()` methods
- `lib/features/chat/presentation/bloc/chat_state.dart` — no state changes needed (cache is internal)

**Tasks**:
1. [T001] Create `VoiceWaveformGeometry` value object
   - Fields: `messageId`, `samples` (List<double> or List<int>), `duration`
   - Implement `==`, `hashCode` for immutability
   - Immutable: final fields, const constructor if possible

2. [T002] Add cache to ChatCubit
   - Field: `final Map<String, VoiceWaveformGeometry> _waveformCache = {};`
   - Method: `VoiceWaveformGeometry? getCachedWaveform(String messageId)`
   - Method: `void cacheWaveform(VoiceWaveformGeometry geometry)`
   - Clear cache in `reset()` (logout cleanup)

3. [T003] Add cache-clear on room close
   - In `closeRoom()`, add `_waveformCache.clear();` before setting `_activeRoomId = null`

---

### Phase 2: VoiceBubble Refactor (Separate Geometry from Playback State)

**Files**:
- `lib/features/chat/presentation/widgets/voice_bubble.dart` (existing file; will be refactored)

**Goal**: Split the widget hierarchy so that:
- Waveform geometry is computed once and cached
- Playback state (isPlaying, progress) updates independently without rebuilding geometry

**Tasks**:

4. [T004] Extract waveform rendering into a stateless `_VoiceWaveformPainter` or similar
   - Takes cached `VoiceWaveformGeometry` as input
   - Renders the waveform bars
   - No state, no rebuilds if geometry input unchanged

5. [T005] Create `_CachedVoiceWaveformDisplay` StatelessWidget
   - Inputs: message, ChatCubit (to access cache)
   - On first build: checks cache via `cubit.getCachedWaveform(message.id)`
   - If miss: extracts waveform (async) and calls `cubit.cacheWaveform()`
   - Uses `ValueNotifier<VoiceWaveformGeometry?>` internally to handle async extraction without full rebuild
   - Renders `_VoiceWaveformPainter` with cached geometry

6. [T006] Separate playback-state layer in `VoiceBubble`
   - Split into two sub-widgets:
     - `_VoiceGeometryLayer`: renders waveform (from `_CachedVoiceWaveformDisplay`)
     - `_VoicePlaybackLayer`: renders progress indicator + play/pause (inherits from current `VoiceBubble`)
   - Use `Stack` to overlay playback layer on top of geometry layer
   - Playback layer rebuilds on state change; geometry layer does not

7. [T007] Verify no parent-list rebuilds trigger geometry recompute
   - Instrument `_CachedVoiceWaveformDisplay` with `debugPrint` on first waveform-cache hit
   - Add visual marker (e.g., different color on cached vs. fresh) to confirm reuse
   - Test: send 10 messages to a conversation with 3 visible voice bubbles; confirm debugPrint fires only once per bubble

---

### Phase 3: Waveform Extraction (Async, Non-Blocking)

**Files**:
- `lib/features/chat/presentation/widgets/voice_bubble.dart` or extracted helper

**Goal**: Ensure waveform extraction doesn't block the message list render

**Tasks**:

8. [T008] Extract waveform computation to async utility function (if not already isolated)
   - Input: message (with audio URL or local path)
   - Output: `List<double>` (sample magnitudes / heights)
   - Use existing `AudioWaveforms` plugin or similar
   - Runs in background; doesn't block message list

9. [T009] Add "loading" placeholder while extraction is in progress
   - On first display: show placeholder waveform (or simple line)
   - Once extraction completes: update `ValueNotifier` and display real waveform
   - No full rebuild of parent list

10. [T010] Prefer sender-provided waveform data
    - Check `message.metadata['waveformSamples']` or similar
    - If present: use directly (no extraction needed)
    - If missing: extract from audio file

---

### Phase 4: Testing (Manual + Unit)

**Tasks**:

11. [T011] Manual acceptance test per spec §2
    - Open conversation with 3+ voice messages
    - Have another user send 10 text messages
    - Verify: voice waveforms stay perfectly stable, no flicker, no repaint
    - Use performance profiler if available to confirm paint count unchanged

12. [T012] Playback state test
    - Play a voice message, pause, play again
    - Verify: waveform geometry unchanged, only progress indicator updates
    - Confirm via debugPrint that cache hit count = 1

13. [T013] Scroll-off-screen and back test
    - Scroll voice message out of viewport, then back in
    - Verify: waveform appears immediately from cache (no extraction delay)

14. [T014] Long message test
    - Send a 2+ minute voice message
    - Verify: waveform extraction doesn't block other messages from displaying
    - Measure first-display render time (should be <300 ms per spec)

15. [T015] Memory test
    - Open conversation with 10+ voice messages
    - Scroll and interact for 2 minutes
    - Verify: memory usage stays bounded (cache doesn't leak)
    - Optional: instrument cache size and eviction if LRU implemented

16. [T016] Regression test
    - Single-device: text messages, images, regular chat ops should be unaffected
    - Verify: input bar waveform (live recording) still works and animates normally

---

## Task Ordering & Dependencies

**Sequential (same file, must order)**:
- T001 → T002 → T003 (foundation)
- T004 → T005 → T006 → T007 (VoiceBubble refactor)

**Parallel-safe** (independent):
- T008–T010 (waveform extraction logic)
- T011–T016 (testing)

**Recommended execution**:
1. T001–T003 (waveform cache infrastructure)
2. T004–T007 (VoiceBubble refactor and geometry isolation)
3. T008–T010 (async extraction, placeholder, metadata preference)
4. T011–T016 (comprehensive manual testing)

---

## File Touchpoints

### New Files
- `lib/features/chat/domain/value_objects/voice_waveform.dart`

### Modified Files
- `lib/features/chat/presentation/bloc/chat_cubit.dart` (+cache field, +methods, +clear-on-close)
- `lib/features/chat/presentation/widgets/voice_bubble.dart` (refactor: separate geometry and playback)

### Read-Only (context only)
- `lib/features/chat/domain/entities/message.dart`
- `lib/features/chat/presentation/bloc/chat_state.dart`
- `lib/core/network/socket_service.dart` (unchanged; no new socket handlers)

---

## Acceptance Gates

**MVP** (T001–T007): 
- Waveform cache implemented
- VoiceBubble refactored to isolate geometry from playback
- Basic instrumentation confirms single-compute per bubble

**Full** (T001–T016):
- All manual tests pass
- No flicker observed
- Memory usage bounded
- Regression tests clean

---

## Notes

- **Frame rate during bursts** (SC-003): Should improve or stay the same since we're reducing paint operations
- **Visual appearance** (FR-006): No change; only stability improves
- **Input bar waveform** (FR-011): Explicitly out of scope; stays as live animation
- **Cross-session persistence**: Not required; cache clears on room close and conversation reopens
- **Older messages without waveform data** (edge case): Extract on first display, cache for session lifetime
