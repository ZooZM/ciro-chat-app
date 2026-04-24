# Quickstart: Optimize Chat Lifecycle (Phase 2)

**Branch**: `003-optimize-chat-lifecycle` | **Date**: 2026-04-25

## Prerequisites

- Flutter SDK `^3.9.2`
- Node.js 18+ (backend)
- Android Studio / Xcode (for platform-specific setup)
- Google Maps API Key (for location features)

## Setup

### 1. Flutter App

```bash
cd E:\zeyad\ciro-chat-app
flutter pub get
```

### 2. New Dependencies (to add)

```yaml
# pubspec.yaml — add these:
google_maps_flutter: ^2.9.0
geolocator: ^12.0.0
geocoding: ^3.0.0
flutter_dotenv: ^5.2.1
```

### 3. Environment File

Create `.env` at the Flutter project root:

```bash
GOOGLE_MAPS_API_KEY=your_api_key_here
```

Add `.env` to `.gitignore`.

### 4. Android Setup

**`android/app/src/main/AndroidManifest.xml`**:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${GOOGLE_MAPS_API_KEY}"/>

<!-- Location permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### 5. iOS Setup

**`ios/Runner/AppDelegate.swift`**:
```swift
import GoogleMaps

// In application(_:didFinishLaunchingWithOptions:):
GMSServices.provideAPIKey("YOUR_API_KEY")
```

**`ios/Runner/Info.plist`**:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Ciro needs your location to share it in chats</string>
```

### 6. Backend

```bash
cd E:\zeyad\chat-app-backend
npm install
npm run start:dev
```

No new backend dependencies required — only schema enum additions.

## Development Commands

```bash
# Run Flutter app
flutter run

# Run code generation (if DI changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Run backend
cd E:\zeyad\chat-app-backend && npm run start:dev

# Run tests
flutter test
cd E:\zeyad\chat-app-backend && npm test
```

## Key Files to Edit

### Backend (NestJS)
| File | Change |
|------|--------|
| `schemas/message.schema.ts` | Add LOCATION, AUDIO, POLL, EVENT to MessageType; extend MessageMetadata |

### Flutter — Domain Layer
| File | Change |
|------|--------|
| `domain/entities/message.dart` | Add system, location, audio, poll, event to MessageType enum |

### Flutter — Data Layer
| File | Change |
|------|--------|
| `data/datasources/chat_local_data_source.dart` | Fix room UPSERT in `saveMessage()` to preserve type/participants/admins |

### Flutter — Presentation Layer
| File | Change |
|------|--------|
| `presentation/widgets/message_bubble_widget.dart` | Add system bubble, location bubble, audio bubble, poll bubble, event bubble renderers |
| `presentation/widgets/attachment_sheet_widget.dart` | Wire Camera, Location, Audio, Poll, Event handlers |
| `presentation/bloc/chat_cubit.dart` | Add sendLocationMessage, sendAudioMessage, sendPollMessage, sendEventMessage methods |
| `presentation/pages/group_info_page.dart` | Connect description to real data; remove mock media section |
