---
description: "Task list for Voice-Bubble Waveform Stability — cache waveforms per-message and isolate from playback-state rebuilds"
---

# Tasks: Voice-Bubble Waveform Stability (010)

**Input**: Design documents from `/specs/010-voice-bubble-perf/`
**Plan**: plan.md ✅

## Phase 1: Foundation (Waveform Cache Infrastructure)

- [ ] T001 Create `lib/features/chat/domain/value_objects/voice_waveform.dart` with `VoiceWaveformGeometry` immutable value object. Fields: `messageId`, `samples` (List<double>), `duration`. Implement `==` and `hashCode`.
- [ ] T002 In `lib/features/chat/presentation/bloc/chat_cubit.dart`, add private field `final Map<String, VoiceWaveformGeometry> _waveformCache = {};` after `_roomStreamSub` declaration. Add public methods: `VoiceWaveformGeometry? getCachedWaveform(String messageId)` and `void cacheWaveform(VoiceWaveformGeometry geometry)`.
- [ ] T003 In `lib/features/chat/presentation/bloc/chat_cubit.dart` `closeRoom()` method, add `_waveformCache.clear();` before the line `_activeRoomId = null;`. Also clear cache in `reset()` (logout).

## Phase 2: VoiceBubble Refactor (Separate Geometry from Playback State)

- [ ] T004 In `lib/features/chat/presentation/widgets/voice_bubble.dart`, extract waveform rendering into a stateless `_VoiceWaveformPainter` class (CustomPainter) or similar. Takes `VoiceWaveformGeometry` as input; renders waveform bars. No state.
- [ ] T005 Create stateless `_CachedVoiceWaveformDisplay` widget in same file. Takes message and ChatCubit context. Checks cache on first build; if miss, extracts waveform async using `ValueNotifier<VoiceWaveformGeometry?>` and updates cache via `cubit.cacheWaveform()`. Renders `_VoiceWaveformPainter` with cached geometry. Handles loading state (placeholder) while extraction in progress.
- [ ] T006 Refactor main `VoiceBubble` widget to split into two sub-widgets: `_VoiceGeometryLayer` (renders `_CachedVoiceWaveformDisplay`) and `_VoicePlaybackLayer` (renders progress + play/pause button). Stack them vertically or overlay. Playback layer only rebuilds on state change; geometry layer does not.
- [ ] T007 Add instrumentation: `debugPrint('[VoiceBubble] Cache hit for message ${message.id}')` in `_CachedVoiceWaveformDisplay` when geometry is retrieved from cache. Run manual test: send 10 messages to conversation with 3 visible voice bubbles; confirm debugPrint fires exactly 3 times (once per bubble on first display).

## Phase 3: Waveform Extraction (Async, Non-Blocking)

- [ ] T008 Extract waveform computation to async utility function (in `lib/features/chat/presentation/widgets/voice_bubble.dart` or separate file). Input: message (URL or local path). Output: `List<double>` (sample magnitudes). Use existing `AudioWaveforms` plugin or similar. Runs in background.
- [ ] T009 In `_CachedVoiceWaveformDisplay`, add "loading" placeholder while extraction is in progress. Once extraction completes, update `ValueNotifier` and display real waveform. No full list rebuild.
- [ ] T010 In waveform extraction logic, prefer sender-provided data: check `message.metadata['waveformSamples']` or similar. If present, use directly (no extraction). If missing, extract from audio file.

## Phase 4: Testing (Manual + Instrumentation)

- [ ] T011 Manual acceptance test per spec §2: Open conversation with 3+ voice messages. Have another user send 10 text messages quickly. Verify voice waveforms stay perfectly stable — no flicker, no repaint. Use performance profiler or visual inspection.
- [ ] T012 Playback state test: Tap play on a voice message, tap pause, tap play again. Verify waveform geometry unchanged (debugPrint cache-hit count = 1). Only progress indicator updates.
- [ ] T013 Scroll-off-screen and back test: Scroll voice message out of viewport, scroll back in. Verify waveform appears immediately from cache (no extraction delay observed).
- [ ] T014 Long message test: Send a 2+ minute voice message. Verify extraction doesn't block other messages from displaying. Measure first-display render time (<300 ms per SC-002).
- [ ] T015 Memory test: Open conversation with 10+ voice messages. Scroll and interact for 2 minutes. Verify memory usage stays bounded and cache doesn't leak. Optional: instrument cache size.
- [ ] T016 Regression test: Single-device, text + images + regular chat ops. Verify input bar waveform (live recording) still animates normally. Confirm no orthogonal regressions.

## Task Summary

| Phase | Count | Status |
|-------|-------|--------|
| 1: Foundation | 3 | Pending |
| 2: VoiceBubble Refactor | 4 | Pending |
| 3: Extraction | 3 | Pending |
| 4: Testing | 6 | Pending |
| **Total** | **16** | **0/16 complete** |

## Execution Order

**Sequential (file editing)**:
- T001–T003 → T004–T007 → T008–T010

**Parallel (testing)**:
- T011–T016 can run after T001–T007 are complete

## MVP Checkpoint

After T001–T007: Basic waveform cache + refactored VoiceBubble with separated geometry/playback. Instrumentation confirms single-compute per bubble.

After T008–T010: Async extraction + metadata preference wired in.

After T011–T016: Full acceptance and regression testing complete.
