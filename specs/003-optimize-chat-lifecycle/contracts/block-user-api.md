# API Contract: Block User

**Date**: April 27, 2026

## Endpoints

### POST /chat/block/:userId

Block a user. Prevents message exchange between the two parties.

**Request**: No body required. `:userId` is the target user's MongoDB ObjectId.

**Headers**: `Authorization: Bearer <jwt>`

**Response 200**:
```json
{ "message": "User blocked successfully", "blockedUserId": "<userId>" }
```

**Response 404**: `{ "message": "User not found" }`
**Response 409**: `{ "message": "User already blocked" }`

---

### DELETE /chat/block/:userId

Unblock a previously blocked user. Restores message exchange.

**Request**: No body required.

**Headers**: `Authorization: Bearer <jwt>`

**Response 200**:
```json
{ "message": "User unblocked successfully", "unblockedUserId": "<userId>" }
```

**Response 404**: `{ "message": "User not found or not blocked" }`

---

### GET /chat/block-list

Returns the list of user IDs blocked by the authenticated user.

**Headers**: `Authorization: Bearer <jwt>`

**Response 200**:
```json
{ "blockedUsers": ["<userId1>", "<userId2>"] }
```

## Socket Guard Behavior

When a message is emitted via the `send_message` socket event:

1. Server extracts `senderId` from the authenticated socket
2. Server checks if `senderId` exists in the recipient's `blockedUsers` array
3. **If blocked**: Message is silently dropped (no error emitted to sender, no delivery to recipient)
4. **If not blocked**: Normal message delivery proceeds
