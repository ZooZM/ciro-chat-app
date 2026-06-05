# Feature: Group Voice Call UI Redesign

## Overview

Redesign the group voice/audio call screens (outgoing, incoming, and active call) to match the provided mockup designs. The UI focuses on a clean, WhatsApp-style dark-gray aesthetic with a centered group avatar, participant tile grid, and a minimal 4-button control bar.

---

## Scope

- **Outgoing (Waiting) Screen**: Shown when the local user starts a group call and waits for others to join.
- **Incoming Screen**: Shown when the user receives a group call invite.
- **Active Call Screen**: Shown once at least one remote participant has joined.
- **Voice-only mode**: Camera is off by default; the layout uses colored letter tiles instead of video feeds.

---

## Functional Requirements

### FR-01: Outgoing / Waiting Screen
- Display group name centered at the top in bold white text.
- Show subtitle "Waiting for other people to join…" in muted gray below the group name.
- Render a large centered white circle containing a green group-call icon.
- Show a row of 4 action buttons: Mic toggle, Speaker toggle (active/green by default), Camera-off, Add Participant.
- Show a full-width red "End Call" button at the bottom.
- Background color: dark gray (`#616161`).

### FR-02: Incoming Screen
- Display group name centered at the top in bold white text.
- Show subtitle "Group call" in muted gray.
- Render the same large centered group icon as FR-01.
- Show a bottom card (rounded dark panel) containing:
  - Green presence dot + "{callerName} is calling you" text.
  - Stacked overlapping mini circular avatars (showing up to 3 participants already in call).
  - Two full-width buttons side by side: **Ignore** (red) and **Join** (green).
- Background color: dark gray (`#616161`).

### FR-03: Active Call Screen
- Show group name, call timer ("00:04"), and participant count ("N participants") centered at top.
- Render a 2-column grid of colored participant tiles:
  - Each tile shows participant's initial letter (large, centered) and first name below.
  - Muted participants show a mic-off badge (small white circle with mic-off icon) in top-right corner.
  - Local user tile: teal/cyan color, labeled "You".
  - Remote participants: varied colors (green, dark-green, purple, light-gray, etc.).
  - When 5 or fewer participants: 2x2 grid + 1 centered bottom tile layout.
  - When more than 6 participants: standard 2-column scrollable grid.
- Same 4 action buttons and red End Call button at the bottom as FR-01.
- Screen share and recording buttons are accessible via overflow but not shown in primary bar.

### FR-04: Controls Bar (shared)
- 4 circular icon buttons arranged in a single horizontal row:
  1. **Mic** — gray background, toggle mute/unmute
  2. **Speaker** — white/green background (active by default)
  3. **Camera** — gray background, camera-off icon (voice call default)
  4. **Add Participant** — gray background
- Full-width red "End Call" button below the icon row.
- Controls rendered over a semi-transparent dark overlay panel at the bottom of the screen.

### FR-05: Voice-first Mode
- When the call is started as a voice call (`isVideo = false`), camera is off by default.
- Participant tiles always show avatar letter (no video feed shown in voice mode).
- The camera button allows switching to video mid-call.

---

## User Scenarios

### Scenario 1: User initiates a group voice call
1. User taps "Group Voice Call" in a group chat.
2. Outgoing screen appears with group name + "Waiting for others…" + group icon.
3. Other participants join → active call screen replaces outgoing screen.

### Scenario 2: User receives an incoming group call
1. User is notified of an ongoing group call.
2. Incoming screen appears: group name, "Group call", caller info card.
3. User taps **Join** → transitions to active call screen.
4. User taps **Ignore** → screen dismisses.

### Scenario 3: User in active group call
1. Active call screen shows participant grid with timers/counts.
2. User can mute/unmute mic, toggle speaker, toggle camera, or add participant.
3. User taps "End Call" → call ends and returns to chat.

---

## Success Criteria

- All 3 screens visually match the provided mockup designs pixel-accurately.
- Transitions between screens (outgoing → active, incoming → active) work without flicker.
- Participant count and call timer update live during the call.
- Mic mute state is reflected immediately on both local and remote tiles.
- Screen renders correctly for 1–8 participants without layout overflow.

---

## Assumptions

- The call type (voice vs video) is determined by the `isVideo` flag in `CallActive` state.
- The group name comes from the existing `CallActive` state or a passed parameter.
- Speaker button toggles audio output route (earpiece vs. speaker) — implementation detail TBD.
- Participant avatars use first letter of their display name/phone number.
- Colors for avatar tiles are assigned deterministically by participant index.
- Screen share and recording remain available but are moved out of the primary control bar.
