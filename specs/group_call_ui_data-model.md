# Phase 1: Design & Data Model

## Entities

While this feature is primarily a UI update, the UI relies on the following data structures in the presentation layer (or mocked for testing):

### 1. `Participant`
Represents an individual in the call.
- **Fields**:
  - `id` (String): Unique identifier.
  - `name` (String): Full name (e.g., "Ahmed Khaled").
  - `initials` (String): Derived from name (e.g., "A" or "AK").
  - `isAudioMuted` (bool): State for rendering the mic off icon.
  - `isVideoMuted` (bool): State for rendering the avatar vs. camera feed.
  - `isActiveSpeaker` (bool): Determines sorting and highlighting.

### 2. `CallSession`
Represents the active call context.
- **Fields**:
  - `groupId` (String): The ID of the group chat.
  - `groupName` (String): Name of the group (e.g., "Tech Team").
  - `participants` (List<Participant>): List of all participants currently in the call.
  - `totalParticipantCount` (int): Total number of participants (used for localized count string and "+N others" calculation).
  - `status` (Enum: `incoming`, `waiting`, `active`): Current UI state.
