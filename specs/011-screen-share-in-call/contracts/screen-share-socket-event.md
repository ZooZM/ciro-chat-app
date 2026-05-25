# Contract: `screenShareStateChanged` Socket Event

This contract governs the single new socket event introduced by feature 011.
The Flutter client and the NestJS backend gateway both depend on this schema
being stable.

---

## Client → Server: emit `screenShareStateChanged`

Emitted by a client when it locally starts or stops a screen share.

```json
{
  "chatRoomId": "<string>",          // required — the call's chat room id
  "userId":     "<string>",          // required — the sharer's userId
  "userName":   "<string>",          // required — display name for the receivers' SnackBar/tile
  "isSharing":  true,                // required — true on start, false on stop
  "withAudio":  false                // required when isSharing=true; ignored when isSharing=false
}
```

### Backend handling (start, `isSharing: true`)

1. `SET NX screenshare:active:{chatRoomId} {userId} EX 21600`  (6-hour TTL safeguard).
2. If `SET NX` returns `1` (we got the lock):
   - Re-broadcast `screenShareStateChanged` to every other socket in the same chat room with the SAME payload.
   - Reply to the emitter with `screenShareAccepted` (acknowledgement; payload `{ chatRoomId }`).
3. If `SET NX` returns `0` (another user holds the lock):
   - `GET screenshare:active:{chatRoomId}` to fetch the current sharer's userId.
   - Reply ONLY to the emitter with `screenShareRejected`:
     ```json
     {
       "chatRoomId":           "<string>",
       "activeSharerUserId":   "<string>",
       "activeSharerName":     "<string>",     // looked up from user profile
       "reason":               "another_user_sharing"
     }
     ```
   - Do NOT re-broadcast.

### Backend handling (stop, `isSharing: false`)

1. `GET screenshare:active:{chatRoomId}` and verify the stored value equals
   `userId` (someone trying to stop a share they don't own is silently ignored).
2. On match: `DEL screenshare:active:{chatRoomId}`.
3. Re-broadcast `screenShareStateChanged` with the same payload (`isSharing: false`) to every other socket in the same chat room.

### Backend cleanup on disconnect

When a participant leaves the call (existing `leaveGroupCall` / `endCall` /
socket-disconnect handlers), the backend MUST check whether
`screenshare:active:{chatRoomId} == userId` and DEL the key if so. This
prevents a "stuck sharer" if the sharer drops without sending an explicit stop.

---

## Server → Client: receive `screenShareStateChanged`

Receivers see the re-broadcast with the original payload shape. The client's
`SocketService.onScreenShareStateChanged` callback fires with:

```dart
void Function(
  String chatRoomId,
  String userId,
  String userName,
  bool isSharing,
  bool withAudio,
)? onScreenShareStateChanged;
```

The `CallCubit` listener ignores the event when `userId == localUserId` (we
already updated our own state during the start/stop request) and otherwise
updates the four `activeSharer*` fields on `CallActive`.

---

## Server → Client: receive `screenShareRejected`

The emitter receives this when their start request lost the race.

```dart
void Function(
  String chatRoomId,
  String activeSharerUserId,
  String activeSharerName,
  String reason,
)? onScreenShareRejected;
```

The `CallCubit` translates this into a `CallScreenShareConflict(activeSharerName)`
side-event for the UI.

---

## Server → Client: receive `screenShareAccepted`

Optional acknowledgement so the client knows the backend committed the lock
before LiveKit publishes the track. In practice the client invokes the LiveKit
API in parallel; the ack just confirms backend commitment for the conflict UI.

```dart
void Function(String chatRoomId)? onScreenShareAccepted;
```

---

## Type-safety guarantee (per constitution IV-A)

The Flutter handler MUST follow the Map-safety rule:

```dart
_socket?.on('screenShareStateChanged', (data) {
  if (data == null || data is! Map) return;
  final map = Map<String, dynamic>.from(data);
  final chatRoomId = map['chatRoomId']?.toString() ?? '';
  final userId = map['userId']?.toString() ?? '';
  final userName = map['userName']?.toString() ?? '';
  final isSharing = map['isSharing'] == true;
  final withAudio = map['withAudio'] == true;
  if (chatRoomId.isEmpty || userId.isEmpty) return;
  onScreenShareStateChanged?.call(chatRoomId, userId, userName, isSharing, withAudio);
});
```

Never `data as Map<String, dynamic>` or `data is Map<String, dynamic>`.

---

## Stability guarantee

The event names `screenShareStateChanged`, `screenShareRejected`,
`screenShareAccepted` and the field names in every payload are part of this
contract. Any rename on the backend MUST be coordinated with a Flutter update
that adjusts `SocketService` callbacks and `CallCubit` listeners in the same
release.
