# Quickstart: Testing Persistent Session (009)

## Prerequisites

- Backend running locally with `.env` updated (see Backend Setup below)
- Flutter app built in debug mode on a physical device or emulator
- Redis running (OTP flow)

---

## Backend Setup

In `chat-app-backend/.env` (or equivalent config):

```
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=365d
```

Restart the backend after changing env vars.

---

## Scenario 1 — Happy path: user stays logged in after token rotation

1. Sign in fresh (clear app data first).
2. Use the app briefly (send a message).
3. Wait 16+ minutes (so the 15-min access token expires naturally).
4. Send another message — the `DioClient` interceptor should silently refresh
   and the message should send without any login prompt.
5. Check logs for `[TokenRefreshService] Refresh successful` and
   **no** `[TokenRefreshService] Revocation detected`.

---

## Scenario 2 — Offline resilience: no logout while offline

1. Sign in and use the app.
2. Enable airplane mode.
3. Wait for a background token expiry cycle (> 15 min).
4. Re-enable network.
5. Send a message — verify it goes through and the user was NOT returned to the
   sign-in screen during the offline period.

---

## Scenario 3 — Revocation: backend-initiated logout propagates

1. Sign in on the device.
2. On the backend (or via a DB client), set the user's `refreshToken` field
   to `null`:
   ```js
   db.users.updateOne({ phoneNumber: '+...' }, { $unset: { refreshToken: '' } })
   ```
3. Wait for the access token to expire (> 15 min) OR trigger a manual 401 by
   temporarily revoking the access token secret.
4. Attempt any action — the app should call `/auth/refresh`, receive
   `"Refresh token revoked"`, and navigate back to the sign-in screen.

---

## Scenario 4 — Concurrent refresh coalescing

1. With network throttled to high latency (Charles Proxy / Network Link
   Conditioner), trigger 3+ HTTP requests simultaneously while the access token
   is expired.
2. In the logs, verify exactly ONE `[TokenRefreshService] Starting refresh`
   log line appears (not three).

---

## Scenario 5 — App killed mid-refresh (cold start recovery)

1. Trigger a refresh (let the token expire, then start an action).
2. Force-kill the app process immediately.
3. Reopen the app — the user should land on conversations, not the sign-in
   screen. The refresh restarts cleanly.

---

## Scenario 6 — Sign-out latency (SC-003)

1. Sign in.
2. Tap "Sign Out" with a stopwatch running (or log `DateTime.now()` at the
   button tap and again at the first `Unauthenticated` state).
3. Verify elapsed ≤ 2 seconds.

---

## Scenario 7 — Cold-start latency unchanged (SC-006, FR-011)

1. Before merging this feature, capture 5 cold-start measurements from app
   launch to "conversations list visible" for a signed-in user.
2. After merging, repeat on the same device/build configuration.
3. Verify the post-merge median is ≤ pre-merge median + 100 ms. Larger
   regressions block release.
