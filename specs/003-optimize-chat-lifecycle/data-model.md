# Phase 1: Data Model

## Entities

### `ChatState` (Cubit State)
- Extends `Equatable`
- **Fields**:
  - `status`: `ChatStatus` (initial, loading, success, failure)
  - `messages`: `List<Message>`
  - `typingUsers`: `List<String>`
  - `onlineUsers`: `List<String>`
- **Behavior**: Uses `copyWith` to selectively update fields without changing the identity of unmodified lists unless necessary, preventing extraneous UI rebuilds.

### `CallState` (Cubit State)
- Extends `Equatable`
- **Fields**:
  - `status`: `CallStatus` (idle, ringing, connecting, active, ended)
  - `callerId`: `String?`
  - `callType`: `CallType` (voice, video)
  - `rtcSessionDescription`: `String?`
- **Behavior**: Manages the WebRTC state entirely independently of the `ChatState`.

### `Message` Entity Updates (If Applicable)
- Ensure alignment with `AGENT_CHAT_LIFECYCLE.md` offline-first model.
- **Fields**:
  - `id`: `String` (uuid)
  - `deliveryStatus`: `MessageStatus` (pending, sent, delivered, read)
