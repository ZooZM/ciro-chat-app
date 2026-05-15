# REST Contract: Group Chat + Group Calls

**Phase 1 output** | Generated: 2026-05-14

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

Request: `file` field — binary file, max 20 MB.

Response 201:
```jsonc
{
  "fileUrl": "/uploads/uuid.jpg",
  "fileName": "avatar.jpg",
  "fileSize": 204800,
  "mimeType": "image/jpeg"
}
```

Errors:
- `413` — file exceeds 20 MB
- `415` — unsupported MIME type

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

## 4. Recordings (No REST endpoints — local-only)

Per spec FR-035 and decision **C4**, recordings are stored entirely on-device:

- Files: `<app-documents-dir>/recordings/<uuid>.m4a` (audio v1)
- Metadata: local SQLite `recordings` table (see data-model.md)

There are **no backend endpoints** for recording listing, upload, download, or sharing. Sharing a recording with someone outside the device is out of scope for v1; if a user wants to share, they can export the file via the OS share sheet (system feature — not implemented as a backend endpoint).
