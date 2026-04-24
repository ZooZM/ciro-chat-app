# Feature Specification: Optimize Chat Lifecycle

**Feature Branch**: `003-optimize-chat-lifecycle`  
**Created**: April 24, 2026  
**Status**: Draft  
**Input**: User description: "Conduct a comprehensive review and optimization of the Chat feature (both P2P and Group Chat). Requirements: 1. Logic Alignment: Ensure the frontend implementation strictly follows the Chat, Voice, and Video call Lifecycle defined in the backend's .md file @E:\zeyad\ciro-chat-app\AGENT_CHAT_LIFECYCLE.md. 2. Optimization over Refactoring: Focus on improving and refining the existing code and fixing bugs rather than rewriting the architecture from scratch. 3. Core Usage: Strictly use existing constants, theme data, and utility classes from the 'lib/core/' directory. Replace any hardcoded strings, colors, or icons with their corresponding 'const' versions from core. 4. Call Integration: Verify that Voice and Video call triggers are properly hooked into the chat lifecycle without breaking the P2P message flow. 5. Performance: Optimize Cubit states to prevent unnecessary UI rebuilds during real-time socket updates."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Real-time Chat Experience (Priority: P1)

Users should experience a seamless, lag-free real-time P2P and Group chat experience without unnecessary UI stutters or rebuilds when receiving rapid socket updates.

**Why this priority**: Core functionality of the chat application relies on a responsive messaging experience.

**Independent Test**: Can be fully tested by sending multiple rapid messages in P2P and Group chats and verifying the UI remains responsive and does not needlessly rebuild non-affected widgets.

**Acceptance Scenarios**:

1. **Given** an active chat view, **When** rapid socket updates (typing status, online status) occur, **Then** only the relevant UI components update without rebuilding the entire list.
2. **Given** a high volume of incoming messages, **When** received in a Group Chat, **Then** the application processes them smoothly without performance degradation.

---

### User Story 2 - Non-Intrusive Call Integration (Priority: P1)

Users receiving or initiating Voice and Video calls should not have their text chat flow interrupted. The call state should act as an overlay or distinct state.

**Why this priority**: Essential to strictly follow the Chat and Call lifecycle without degrading the text messaging experience.

**Independent Test**: Can be fully tested by initiating a call while actively typing or reading messages, ensuring the chat UI remains accessible or gracefully manages the call UI.

**Acceptance Scenarios**:

1. **Given** a user is typing a message, **When** an incoming call occurs, **Then** the call UI appears as an overlay, and text chat state is preserved.
2. **Given** an ongoing voice call, **When** navigating the chat view, **Then** the chat messages can still be read and sent without affecting the active call.

---

### User Story 3 - Codebase Consistency (Priority: P2)

The chat feature strictly adheres to the core design system and utility classes, ensuring visual and architectural consistency.

**Why this priority**: Reduces technical debt and ensures a uniform aesthetic across the app.

**Independent Test**: Can be tested by verifying that no hardcoded strings, colors, or icons are used in the chat feature UI, and all styling comes from `lib/core/`.

**Acceptance Scenarios**:

1. **Given** the chat UI, **When** rendering components, **Then** only constants and theme data from `lib/core/` are applied.

### Edge Cases

- What happens when a socket reconnects during an active call?
- How does system handle incoming calls when the user is already in a call?
- How are missed events handled if the socket drops briefly during high message throughput?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST process real-time socket updates via `ChatCubit` without causing full-page UI rebuilds.
- **FR-002**: System MUST manage Voice and Video call states as a separate layer or distinct state in `SocketService` and `ChatCubit` to prevent disruption of text chat.
- **FR-003**: System MUST align the frontend implementation with the Chat, Voice, and Video call Lifecycle defined in `AGENT_CHAT_LIFECYCLE.md`.
- **FR-004**: System MUST strictly use constants, theme data, and utilities from `lib/core/` for all chat-related UI components.
- **FR-005**: System MUST preserve the P2P message flow integrity when call triggers (initiate, answer, end) are received via the socket.

### Key Entities

- **ChatCubit State**: Represents the current UI state of the chat, optimized for targeted rebuilds.
- **SocketService State**: Represents the real-time connection and event handling logic, separating messaging and calling events.
- **Call Overlay/State**: The representation of an active or incoming Voice/Video call.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: UI rebuilds during real-time typing or status updates are reduced to only affected widgets (measured via Flutter DevTools).
- **SC-002**: 100% of hardcoded strings, colors, and icons in the chat feature are replaced with `lib/core/` equivalents.
- **SC-003**: Initiating or receiving a call during an active text chat preserves the typed text and scroll position.
- **SC-004**: Socket event handling accurately implements the states outlined in `AGENT_CHAT_LIFECYCLE.md` (Connecting, Connected, Reconnecting, etc.).

## Assumptions

- The existing `ChatCubit` and `SocketService` provide a foundation that can be refactored into without a complete rewrite.
- `AGENT_CHAT_LIFECYCLE.md` is the absolute source of truth for the socket and call lifecycle.
- UI overlay mechanisms (like Flutter's `Overlay` or state-driven dialogs/bottom sheets) are acceptable for non-intrusive call handling.
