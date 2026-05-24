# Research: Persistent Session (009)

## Decision 1 — Refresh token lifetime

**Decision**: Extend `JWT_REFRESH_EXPIRES_IN` from `7d` to `365d` on the backend.

**Rationale**: The current 7-day JWT TTL is the root cause of "I was offline for 10 days and got logged out". Because `generateAuthResponse` issues a new refresh token on every successful refresh, the 365-day window is rolling — any app open resets it. A user who opens the app once a month stays logged in indefinitely. Only a user who goes 365 days without opening the app would see a session end, which is indistinguishable from an uninstall.

**Alternatives considered**:
- `'3650d'` (10 years): meets the spec but feels unbounded; 365d rolling is a reasonable security/UX balance and satisfies all spec test scenarios (including the 7-day offline test).
- Non-expiring JWT (no `expiresIn`): removes the safety-net entirely. Rejected because the DB-stored token rotation already provides revocation; we don't need to remove the TTL safety net entirely.
- Opaque refresh token (not JWT): clean but requires a DB lookup on every refresh rather than JWT signature verification. Rejected as a larger backend refactor with no spec requirement.

---

## Decision 2 — Revocation signal detection

**Decision**: Inspect `DioException.response?.data['message']` for the literal string `'Refresh token revoked'`. All other 401 messages (including `'Invalid or expired refresh token'`) and all non-401 errors are treated as transient and trigger retry — not logout.

**Rationale**: The backend already emits two distinct messages from `refreshTokens()` in `auth.service.ts`:
- `'Refresh token revoked'` — the stored token doesn't match; this is an explicit backend revocation (terminal per FR-005).
- `'Invalid or expired refresh token'` — JWT verification failed. With a 365-day TTL this is only triggered after true long-term non-use, which is acceptable as a terminal condition too. We detect this the same way.

Both 401s map to "session is definitively over". All other errors (network error, 5xx, timeout) do NOT map to revocation and must retry.

**Alternatives considered**:
- Check HTTP status code only (any 401 = logout): too broad; a transient backend 401 due to a clock issue would log the user out.
- Custom HTTP header from backend: cleaner but requires backend changes beyond TTL extension. Rejected in favor of reusing existing message strings.

---

## Decision 3 — Concurrent refresh coalescing

**Decision**: A `Completer<String>?` field in `TokenRefreshService`. If `_refreshCompleter` is non-null, subsequent callers await `_refreshCompleter!.future` instead of starting a new refresh. The completer resolves with the new access token or throws.

**Rationale**: `DioClient` interceptors are called concurrently for each in-flight HTTP request. Without coalescing, 5 simultaneous 401 responses would fire 5 parallel refresh calls, each receiving a new token and storing it — but only the last writer's token matches what the backend stored, invalidating all earlier ones. This is a race that causes spurious logouts. The `Completer` pattern is standard Dart for "gate multiple awaiters behind one async operation".

**Alternatives considered**:
- `Mutex` package: explicit mutual exclusion; heavier. The `Completer` pattern is lighter and idiomatic.
- `_isRefreshing` boolean flag (already used in `SocketService`): only prevents duplicate starts; callers that were blocked still need to be notified of the result. `Completer` handles both.

---

## Decision 4 — Retry strategy for transient failures

**Decision**: Exponential backoff starting at 2 seconds, doubling each attempt, capped at 60 seconds. No maximum attempt count — retries continue until the operation succeeds or a revocation signal is received. The retry loop lives in `TokenRefreshService.refreshTokens()`.

**Rationale**: FR-004 requires "retry indefinitely … until credential rotation succeeds or the backend explicitly revokes the session". A capped retry count would violate this. The backoff cap at 60s prevents flooding the server during sustained outages.

**Alternatives considered**:
- Linear backoff: simpler but hammers the server during an outage.
- Fixed retry interval: same problem.
- Retry count limit: explicitly excluded by FR-004.

---

## Decision 5 — TokenRefreshService placement and DI

**Decision**: New `@lazySingleton` class `TokenRefreshService` in `lib/core/services/token_refresh_service.dart`. Both `DioClient` and `SocketService` receive it via constructor injection (get_it / injectable).

**Rationale**: Today both `DioClient` and `SocketService` each embed their own ad-hoc refresh Dio + delete-on-failure logic. They share no state so concurrent refreshes from both paths can race. Extracting into a shared singleton gives the single Completer-based mutex that prevents all races.

**Alternatives considered**:
- Keep refresh in `DioClient` and have `SocketService` call `DioClient` for refresh: creates a dependency from `SocketService` → `DioClient` which is architecturally backwards (network services shouldn't depend on each other).
- Keep both independent with a shared flag in a different singleton: harder to coalesce the result correctly.

---

## Decision 6 — App startup credential check

**Decision**: `AuthRepositoryImpl.checkAuthStatus()` continues to return `true` if a token string exists locally, without verifying it against the backend. `AuthCubit.verifyAuthStatus()` navigates to home on `true`, and `_proactiveTokenRefreshIfNeeded` now uses `TokenRefreshService` to attempt a refresh if the token is near expiry.

**Rationale**: FR-007 says the sign-in screen MUST only appear if credentials are explicitly rejected as revoked. Local existence of a token is sufficient to navigate home; the next real backend call will catch any revocation. This preserves the current fast cold-start path (SC-006).

**Alternatives considered**:
- Validate token against backend on every cold start: adds ~300ms to every app open and fails offline cold-starts. Rejected.
