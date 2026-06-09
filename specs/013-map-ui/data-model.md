# Data Model: Map UI

**Feature**: `013-map-ui`  
**Date**: 2026-06-09  
**Note**: All entities in this document are **mock data models** used purely for UI population. No persistence or backend contracts.

---

## Entity Definitions

### MockUser

Represents a user shown on the map or in the reels/status viewer.

| Field          | Type              | Description                                             |
|----------------|-------------------|---------------------------------------------------------|
| `id`           | `String`          | Unique identifier (used as key in widget trees)         |
| `name`         | `String`          | Display name shown under avatar marker and in sheets    |
| `initial`      | `String`          | Single character initial, shown when no avatar photo    |
| `avatarUrl`    | `String?`         | Network URL for the user's profile photo (nullable)     |
| `isOnline`     | `bool`            | Online/offline status; drives border and dot color      |
| `locationLabel`| `String`          | Human-readable location string, e.g. "Near Zamalek, Cairo" |
| `avatarBgColor`| `Color`           | Background color for the initial-letter avatar fallback |

---

### MockMapMarker

Represents a pinned user on the map.

| Field          | Type              | Description                                               |
|----------------|-------------------|-----------------------------------------------------------|
| `user`         | `MockUser`        | Associated user entity                                    |
| `latitude`     | `double`          | Geographic latitude for map placement                     |
| `longitude`    | `double`          | Geographic longitude for map placement                    |
| `isCurrentUser`| `bool`            | If true, marker is labeled "You" and uses photo style     |

---

### MockStatus

Represents a single status/reel item in the immersive viewer.

| Field          | Type              | Description                                                         |
|----------------|-------------------|---------------------------------------------------------------------|
| `id`           | `String`          | Unique identifier                                                   |
| `author`       | `MockUser`        | The user who posted the status/reel                                 |
| `mediaUrl`     | `String`          | Network URL for the background image or video thumbnail             |
| `caption`      | `String`          | Text caption overlaid at the bottom of the screen                   |
| `timestamp`    | `DateTime`        | When the status was posted; displayed as relative time ("2h ago")   |
| `likeCount`    | `int`             | Number of likes shown in the right-side action column               |
| `commentCount` | `int`             | Number of comments                                                  |

---

### MapFilterState

Represents the current state of filters applied in the filter sheet. Stored as local widget state (no Cubit).

| Field              | Type              | Description                                                     |
|--------------------|-------------------|-----------------------------------------------------------------|
| `searchQuery`      | `String`          | Text typed in the filter search bar                             |
| `selectedStatus`   | `StatusFilter`    | Enum: `all`, `online`, `offline`                                |
| `selectedGroupIds` | `List<String>`    | IDs of selected group filter chips                              |
| `maxDistanceKm`    | `double`          | Distance slider value in kilometers (0–100)                     |

---

## Mock Data Seed

All mock data is defined in a single file: `lib/features/map/presentation/mock/map_mock_data.dart`.

### MockUsers seed

```
[
  { id: 'u1', name: 'You', initial: 'Y', avatarUrl: '<photo_url>', isOnline: true, locationLabel: 'Zamalek, Cairo', avatarBgColor: Colors.grey },
  { id: 'u2', name: 'Mahmoud', initial: 'M', avatarUrl: null, isOnline: true, locationLabel: 'Al Dhahab Island, Cairo', avatarBgColor: Color(0xFFB0BEC5) },
  { id: 'u3', name: 'Amr', initial: 'A', avatarUrl: null, isOnline: true, locationLabel: 'Qasr El Nil, Cairo', avatarBgColor: Color(0xFFFCB64F) },
  { id: 'u4', name: 'Ahmed', initial: 'A', avatarUrl: '<photo_url>', isOnline: false, locationLabel: 'Doqi, Cairo', avatarBgColor: Colors.grey },
  { id: 'u5', name: 'Omar Hassan', initial: 'O', avatarUrl: '<photo_url>', isOnline: true, locationLabel: 'Near Zamalek, Cairo', avatarBgColor: Colors.teal },
]
```

### MockMapMarkers seed

Placed around Cairo (Zamalek/Nile area) to match mockup screenshots:

```
[
  { user: u1, latitude: 30.0626, longitude: 31.2197, isCurrentUser: true },
  { user: u2, latitude: 30.0680, longitude: 31.2260, isCurrentUser: false },
  { user: u3, latitude: 30.0550, longitude: 31.2230, isCurrentUser: false },
  { user: u4, latitude: 30.0490, longitude: 31.2100, isCurrentUser: false },
]
```

### MockStatus seed

```
[
  { id: 's1', author: u1, mediaUrl: '<portrait_photo_url>', caption: 'Good morning!', timestamp: now-2h, likeCount: 14, commentCount: 3 },
  { id: 's2', author: u5, mediaUrl: '<portrait_photo_url>', caption: 'Status & Explore', timestamp: now-5h, likeCount: 31, commentCount: 7 },
]
```
