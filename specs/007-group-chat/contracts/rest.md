# REST Contract: Group Chat + Group Calls + Recording Share

**Phase 1 output** | Generated: 2026-05-14 | Revised: 2026-05-16

> **Revision (2026-05-16)**: Section 4 inverted — recording is now uploaded and shared via
> the existing media pipeline (FR-035). Upload cap lifted for recordings (RD-9). Optional
> new endpoint for renaming/managing recordings remains LOCAL ONLY (no server).

All endpoints require `Authorization: Bearer <accessToken>` header.
Base URL: `AppConstants.apiBaseUrl` (resolved from `.env`).
All responses use `Content-Type: application/json`.

Media URLs returned by the backend are relative paths (e.g. `/uploads/xyz.jpg`) and MUST be resolved on the client via `UrlUtils.resolveMediaUrl(url)` before display (Constitution §VIII-A).

---

## 1. Group CRUD (Existing — no change needed)

### Create Group

```
POST /chat/group/create
```

Request:
```jsonc
{
  "name": "Weekend Crew",
  "participants": ["+201012345678", "+201098765432"],
  "avatarUrl": "/uploads/abc123.jpg"   // optional
}
```

Response 201: Full `ChatRoom` document.

Errors:
- `400` — missing name or fewer than 2 participants (including creator)
- `401` — invalid/expired token
- `404` — one or more participant phone numbers not found

---

### Add Participants

```
POST /chat/group/:roomId/add
```

Request:
```jsonc
{ "phoneNumbers": ["+201011112222"] }
```

Response 200: Updated `ChatRoom` document.

Errors:
- `403` — caller is not an admin
- `404` — room not found

---

### Remove Participant

```
POST /chat/group/:roomId/remove
```

Request:
```jsonc
{ "phoneNumber": "+201011112222" }
```

Response 200: Updated `ChatRoom`.

Errors:
- `403` — caller is not an admin
- `400` — cannot remove yourself via this endpoint (use `/leave`)

---

### Leave Group

```
POST /chat/group/:roomId/leave
```

Request: empty `{}`.

Response 200:
```jsonc
{ "message": "Left group successfully", "newAdmin": "+20..." | null }
```

**Behavior**:
- Removes caller from `participants` and `admins`.
- If caller was the last admin: promotes `participants[0]` (earliest joiner; MongoDB `$pull` preserves insertion order) as the new admin. `newAdmin` field is set so the Flutter client can update the local `admins` list without a full room refresh.

Errors:
- `404` — room not found or caller is not a member

---

## 2. File Upload (Shared)

```
POST /chat/upload
Content-Type: multipart/form-data
```

Request:
- `file` field — binary file
- `category` field (optional) — one of `attachment` (default) | `recording`

| `category` | Max file size |
|------------|---------------|
| `attachment` (default) | 20 MB (unchanged) |
| `recording` (NEW, RD-9) | 500 MB |

Response 201:
```jsonc
{
  "fileUrl": "/uploads/uuid.mp4",
  "fileName": "Recording 2026-05-16 14-23.mp4",
  "fileSize": 12450000,
  "mimeType": "video/mp4"
}
```

Errors:
- `413` — file exceeds the category's cap
- `415` — unsupported MIME type

**Backend change required**: `chat.controller.ts` upload handler reads the `category` form
field and selects the appropriate size cap. Recording category is rate-limited to 5 uploads
per minute per user to prevent abuse.

---

## 3. Video / LiveKit Token (Existing — small auth tightening)

```
POST /video/room/:roomId/join
```

Request: empty `{}`.

Response 200:
```jsonc
{
  "token": "<jwt-with-livekit-grants>"
}
```

**Existing behavior**: issues a LiveKit token granting `roomJoin: true, canPublish: true, canSubscribe: true` for `roomName == roomId`.

**Required change for group calls (INV-9)**:
- Before issuing the token, verify the requesting user is a current participant of the `ChatRoom` with the given ID.
- If verification fails, return `403 Forbidden`.

This change is backwards-compatible with existing 1-to-1 callers: the 1-to-1 room is `call_{callerId}_{receiverId}` and the auth check can be skipped when the room name follows the legacy pattern (or, more uniformly, the check can pass through for any ChatRoom where the user is in `participants`).

Errors (added):
- `403` — user not a participant of the room
- `403` — group call participant cap (32) reached

---

## 4. Recordings — Share Pipeline (revised 2026-05-16)

Per spec FR-035/FR-036 (revised) and research decisions RD-6/RD-7, recordings are:

1. **Captured locally** in `<app-documents-dir>/recordings/<uuid>.{m4a|mp4}`.
2. **Saved to OS** via `gal` (video → Photos/Gallery) or filesystem (audio → Downloads).
3. **Uploaded** via the existing `POST /chat/upload?category=recording` endpoint (§2).
4. **Sent** as a media message via the existing `sendMessage` socket event (see socket.md),
   with `type = video | audio` and `fileUrl` from step 3.
5. **Tracked** locally in the `recordings` SQLite table with `share_status` ∈ {idle,
   uploading, shared, failed} (see data-model.md §3).

**No new REST endpoints are introduced** — the share pipeline reuses existing media flow.

### Per-Step Endpoint Reference

| Step | Endpoint / Event | Purpose |
|------|------------------|---------|
| Upload | `POST /chat/upload` (category=recording) | Get permanent `fileUrl` |
| Send | Socket `sendMessage` { type=video|audio, fileUrl, chatRoomId, clientMessageId } | Post the recording as a chat message |
| Status | Socket `messageSent` / `messageDelivered` / `messageRead` (existing) | Recording message follows standard media-message status flow |
| Retry | Reruns Upload + Send from the recordings list (manual user action) | RD-7 retry-on-failure UX |

### Recording Metadata — Local Only

Recording rename, delete, and orphan-recovery are local-only. There are **no server endpoints**
for managing recording metadata. The shared chat message and the local `Recording` row are
independent records — renaming a local recording does not rename the shared chat message,
and deleting a local recording does not delete the shared message (that requires the
existing chat-message-delete flow, which is out of scope for this feature).
