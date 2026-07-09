# Data Model: Dynamic Group Call Screen

**Feature**: 023-dynamic-group-call  
**Date**: 2026-07-09  

## Entities

### CallParticipant

Represents a single participant in the mock group call.

| Field           | Type     | Description                                                    |
|-----------------|----------|----------------------------------------------------------------|
| `id`            | `String` | Unique identifier for the participant                          |
| `name`          | `String` | Display name (e.g., "Ahmed", "Sara")                           |
| `avatarUrl`     | `String` | URL or asset path for the participant's avatar image           |
| `backgroundColor` | `Color`  | Vibrant solid background color (purple, blue, yellow, pink)   |
| `isVideoOn`     | `bool`   | Whether the participant has their video enabled                |
| `isMuted`       | `bool`   | Whether the participant's microphone is muted                  |
| `isSpeaking`    | `bool`   | Whether the participant is currently the active speaker        |
| `isLocal`       | `bool`   | Whether this is the local user                                 |

### GroupCallLayoutType (enum)

Determines the layout strategy based on participant count.

| Value          | Condition             | Layout Description                                     |
|----------------|-----------------------|--------------------------------------------------------|
| `p2p`          | count == 2            | Full-screen remote + floating PIP local               |
| `triSplit`     | count == 3            | Top half full-width + bottom half split into 2 columns |
| `grid`         | count >= 4            | 2-column grid (scrollable if > 6)                      |
| `waiting`      | count <= 1            | Single full-screen local + waiting message             |

## Relationships

- `GroupCallLayoutType` is derived from `CallParticipant` list length.
- Each `CallParticipant` maps to exactly one participant cell in the layout.
- The local participant (`isLocal == true`) always exists and is included in the count.

## State Transitions

```
waiting (1) → p2p (2) → triSplit (3) → grid (4–6+)
```

Layout switches instantly based on `_participantCount` changes. No animation between layout types.

## Mock Data

A static list of 6 `CallParticipant` objects with pre-assigned vibrant colors:

| Index | Name       | Color   | isVideoOn | isMuted | isSpeaking |
|-------|------------|---------|-----------|---------|------------|
| 0     | (Local)    | Purple  | false     | false   | false      |
| 1     | "Ahmed"    | Blue    | true      | false   | false      |
| 2     | "Sara"     | Yellow  | false     | true    | false      |
| 3     | "Khaled"   | Pink    | false     | false   | true       |
| 4     | "Nour"     | Orange  | true      | false   | false      |
| 5     | "Layla"    | Teal    | false     | true    | false      |
