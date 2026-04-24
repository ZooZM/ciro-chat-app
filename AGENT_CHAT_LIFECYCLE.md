# Chat & Call Lifecycle Guide for Frontend Agent

This document explains the architecture and lifecycle of chat sockets, message delivery, and WebRTC calling (P2P and Group) to guide AI agents working on the frontend mobile application.

## 1. WebSocket Lifecycle
The app relies on a persistent WebSocket connection for real-time messaging, presence, and call signaling.

### States
1.  **Disconnected**: The initial state or when the network is lost.
2.  **Connecting**: Attempting to establish a connection using the user's authentication token.
3.  **Connected**: Socket is established. The client immediately listens for missed events or triggers an offline sync (fetching missed messages or status updates).
4.  **Reconnecting**: If the connection drops, the socket manager automatically attempts to reconnect with exponential backoff.
5.  **Teardown/Logout**: On logout, the socket must be explicitly disconnected, and all listeners removed to prevent memory/state leaks.

### Best Practices for Agents
*   Always ensure socket events are handled idempotently. The same event might arrive twice.
*   Do not rely solely on the socket for data integrity; always fallback to REST for missed state (e.g., missed messages during offline periods).

---

## 2. Message Lifecycle (Offline-First)
The app implements a WhatsApp-style offline-first approach. All messages are saved locally (e.g., SQLite/Hive) before being sent.

### Message Statuses
1.  **Pending** (`pending` / `timer icon`): The message is saved to the local database, and the socket is trying to emit it. If offline, it stays here.
2.  **Sent** (`sent` / `single tick`): The server acknowledged receipt of the message via a socket ACK callback. The server has saved it.
3.  **Delivered** (`delivered` / `double tick`): The recipient's device came online, received the message, and emitted a `message_delivered` event back to the server, which relayed it to the sender.
4.  **Read** (`read` / `blue double tick`): The recipient opened the chat view. Their app emitted a `message_read` event to the server, relayed to the sender.

### Flow
1.  **User A sends a message**: Generate a local `uuid` -> Save locally as `pending` -> Emit `send_message` via socket.
2.  **Server ACK**: Server saves message -> Acknowledges client A -> Client A updates local DB to `sent`.
3.  **Delivery**: Server emits `receive_message` to User B. User B's device saves it -> Emits `message_delivered`. Server relays `status_update` to User A. User A updates DB to `delivered`.
4.  **Read**: User B opens chat -> Emits `message_read`. Server relays to User A -> User A updates DB to `read`.
5.  **Offline Sync**: When User A comes back online, they must hit a REST endpoint or sync socket event to fetch statuses of messages sent while they were offline.

---

## 3. P2P Calling Lifecycle (WebRTC)
P2P calls are managed via WebRTC, using the WebSocket connection purely for signaling.

### Signaling Flow
1.  **Initiation**:
    *   Caller creates a WebRTC `RTCPeerConnection`.
    *   Caller creates an `Offer` (SDP) and sets it as local description.
    *   Caller emits `call_initiate` over socket containing the `Offer`.
2.  **Ringing / Answer**:
    *   Callee receives `call_initiate`. App rings.
    *   Callee accepts -> Creates `RTCPeerConnection`.
    *   Callee sets the Caller's `Offer` as remote description.
    *   Callee creates an `Answer` (SDP), sets as local, and emits `call_answer` over socket.
3.  **ICE Candidates**:
    *   Both peers continuously gather ICE Candidates (network paths).
    *   As candidates are gathered, they are sent over socket via `ice_candidate` events.
    *   Peers receive and add these candidates to their `RTCPeerConnection`.
4.  **Connected**: Once ICE negotiation succeeds, peer-to-peer media tracks (audio/video) begin flowing.
5.  **End Call**: Either party emits `call_end`. Both clean up local `RTCPeerConnection` and media streams.

---

## 4. Group Calling Lifecycle
Group calling generally uses a Selective Forwarding Unit (SFU) backend or a Mesh architecture. Assuming a scalable SFU architecture (like mediasoup or WebRTC SFU):

### Signaling Flow
1.  **Join Room**: User emits `join_group_call` to the server.
2.  **Publish (Send Media)**:
    *   User creates a Send Transport.
    *   User creates an `Offer` to publish their media and sends it to the server.
    *   Server replies with an `Answer`.
3.  **Subscribe (Receive Media)**:
    *   For every other user in the group call, the server notifies the new user.
    *   The user creates a Receive Transport for each remote user's media track.
    *   User negotiates `Offer`/`Answer` with the server to pull those tracks.
4.  **Dynamic Changes**:
    *   When someone speaks, server may emit `active_speaker` events.
    *   When someone leaves, server emits `peer_left_call`, and the client cleans up the Receive Transport for that peer.

### Important Note for Agents
*   Always ensure media streams and WebRTC connections are properly disposed of when leaving a call or if the app is paused/closed, otherwise the camera/mic will stay active and leak memory.
