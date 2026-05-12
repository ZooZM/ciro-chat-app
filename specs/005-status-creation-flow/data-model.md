# Data Model: Status Creation Flow

**Feature**: `005-status-creation-flow`  
**Date**: May 12, 2026

## Entity Modifications

### StatusEntity (EXTEND existing)

The existing `StatusEntity` needs additional fields to support the new content types:

```
StatusEntity (extended)
├── id: String                    # (existing)
├── authorName: String            # (existing)
├── authorAvatar: String          # (existing)
├── timestamp: DateTime           # (existing)
├── expiresAt: DateTime           # (existing)
├── isViewed: bool                # (existing)
├── isMine: bool                  # (existing)
├── contentType: StatusContentType # NEW — text | image | video | voice
├── textContent: String?          # NEW — text body (for text statuses)
├── mediaUrl: String?             # NEW — image/video/voice file URL
├── backgroundColor: int?         # NEW — background color as ARGB int
├── fontStyle: String?            # NEW — font family name
├── musicTrackId: String?         # NEW — attached music track ID
├── caption: String?              # NEW — caption for media statuses
└── privacy: StatusPrivacy        # NEW — public | private | showOnMap
```

### StatusContentType (NEW enum)

```
StatusContentType
├── text
├── image
├── video
└── voice
```

### StatusPrivacy (NEW enum)

```
StatusPrivacy
├── public       # visible to all contacts
├── private      # visible to selected contacts only
└── showOnMap    # visible on the map view
```

### StatusDraft (NEW — presentation-only, not persisted)

Represents an in-progress status being composed. Lives only in `StatusCreationCubit` state.

```
StatusDraft
├── contentType: StatusContentType
├── textContent: String
├── backgroundColor: Color        # current canvas color
├── fontStyle: String             # current font family
├── privacy: StatusPrivacy
├── selectedContactIds: List<String>  # for private mode
├── mediaFilePath: String?        # local path to captured/selected media
├── mediaUrl: String?             # uploaded URL (post-upload)
├── recordingFilePath: String?    # local path to voice recording
├── musicTrack: MusicTrack?       # attached music track
├── caption: String               # caption text
└── videoDuration: Duration?      # for validation (≤30s)
```

### MusicTrack (NEW entity)

```
MusicTrack
├── id: String
├── name: String
├── artist: String
├── duration: Duration
├── thumbnailUrl: String
├── previewUrl: String
└── category: String              # suggestions | mood | type
```

### AIImageResult (NEW entity)

```
AIImageResult
├── generationId: String
├── prompt: String
├── imageUrl: String
└── createdAt: DateTime
```

## State Transitions

### StatusCreation Flow

```
Idle → DraftInitialized → Composing → Uploading → Success
                                    ↘ UploadFailed → (retry) → Uploading
```

### Voice Recording Flow

```
Idle → Recording → RecordingComplete → (preview) → Ready
                 ↘ RecordingCancelled → Idle
```

### AI Image Generation Flow

```
Idle → Generating → Generated → Selected
                  ↘ GenerationFailed → (retry) → Generating
```

## Relationships

- `StatusEntity` 1:1 `StatusPrivacy` (embedded enum)
- `StatusEntity` 0..1 `MusicTrack` (optional music attachment via `musicTrackId`)
- `StatusDraft` is **transient** — never persisted to SQLite; lives only in Cubit state
- `MusicTrack` is fetched from backend REST endpoint, not stored locally (cache optional)
