# Data Model: Avatar-Based Video Call UI

This feature is **UI-only** — no new entities, database tables, or API contracts are introduced. The screens consume data passed via constructor parameters (mock data).

## Widget Input Models

These are not domain entities — they are the constructor parameters each presentation widget expects.

### AvatarIncomingCallScreen

| Parameter | Type | Description |
|-----------|------|-------------|
| `callerName` | `String` | Display name of the caller |
| `callerAvatarUrl` | `String` | URL for the caller's avatar image (empty → show initials placeholder) |
| `onJoin` | `VoidCallback` | Triggered when user taps "Join" |
| `onDecline` | `VoidCallback` | Triggered when user taps "Not Now" |

### AvatarActiveCallScreen

| Parameter | Type | Description |
|-----------|------|-------------|
| `remoteName` | `String` | Display name of the remote user |
| `remoteAvatarUrl` | `String` | URL for the remote avatar (empty → show initials placeholder) |
| `localAvatarUrl` | `String` | URL for the local user's PIP avatar (empty → show initials placeholder) |
| `localName` | `String` | Local user's display name (for initials fallback) |
| `isMuted` | `bool` | Whether the mic is currently muted |
| `isCameraOff` | `bool` | Whether the camera is currently off |
| `callDuration` | `String` | Formatted call duration string (e.g., "0:03") |
| `onToggleMute` | `VoidCallback` | Triggered when user taps Mute button |
| `onToggleCamera` | `VoidCallback` | Triggered when user taps Camera button |
| `onEndCall` | `VoidCallback` | Triggered when user taps End Call button |
| `onMinimize` | `VoidCallback?` | Triggered when user taps the chevron/minimize button (optional) |

## Existing Entities Referenced

- **`CallState` hierarchy** (`CallIncoming`, `CallActive`, etc.) — existing states in `call_cubit.dart` that will eventually trigger navigation to these screens. No modification needed for this UI-only feature.

## Localization Keys (New)

| Key | EN Value | AR Value |
|-----|----------|----------|
| `call_incoming_call` | "Incoming call" | "مكالمة واردة" |
| `call_action_not_now` | "Not Now" | "ليس الآن" |
| `call_btn_camera` | "Camera" | "كاميرا" |
| `call_btn_end_call` | "End Call" | "إنهاء" |

Existing keys to reuse: `call_action_join`, `call_btn_mute`.
