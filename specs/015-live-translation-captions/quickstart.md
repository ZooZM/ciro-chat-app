# Quickstart: Live Translation Captions Overlay (Frontend MVP)

## Prerequisites

- Backend `chat-app-backend` running with `001-realtime-call-translation` Phases 1-4
  deployed (translation pipeline, Socket.IO `translation:*` events, LiveKit data-channel
  caption publishing).
- A test account with sufficient `translationSecondsBalance` (backend Phase 5 gating —
  if already enforced on the running backend, ensure balance > 0; this MVP does not
  surface balance UI but `translation:denied{reason:'insufficient_credits'}` would still
  block activation).
- Two devices/simulators able to join the same group call room.

## Manual validation steps

1. **Join a group call** with two participants: Listener (Device A) and Speaker
   (Device B). Both on `GroupCallScreen`.
2. **Enable translation** (US3/FR-001): On Device A, tap the CC icon on Speaker's tile,
   pick a target language different from the speaker's spoken language, confirm.
   - Expect: `translation:subscribe` emitted; `translation:subscribed` received within a
     few seconds; CC icon shows "active" state.
3. **Speak** on Device B in the source language.
   - Expect (US1/SC-001): an interim caption appears on Speaker's tile on Device A
     within ~1s, updating live as more is recognized.
   - Expect (US1/SC-002): when the sentence ends, the interim caption is replaced by a
     final caption within ~2s and remains visible.
4. **Performance check** (US2/SC-003): While captions are actively updating, scroll the
   participant grid (if >2 participants) and tap call controls (mute/camera). Confirm no
   visible stutter/frame drop and controls respond immediately. (Optional: run in
   profile mode and confirm the DevTools "Performance" overlay shows the video grid
   subtree is not rebuilding on each caption update.)
5. **Disable translation** (US3/FR-002, SC-006): Tap the CC icon again to turn it off.
   - Expect: `translation:unsubscribe` emitted; caption overlay for Speaker disappears
     within ~1s; call continues uninterrupted.
6. **Off-screen fallback** (FR-010): With ≥3 participants in a scrollable grid, enable
   translation for a speaker whose tile is scrolled out of view.
   - Expect: the bottom `CaptionBanner` shows `"{speakerName}: {text}"` for that
     speaker's captions even though their tile isn't visible.
7. **Speaker leaves** (FR-013): While translation is active for Speaker, have Device B
   leave the call.
   - Expect: Speaker's tile (and its caption overlay) is removed from the grid; no
     dangling caption/banner remains for that speaker.
8. **Translation unavailable** (FR-014, edge case): Trigger a backend
   `translation_unavailable` (e.g., have the speaker talk in an unsupported/undetected
   language, if the test backend can simulate this).
   - Expect: a small "translation unavailable" badge appears on Speaker's tile; call
     audio/video unaffected; no frozen/blank caption box.

## Automated checks

```bash
flutter test test/features/translation/
flutter analyze
```

- `caption_model_test.dart`: `fromJson` for valid `interim`/`final` payloads, malformed
  payload → `null`, missing optional `seq`/`ts` defaults to `0`.
- `translation_cubit_test.dart` (`bloc_test`): subscribe → `pending` → `subscribed` →
  `active`; `denied` path; `translation_unavailable` path; stale/out-of-order interim is
  dropped, final always applies and freezes the segment; `close()` disposes all
  `ValueNotifier`s and emits `translation:unsubscribe` for active subscriptions.
