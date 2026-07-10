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
- **v4 requirements**: reporting/moderation env — `REEL_REPORT_AUTOHIDE_THRESHOLD` (default 25; set to `3` locally to test the auto-hide loop without 25 accounts), `REEL_REPORT_DAILY_LIMIT` (default 20), `ADMIN_API_KEY` (any secret string; guards the admin moderation endpoints — never ship a default).
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

# v4 endpoints (reporting + reposting/feed tabs; run with REEL_REPORT_AUTOHIDE_THRESHOLD=3 for a quick loop)
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"reason":"spam"}' "http://localhost:3000/api/reels/<reelId>/report"            # {"reported":true,"alreadyReported":false}
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"reason":"other","customReason":"misleading edit"}' "http://localhost:3000/api/reels/<reelId>/report"  # duplicate → alreadyReported:true, count unchanged
# report from 2 more accounts (threshold 3) → reel auto-hides: owner sees status "hidden", others get 404
curl -s -H "x-admin-key: $ADMIN_API_KEY" "http://localhost:3000/api/reels/moderation/hidden" | jq '.items[0].reports'
curl -s -X PATCH -H "x-admin-key: $ADMIN_API_KEY" -H "Content-Type: application/json" \
  -d '{"action":"restore"}' "http://localhost:3000/api/reels/<reelId>/moderation"     # {"status":"published"}; reel now immune to auto-hide (adminRestored)
curl -s -X POST -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/<reelId>/repost"          # {"reposted":true} (not on own reels → 400)
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/following?limit=5" | jq '.items[].repostedBy'  # all null — originals only
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels?limit=10" | jq '[.items[]|select(.repostedBy!=null)]'  # follower sees injected repost
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/reels/<reelId>/repost"        # {"reposted":false}; injected item gone next fetch
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
13. **US11 + US12 (reporting, reposting, feed tabs)** — set `REEL_REPORT_AUTOHIDE_THRESHOLD=3` locally; use two accounts, A follows B:
    - **Action column layout**: every reel shows Love, Comment, Share, **Repost** (repeat glyph — Save's former slot), then the 3-dots entry. The 3-dots sheet carries **Save** for everyone plus **Report** (others' reels) or **Delete** (your own). Save/unsave from the sheet still updates the Saved list (US8 regression).
    - **Report flow**: on another creator's reel, 3-dots → Report → reasons sheet (Spam / Nudity / Violence / Hate Speech / Other); choosing Other reveals a required text field (whitespace-only stays disabled); submit → confirmation snackbar, playback never pauses. Reporting the same reel again quietly no-ops.
    - **Auto-hide**: report the same reel from 3 accounts → it vanishes for everyone (feeds, search, profile grid, deep link → unknown-reel error) from the next fetch; the owner sees an **"Under review"** badge on their profile. Restore via the admin curl (§Backend) → visible again with prior likes/comments intact; further mass-reporting never re-hides it (`adminRestored` immunity).
    - **Repost**: on B's account, tap Repost on a reel by C → icon flips to the active state instantly; on your own reel the icon is hidden/disabled. On A's **For You** tab the reel appears with a "**B reposted**" pill above C's name (badge is not tappable — tapping there pauses/resumes); B sees "**You reposted**" on it. The reel never appears twice in one session (scroll on — no duplicate).
    - **Following tab**: A's Following tab shows only originals created by B (and other followees) — no reposts, no badge; empty state when following no one. Switching Following ↔ For You: outgoing audio stops instantly, each tab resumes its own position, first video plays ≤2 s.
    - **Un-repost / cleanup**: B un-reposts → gone from A's For You on next fetch; A blocks B → B's repost injections disappear while C's original may still surface organically without a badge.
14. **Report rate limit**: with `REEL_REPORT_DAILY_LIMIT=2` locally, a third report attempt the same day is declined with a non-intrusive notice and records nothing.
15. **US13 (camera-first creation)** — real device recommended (camera + mic):
    - **Capture screen**: tap "+" on the Reels top bar → full-screen live preview with exactly: red record button (bottom center), gallery thumbnail (bottom left), flip + flash (top right), `Video | 15s | 30s | 60s` selector above the record button (60s pre-selected) — nothing else. Flip switches cameras; the flash control disappears on the front camera.
    - **Recording**: tap record → the button flips to the recording shape **immediately** (optimistic, no perceived freeze while the platform call runs); progress ring runs; with 15s selected recording auto-stops at 15 s and lands **directly in the trimmer** (no preview step); a second tap stops earlier; a sub-second tap-tap is discarded with a notice and the camera stays ready. The selector is disabled while recording.
    - **Record-start/stop robustness (B1/B2 regression)**: double-tap the record button as fast as possible at start — it must NOT crash or start two recordings (busy-guarded). Tap record then stop almost immediately (a very short clip) — the stop is padded to a safe minimum so `stopVideoRecording()` never crashes the plugin, and the clip is still discarded as "too short". Let a recording auto-stop at the cap while also tapping stop by hand — no double side effect (the captured clip is never overwritten by a discard).
    - **Permissions**: deny camera/mic (fresh install or Settings) → the capture screen shows the explanation state with an open-settings path, never a black preview; the gallery path still works.
    - **Trimmer**: for a 15s recording the selectable segment maxes at 15 s; for a gallery video at 60 s; the CTA reads **"Next"**. Backing out asks to discard and returns to the camera. iOS regression: pick a gallery video whose path contains spaces — trimming must still succeed (safe-path copy).
    - **Post details**: only the description field (left), preview thumbnail (right), and **Post** button (bottom). Typing `@` lists followed users (≤300 ms), narrowing per keystroke; tapping one inserts `@username ` and closes the panel; deleting the `@`, typing a space, or blurring closes it too; with an account following no one, no panel appears and typing is unaffected.
    - **Next → post transition (B3 regression)**: tapping "Next" in the trimmer shows the export loading, then goes **straight to the post-details screen** — the live camera screen must NOT flash between the trimmer and the post screen. Backing out of the post screen returns to the trimmer (not the camera); backing out of the trimmer returns to the camera.
    - **Submit**: Post → upload progress → reel shows "Processing" on your profile and the full US10 moderation loop (§12) proceeds unchanged; mention notifications fire at publish for suggestion-completed mentions.
    - **Cleanup**: abandon the flow after recording (confirm discard) → no phantom reel, and `reels_tmp` is empty on next entry.

## Performance gates (must pass before merge)

- `flutter run --profile`, 50-video swipe session: no dropped-frame bars; memory flat after window stabilizes (max 3 live players — debug assert enforces).
- Like tap while playing: zero rebuilds outside `LoveButton` subtree; no frame drop.
- Swipe-to-playback ≤300 ms on prepared videos (SC-001); interaction feedback ≤100 ms (SC-006).
- **v4**: Following ↔ For You switch — first video playing ≤2 s, never two audible videos during the transition (SC-023); repost toggle + save-from-sheet reflect ≤100 ms with no frame drop (SC-012); repost badge renders without overlay rebuild storms (FR-014 applies to the badge leaf).
- **v5**: "+" → live camera preview ≤2 s; record start/stop feedback ≤200 ms (SC-024); auto-stop at the cap ±0.5 s and no upload >60 s (SC-025); mention panel ≤300 ms with zero visible input lag while filtering (SC-026); capture → submitted reel in ≤5 taps + text (SC-027).
