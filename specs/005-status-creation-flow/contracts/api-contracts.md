# API Contracts: Status Creation Flow

**Feature**: `005-status-creation-flow`  
**Date**: May 12, 2026

## 1. Status Upload

### POST `/status/upload`

Upload a new status (text, image, video, or voice).

**Request** (multipart/form-data):
```json
{
  "contentType": "text | image | video | voice",
  "textContent": "Hello world",
  "backgroundColor": 4283215696,
  "fontStyle": "Roboto",
  "privacy": "public | private | showOnMap",
  "selectedContactIds": ["userId1", "userId2"],
  "musicTrackId": "track_123",
  "caption": "Good morning"
}
```
+ Optional file attachment: `media` (image/video/audio file)

**Response** (200):
```json
{
  "statusId": "status_abc123",
  "mediaUrl": "https://cdn.example.com/status/file.jpg",
  "createdAt": "2026-05-12T15:00:00Z",
  "expiresAt": "2026-05-13T15:00:00Z"
}
```

**Errors**:
- 400: Invalid content type or missing required fields
- 413: File too large
- 401: Unauthorized

---

## 2. Music Catalog

### GET `/music/tracks`

Fetch paginated music catalog.

**Query params**:
- `q` (string, optional): Search query
- `category` (string, optional): `suggestions` | `mood` | `type`
- `page` (int, default 1): Page number
- `limit` (int, default 20): Items per page

**Response** (200):
```json
{
  "tracks": [
    {
      "id": "track_123",
      "name": "song1",
      "artist": "Singer",
      "duration": 292,
      "thumbnailUrl": "https://cdn.example.com/thumbs/track_123.jpg",
      "previewUrl": "https://cdn.example.com/previews/track_123.mp3",
      "category": "suggestions"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "hasMore": true
  }
}
```

---

## 3. AI Image Generation

### POST `/ai/generate-image`

Generate an AI image from a text prompt.

**Request**:
```json
{
  "prompt": "A sunset over the pyramids of Egypt"
}
```

**Response** (200):
```json
{
  "generationId": "gen_xyz789",
  "imageUrl": "https://cdn.example.com/ai/gen_xyz789.png",
  "prompt": "A sunset over the pyramids of Egypt",
  "createdAt": "2026-05-12T15:00:00Z"
}
```

**Errors**:
- 400: Empty or invalid prompt
- 429: Rate limited (too many generations)
- 504: Generation timed out

---

## 4. Status Reaction

### POST `/status/:statusId/react`

Send a heart/like reaction to a status.

**Request**:
```json
{
  "reaction": "heart"
}
```

**Response** (200):
```json
{
  "success": true
}
```

---

## 5. Status Reply

### POST `/status/:statusId/reply`

Reply to a status (sends as direct message).

**Request**:
```json
{
  "message": "Nice photo!"
}
```

**Response** (200):
```json
{
  "messageId": "msg_abc123",
  "chatRoomId": "room_xyz"
}
```

---

## 6. Socket Events

### Emit: `uploadStatus`
```json
{
  "statusId": "status_abc123",
  "contentType": "text",
  "textContent": "Hello",
  "backgroundColor": 4283215696,
  "mediaUrl": null,
  "privacy": "public"
}
```

### Listen: `statusReceived` (already implemented)
```json
{
  "id": "status_abc123",
  "authorName": "Amr Mohamed",
  "authorAvatar": "avatar_url",
  "contentType": "image",
  "mediaUrl": "https://...",
  "timestamp": "2026-05-12T15:00:00Z",
  "expiresAt": "2026-05-13T15:00:00Z"
}
```
