# Research: Status Creation Flow

**Feature**: `005-status-creation-flow`  
**Date**: May 12, 2026

## R1: Music Catalog Backend Integration

**Decision**: Backend-owned REST endpoint with pagination  
**Rationale**: User confirmed (Q1: A) the backend team provides the music catalog. Client consumes a paginated REST endpoint for listing, searching, and filtering by category (Suggestions, Mood, Type).  
**Alternatives considered**:
- Third-party API (Spotify/Deezer) — rejected due to licensing complexity
- Static mock data — rejected; user wants real integration

**Implementation notes**:
- Use `DioClient` for REST calls to `/music/tracks` (GET, paginated)
- Query params: `?q=search&category=mood&page=1&limit=20`
- Response model: `MusicTrackModel` with `id`, `name`, `artist`, `duration`, `thumbnailUrl`, `previewUrl`
- Audio preview via `just_audio` (already in pubspec)

## R2: AI Image Generation via OpenAI DALL-E

**Decision**: OpenAI DALL-E via backend proxy  
**Rationale**: User confirmed (Q2: A). The client sends a text prompt to the backend, which proxies the request to OpenAI DALL-E and returns the generated image URL.  
**Alternatives considered**:
- Self-hosted Stable Diffusion — rejected; requires GPU infrastructure
- Stub/placeholder — rejected; user wants real integration

**Implementation notes**:
- POST `/ai/generate-image` with `{ "prompt": "..." }`
- Response: `{ "imageUrl": "https://...", "generationId": "..." }`
- Show loading indicator during generation (up to 15s timeout)
- Voice-to-text for prompt input via platform speech recognition or a simple text field with mic icon

## R3: Video Clip Support (≤30s)

**Decision**: Image + short video clips ≤30 seconds, no trimming  
**Rationale**: User confirmed (Q3: C with 30s). Gallery videos exceeding 30s are rejected with a user-friendly message. No client-side trimming editor.  
**Alternatives considered**:
- Full video support with trimming — rejected; too much scope for v1
- Image-only — rejected; user wants video clips

**Implementation notes**:
- Use `image_picker` (already in pubspec) for camera/gallery capture
- Validate video duration client-side after selection using `video_player` (already in pubspec)
- If duration > 30s: show SnackBar "Video must be 30 seconds or less"
- Camera recording: use `image_picker`'s `maxDuration` parameter set to 30s

## R4: Voice Recording for Status

**Decision**: Use existing `record` and `audio_waveforms` packages  
**Rationale**: Both `record: ^6.2.0` and `audio_waveforms: ^2.0.2` are already in pubspec. No new dependencies needed.  
**Alternatives considered**: N/A — packages already installed

**Implementation notes**:
- `RecorderController` from `audio_waveforms` for real-time waveform visualization
- Max recording duration: 30 seconds (auto-stop with callback)
- Output format: AAC/M4A for cross-platform compatibility
- Temporary file stored in app cache directory until upload

## R5: Background Color Palette

**Decision**: Curated palette of 24+ colors stored as constants  
**Rationale**: The UI screenshots show a fixed grid of ~24 color swatches. No need for a custom color picker — a predefined list is sufficient.

**Implementation notes**:
- Define as `List<Color>` constant in a dedicated file
- Default color: teal/mint (matching the screenshots)
- Persist selected color in `StatusDraft` entity

## R6: Privacy Controls

**Decision**: Three-tier privacy model  
**Rationale**: Screenshots show "Public (All contacts)", "Private (Select contacts)", and "Show on Map" options.

**Implementation notes**:
- `StatusPrivacy` enum: `public`, `private`, `showOnMap`
- For `private`: launch a contact multi-select picker (reuse existing contacts infrastructure)
- For `showOnMap`: stub for now if no location feature exists; mark as "coming soon" in UI

## R7: Existing Dependencies Audit

All required packages are already in `pubspec.yaml`:

| Package | Version | Usage |
| ------- | ------- | ----- |
| `image_picker` | ^1.1.2 | Camera capture + gallery selection |
| `video_player` | ^2.11.1 | Video duration validation + preview |
| `record` | ^6.2.0 | Voice recording |
| `audio_waveforms` | ^2.0.2 | Real-time waveform visualization |
| `just_audio` | ^0.10.5 | Music preview playback |
| `permission_handler` | ^12.0.1 | Camera/mic/gallery permissions |
| `file_picker` | ^8.1.2 | Alternative file selection |
| `video_thumbnail` | ^0.5.6 | Video thumbnail generation |

**No new pub dependencies required.**
