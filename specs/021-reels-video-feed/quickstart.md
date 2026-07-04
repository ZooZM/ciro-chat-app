# Quickstart: Reels / Short Videos Feed

**Feature**: `021-reels-video-feed`

## Backend (chat-app-backend — NestJS)

```bash
cd "/Volumes/Zeyad/Documents/work/Node js/chat-app-backend"
npm run start:dev
```

- Module: `src/modules/reels/` (registered in `app.module.ts`).
- **v2 requirements**: MongoDB must be running (`npm run docker:local:up` starts the local compose stack). Demo content seeds idempotently into Mongo at first boot. For push notifications set `FIREBASE_SERVICE_ACCOUNT` (JSON string) in the backend env — without it push is disabled (logged warning) but events are still recorded.
- **v3 requirements**: Redis must be running (`REDIS_URL`, in the same compose stack) for the `reels-moderation` BullMQ queue. Moderation provider via env: `MODERATION_PROVIDER=stub` (default — clean verdicts unless the description contains `nsfw-test`; the stub also checks the video path, but Multer randomizes every upload's on-disk filename, so the description marker is the only trigger reachable through the real endpoint) or `MODERATION_PROVIDER=sightengine` + `SIGHTENGINE_API_USER`/`SIGHTENGINE_API_SECRET`. Fail-closed: without a working provider, uploads stay in "Processing" and are retried — they never auto-publish.
- Smoke test (needs a valid access token from the existing auth flow):

```bash
TOKEN=<accessToken>
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels?limit=5" | jq '.items[0]'
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/reel-1" | jq '.id'
curl -s -X POST -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/reel-1/like"
curl -s -X POST -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/reel-1/share"
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/users/mock-user-1/profile" | jq '.stats'
curl -s -X POST -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/users/mock-user-1/follow"
# store-redirect fallback page (public, no token): expect App Store redirect for iPhone UA
curl -s -A "iPhone" -o /dev/null -w "%{http_code} %{redirect_url}\n" "http://localhost:3000/reels/reel-1"

# v2 endpoints
curl -s -X POST -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/<reelId>/view"          # dedup: run twice, count unchanged
curl -s -X POST -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/<reelId>/save"          # {"saved":true}
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/liked?limit=5" | jq '.items|length'
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/saved?limit=5" | jq '.items|length'
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/search?q=trav" | jq '.items[0].hashtags'
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/users/search?q=lin" | jq '.items[0]'
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels?hashtag=travel" | jq '.nextCursor'
curl -s -X POST -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/users/<userId>/block"          # then re-fetch feed: their reels gone

# v3 endpoints (upload + moderation, stub provider)
curl -s -X POST -H "Authorization: Bearer $TOKEN" -F "video=@clean.mp4;type=video/mp4" -F "description=my first reel #test" \
  "http://localhost:3000/api/reels" | jq '.status'                     # "pending_moderation"
# wait a few seconds (stub verdict) then:
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/<newReelId>" | jq '.status'      # "published" (owner + everyone)
curl -s -X POST -H "Authorization: Bearer $TOKEN" -F "video=@clean.mp4;type=video/mp4" -F "description=nsfw-test marker" \
  "http://localhost:3000/api/reels" | jq '.id'                         # stub flags via the description marker
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/<flaggedId>" | jq '.status'      # "rejected" (owner); a second account gets 404
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/<newReelId>"           # {"deleted":true}; re-fetch → 404
```

- Tests: `npm test -- reels`
- Counter integrity check: like a reel twice (on/off) → `likesCount` and the creator's `totalLikes` return to their initial values (no drift).

## Flutter app

1. **New dependencies** (`pubspec.yaml`): `media_kit`, `media_kit_video`, `media_kit_libs_video`, `share_plus` (v1); **v3**: `video_editor` (trim UI) + `ffmpeg_kit_flutter_new` (trim export + thumbnail extraction) — verify current pins on pub.dev (R16). Then `flutter pub get`.
2. **`main.dart`**: add `MediaKit.ensureInitialized();` right after `WidgetsFlutterBinding.ensureInitialized();`.
3. **DI codegen** (new injectables): `dart run build_runner build --delete-conflicting-outputs`.
4. **Base URL**: `.env` `API_URL` must point at the backend (constitution VIII-B); relative media URLs resolve via `UrlUtils.resolveMediaUrl`.
5. Run: `flutter run` (dev) / `flutter run --profile` (performance verification).

## Verify the user stories

1. **US1**: Bottom bar shows a play-circle Reels icon right after Calls (6 tabs, Calls untouched) → tap → full-screen feed auto-plays behind the dark-themed nav bar; swipe up/down navigates; switching tabs silences audio instantly.
2. **US2**: Swipe fast through 20+ videos — instant starts, no stutter; DevTools performance overlay shows no red bars (see research.md R7).
3. **US3**: Love toggles with micro-animation (only the icon rebuilds — check "Track widget rebuilds" in Inspector); Comment opens bottom sheet over the still-playing video; Share opens the custom sheet instantly — top row of recent chats (avatar + name; one tap sends a reelShare message that renders as a rich preview card in the recipient's chat), bottom row Copy Link + "Share via…" (OS sheet); send/copy bumps the share counter, dismissing or OS-sheet shares do not. Returning to the Reels tab after visiting Chats resumes the same video.
4. **US4**: Tap creator name/avatar → profile with avatar/name/bio, follower/following/total-likes stats, 3-column grid; grid tap opens creator-scoped feed at that video.
5. **US5**: Follow flips instantly on overlay; profile shows consistent state + count; self-profile hides the button.
6. **US6 (deep links)**: with the app running (warm) and killed (cold):

```bash
# Android emulator/device
adb shell am start -a android.intent.action.VIEW -d "https://ciro.chat/reels/reel-1"
# iOS simulator
xcrun simctl openurl booted "https://ciro.chat/reels/reel-1"
```

   → app opens on Reels, skeleton while fetching, `reel-1` plays, swiping continues the feed. Also tap a shared link inside a chat message (internal navigation) and try an unknown id (`.../reels/nope` → friendly error + regular feed). Note: verified `https` handling on real devices requires the `ciro.chat` association files; use the custom-scheme fallback (`cirochat://reels/reel-1`) until that's hosted.

7. **US7 (own profile)**: on the Reels feed, your avatar shows top-left (placeholder if none set) → one tap lands on your own reels-style profile with your account picture; no Follow button; back returns to the same video.
8. **US8 (saves & history)**: tap Save (bookmark) on the overlay → flips instantly; own profile shows Videos | Liked | Saved tabs — saved/loved reels appear there, tap plays them in a scoped feed; another user's profile shows no such tabs.
9. **US9 (search & hashtags)**: search icon (top-right on Reels) → type a seeded hashtag fragment → Videos group populates; type a seeded name fragment → Users group populates; tap results (video → feed, user → profile). Tap a `#hashtag` in any description → hashtag feed; tap a `@mention` → that user's profile.
10. **Blocking**: block a creator from their profile → their reels vanish from feed/search/hashtag results on next fetch; a deep link to their reel shows the friendly unknown-reel error.
11. **Notifications** (needs `FIREBASE_SERVICE_ACCOUNT` + a second logged-in device/account): follow someone / like their reel → push arrives ≤10 s; tapping it opens the reel or the follower's profile; liking your own reel produces nothing.
12. **US10 (upload + moderation)** — with `MODERATION_PROVIDER=stub`:
    - Tap the "+" in the Reels top bar → record (camera stops at 60 s) or pick from gallery; picking a >60 s video opens the WhatsApp-Status-style trimmer (select a ≤60 s window) — the video is never rejected for length.
    - Add a description with a `#hashtag` and an `@mention`, submit → upload progress, then your own profile shows the reel with a **"Processing"** badge; a second account sees nothing (feed, profile, search, deep link → friendly unknown-reel error).
    - After the stub verdict: the reel flips to published everywhere, and the mentioned user gets their push **now** (not at upload time) — exactly once.
    - Upload with `nsfw-test` somewhere in the description (the reliable trigger — Multer randomizes every upload's on-disk filename, so a filename marker never reaches the stub provider through the real endpoint) → it flips to **"Removed due to policy violations"** on your profile, you receive the rejection push (tap → your profile), the other account still sees nothing, and no mention push ever fires.
    - Stop Redis or unset provider credentials, upload again → the reel stays "Processing" indefinitely (never publishes unmoderated); restore Redis → the sweep re-enqueues and the verdict lands.
    - Delete a reel (menu on your own grid item, confirm) → gone from every surface on both accounts; its deep link shows the unknown-reel error.

## Performance gates (must pass before merge)

- `flutter run --profile`, 50-video swipe session: no dropped-frame bars; memory flat after window stabilizes (max 3 live players — debug assert enforces).
- Like tap while playing: zero rebuilds outside `LoveButton` subtree; no frame drop.
- Swipe-to-playback ≤300 ms on prepared videos (SC-001); interaction feedback ≤100 ms (SC-006).
