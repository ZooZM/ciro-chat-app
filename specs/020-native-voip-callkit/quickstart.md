# Quickstart: Native VoIP CallKit Integration

Developer-oriented setup + verification for feature 020. Assumes feature 019 (call audio) is already in place.

## 1. Dependencies

```bash
flutter pub add flutter_callkit_incoming
flutter pub get
```

Run codegen after adding `@lazySingleton`/`@injectable` services:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 2. Platform configuration

### iOS — `ios/Runner/Info.plist`

Extend the existing `UIBackgroundModes` array (currently only `location`):

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>audio</string>
    <string>voip</string>
</array>
```

(CallKit + VoIP push entitlements provisioned per spec Assumptions.)

### Android — `android/app/src/main/AndroidManifest.xml`

Add alongside existing permissions:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

`flutter_callkit_incoming` registers its own call-style foreground service/receivers (per its README) — keep the existing screen-share foreground service entries untouched.

## 3. Wire-up checklist

- [ ] Register `CallKitService` + `AudioRouteService` in DI (`core/di/`).
- [ ] `CallCubit`: generate a `callId` UUID per call; call `CallKitService.showIncoming/startOutgoing/setConnected/endCall` on the **1:1** paths only; subscribe to `CallKitService.actions`.
- [ ] `CallCubit`: write a `CallHistoryRecord` at every terminal transition (table in data-model.md).
- [ ] `push_notification_service.dart`: on `call`-type data push → `CallKitService.showIncoming`.
- [ ] `voice_call_screen.dart` / `video_call_screen.dart`: replace the `_isSpeakerOn` toggle with the **speaker icon** button → `audio_route_picker_sheet`; on connect call `AudioRouteService.start()` + `applyDefaultForCall(isVideo)`.
- [ ] `chat_list_screen.dart`: `_buildBody` index 3 → `const CallsHistoryScreen()`.
- [ ] Logout (§V-A): `CallKitService.endAllCalls()` inside `CallCubit.reset()`.

## 4. Manual verification (maps to Success Criteria)

| Check | Expected | SC |
|---|---|---|
| Lock device, receive 1:1 call | Native incoming UI on lock screen < 5s | SC-001 |
| Answer from lock screen | App opens into active call | US1 |
| End call, open Calls tab | Row present, correct contact/direction/type | SC-002 |
| Background during call | Audio continues both ways | SC-003 |
| Tap speaker icon | Route picker lists Earpiece/Speaker/BT | US3 |
| Select Speaker / BT | Audio moves < 1s; icon updates | SC-004/005 |
| Disconnect BT mid-call | Auto-fallback to default; icon updates | FR-VoIP-09 |
| Speaker on, listen | NS still effective (no garbled consonants) | SC-006 |
| Force-kill app, receive call | Rings natively; answer opens call | SC-008 |
| End abnormally (kill network) | No ghost ongoing-call indicator | SC-007 |
| Missed call | Row red, name+arrow red | FR-VoIP-04 |
| Search in Calls | List filters by contact | FR-VoIP-04 |

## 5. Tests

```bash
flutter test test/features/call_history/
```

- `CallHistoryCubit` load/search (bloc_test + mocktail).
- `CallHistoryLocalDataSource` insert/watch/search (in-memory sqflite).
- `AudioRouteService` regression: `CallAudioConfig.captureOptions` unchanged after `selectRoute` (SC-006).
- Group-call path writes a history row but does NOT call `CallKitService` (R2).

## 6. Guardrails (do not regress)

- Never modify `CallAudioConfig` or `CallAudioSessionService` configuration.
- Route audio only through `Hardware.instance`.
- Socket payload reads use `Map<String,dynamic>.from(data)` (§IV-A).
- Cancel all subscriptions in `dispose`/`close` (§V); use `INSERT OR REPLACE` on `call_history.id` (§III).
