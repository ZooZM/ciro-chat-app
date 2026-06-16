# Frontend Integration Contract: Live Translation Captions

This feature introduces **no new backend APIs**. It is a consumer of the contracts
already implemented and documented in the backend repo at
`chat-app-backend/specs/001-realtime-call-translation/contracts/`:

- `caption-data-channel.md` — LiveKit data-channel caption payload (topic
  `"translation"`).
- `socket-events.md` — Socket.IO `translation:subscribe` / `translation:unsubscribe` /
  `translation:changeLanguage` (client→server) and `translation:subscribed` /
  `translation:unsubscribed` / `translation:denied` / `translation_unavailable` /
  `credits_low` / `credits_exhausted` (server→client).

This document records, for the **Flutter side**, exactly which parts of those contracts
this MVP implements and how.

## 1. LiveKit Data Channel: `topic: "translation"`

**Consumed via**: `TranslationDataChannelDataSource.attach(room)`, which creates its own
`Room.createListener().on<DataReceivedEvent>(...)` inside the data layer and exposes the
result as a `Stream<Caption>`. The `GroupCallScreen` never wires a `DataReceivedEvent`
handler itself — the UI stays decoupled from the raw data channel (Constitution I).

**Filter**: only packets where `event.topic == 'translation'` are passed to
`TranslationDataChannelDataSource`. All other topics/packets are ignored (untouched by
this feature).

**Payload** (UTF-8 JSON, per backend `caption-data-channel.md`):

```jsonc
{
  "v": 1,
  "type": "interim" | "final",
  "speakerId": "string",
  "sourceLanguage": "string",
  "targetLanguage": "string",
  "text": "string",
  "segmentId": "string",
  "seq": 0,
  "ts": 0
}
```

**Client behavior** (implements the backend contract's "Client rendering rules"):
- Group by `segmentId`; render the latest `interim` (highest `seq`).
- On `type: "final"`, replace and freeze the line for that `segmentId`.
- A new `segmentId` starts a new caption line; the previous final remains on screen
  until replaced by a new segment for the same speaker (FR-006).
- Out-of-order/duplicate interims are dropped (never regress displayed text — FR-012).

**Routing**: `speakerId` → `TranslationCubit.captionNotifier(speakerId)` →
`CaptionOverlay` on that participant's `_ParticipantTile` (FR-004). If `speakerId` does
not currently match a rendered tile (off-screen / camera off), the caption still updates
`latestActiveCaption` for the `CaptionBanner` fallback (FR-010).

## 2. Socket.IO Control Events (subset implemented this MVP)

All emitted/received via the existing `SocketService` singleton (constitution IV);
payload shapes are **exactly** the backend's `socket-events.md` — no field renames.

| Direction | Event | Used for |
|---|---|---|
| Client → Server | `translation:subscribe` `{roomId, speakerId, targetLanguage}` | User enables translation for a speaker (FR-001). |
| Client → Server | `translation:unsubscribe` `{roomId, speakerId}` | User disables translation for a speaker (FR-002), or speaker leaves the call (FR-013, local cleanup + best-effort emit). |
| Client → Server | `translation:changeLanguage` `{roomId, speakerId, targetLanguage}` | User changes target language for an already-active speaker (FR-001/US3). |
| Server → Client | `translation:subscribed` `{roomId, speakerId, targetLanguage, remainingSeconds}` | `pending → active`. `remainingSeconds` is received and stored but **not surfaced in UI this MVP** (credits UI is out of scope — see spec Assumptions). |
| Server → Client | `translation:unsubscribed` `{roomId, speakerId}` | Confirms `→ off`; informational only (client already transitioned optimistically). |
| Server → Client | `translation:denied` `{roomId, speakerId, reason}` | `pending → denied`; reason shown in a non-blocking snackbar (Constitution VII). |
| Server → Client | `translation_unavailable` `{roomId, speakerId, reason, transient}` | `active → unavailable`; small badge on the speaker's tile; call audio/video unaffected (FR-014). |

**Explicitly NOT wired this MVP** (backend Phases 5-6 not yet implemented per the
request, and out of scope per spec Assumptions):
- `credits_low`, `credits_exhausted` — `SocketService` callbacks may be added later
  without affecting this feature's structure.
- Multiple simultaneous target languages for the same speaker from one listener
  (US3/FR-011 generalization) — this MVP assumes one `targetLanguage` per
  `(listener, speaker)` at a time, matching backend Phases 1-4.

## 3. Membership / auth

No new auth flow. `translation:*` events ride the existing authenticated Socket.IO
connection (JWT on handshake, per constitution IV); the backend enforces its
room-membership rule — the client does not duplicate that check.
