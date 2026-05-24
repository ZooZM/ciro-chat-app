---

description: "Tasks for Persistent Session (009)"
---

# Tasks: Persistent Session (Stay Logged In Indefinitely)

**Input**: Design documents from `/specs/009-persistent-session/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/refresh-error-schema.md, quickstart.md

**Tests**: Unit tests are included for `TokenRefreshService` because its retry/coalescing logic is non-trivial and not exercisable end-to-end without provoking real network failures. UI tests are NOT generated (no UI work in this feature).

**Organization**: Tasks grouped by user story. US1 and US2 are both P1 and share the same `TokenRefreshService`; the split is happy-path (US1) vs. failure-handling (US2).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Different files, no dependency on incomplete tasks
- **[Story]**: US1, US2, or US3 (maps to spec.md user stories)
- File paths are exact and absolute-from-repo-root

## Path Conventions

- **Flutter core**: `lib/core/`
- **Flutter feature**: `lib/features/auth/`
- **Flutter tests**: `test/core/`
- **Backend**: `chat-app-backend/src/modules/auth/` (relative to the Node project root at `/Volumes/Zeyad/Documents/work/Node js/chat-app-backend`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Backend config change + DI registration. No tests yet.

- [X] T001 Update `chat-app-backend/.env` (and `.env.example` if present) to set `JWT_REFRESH_EXPIRES_IN=365d`. Restart the backend after the change.
- [X] T002 In `chat-app-backend/src/modules/auth/auth.service.ts`, change the fallback in `generateAuthResponse()` from `'7d'` to `'365d'` so the default matches the new env value: `const refreshTokenExpiresIn = this.configService.get<string>('JWT_REFRESH_EXPIRES_IN') || '365d';`
- [X] T002a In `chat-app-backend/src/modules/auth/auth.service.ts`, extract the two terminal error messages as exported constants at the top of the file: `export const AUTH_ERR_REVOKED = 'Refresh token revoked';` and `export const AUTH_ERR_INVALID_OR_EXPIRED = 'Invalid or expired refresh token';` Replace the inline literals in `refreshTokens()` with these constants. This makes the Flutter↔Node contract refactor-safe (any rename forces a contract-coordinated change).

**Checkpoint**: Backend now issues 365-day rolling refresh tokens. All existing flows still work; no client change required to observe this.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create the new exception type and the empty `TokenRefreshService` so it can be DI-wired before stories start. Story implementations fill in the method bodies.

- [X] T003 [P] Create `lib/core/error/revocation_exception.dart` containing the `RevocationException` class exactly as specified in [data-model.md](data-model.md) ("New Classes" section).
- [X] T004 [P] Create `lib/core/services/token_refresh_service.dart` with the class declaration, `@lazySingleton` annotation, constructor-injected `AuthLocalDataSource`, and the `Completer<String>? _refreshCompleter` field. Stub the public method `Future<String> refreshTokens()` to throw `UnimplementedError` for now. Stub the private `bool _isRevocationResponse(DioException e)` too. **(Implemented in full — see T006/T007/T013/T014 below; the stub state was elided since all tasks land in the same PR.)**
- [X] T005 Run `dart run build_runner build --delete-conflicting-outputs` (or the project's equivalent) to regenerate `injection.config.dart` so `TokenRefreshService` is registered in `getIt`.
- [X] T005a Update `.specify/memory/constitution.md` section IV-C: change the "Any refresh failure" row of the Token Refresh Lifecycle table to read: *"Both actors → MUST call `tokenRefreshService.refreshTokens()`. Only `RevocationException` triggers `deleteTokens()` + `globalOnUnauthorizedRedirect?.call()`. All other failures retry indefinitely with exponential backoff."* Bump version to `1.3.0` and update the Sync Impact Report at the top of the file. **This task MUST land in the same PR as T015 (the first code change that contradicts the old rule) to keep the repo coherent with its own constitution.**

**Checkpoint**: `getIt<TokenRefreshService>()` resolves. The service does nothing yet; stories below fill it in. The constitution now permits the new revocation-only logout rule.

---

## Phase 3: User Story 1 - User never has to sign in again (Priority: P1) 🎯 MVP

**Goal**: A signed-in user can close the app, leave the device offline for 7+ days, and reopen the app directly into the conversations list without seeing the sign-in screen. Covers FR-001, FR-002, FR-003, FR-007, FR-008, FR-011.

**Independent Test**: Sign in on a fresh install. Use the app briefly. Set the device clock forward 7 days (or actually wait). Reopen the app — user lands on conversations list. In logs, observe exactly one `[TokenRefreshService] Refresh successful` line on the first backend interaction.

### Implementation for User Story 1

- [X] T006 [US1] In `lib/core/services/token_refresh_service.dart`, implement the happy-path branch of `refreshTokens()`: read the refresh token from `_authLocal`, POST to `/auth/refresh` with an isolated `Dio` instance, parse `accessToken` and `refreshToken` from the response, persist via `_authLocal.saveTokens()`, and complete `_refreshCompleter` with the new access token. Add `debugPrint('[TokenRefreshService] Refresh successful')`. Do NOT implement retry or revocation detection here — that is US2.
- [X] T007 [US1] In the same file, implement the Completer-based coalescing gate: at the top of `refreshTokens()`, if `_refreshCompleter != null && !_refreshCompleter!.isCompleted`, return `_refreshCompleter!.future` directly. Otherwise create a new `Completer<String>()`, assign to `_refreshCompleter`, run the refresh, and null out the field in a `finally` block after completion. Add `debugPrint('[TokenRefreshService] Starting refresh')` only on the first caller path. (FR-008)
- [X] T008 [US1] In `lib/core/network/dio_client.dart`, replace the inline refresh block inside `onError` with `final newAccess = await getIt<TokenRefreshService>().refreshTokens();`. Keep the socket re-sync (lines 62-70) and the original-request retry (lines 74-75) using the returned token. Remove the `try/catch` that calls `deleteTokens()` — the catch block will be filled in by US2 to handle `RevocationException` only.
- [X] T009 [US1] In `lib/core/network/socket_service.dart`, replace `_handleTokenRefresh()` so the body just awaits `getIt<TokenRefreshService>().refreshTokens()`, then on success sets `_socket!.auth = {'token': newAccess}` and calls `_socket!.connect()`. Remove the `_isRefreshing` field — concurrency is now handled centrally by the service's Completer.
- [X] T010 [US1] In `lib/features/auth/presentation/bloc/auth_cubit.dart`, change `_proactiveTokenRefreshIfNeeded()` to call `await getIt<TokenRefreshService>().refreshTokens()` when the JWT `exp` is within 5 minutes. Remove the inline `refreshDio` block. Keep the silent-on-error swallow for the proactive path (failures here are non-fatal because the next real request will trigger a retry via the service).
- [X] T011 [P] [US1] Add `token_refresh_service_test.dart` in `test/core/services/` covering the happy path: a single `refreshTokens()` call completes with a new token, stores both tokens via the mocked `AuthLocalDataSource`, and emits the expected `debugPrint` line. Use `mocktail` to fake `AuthLocalDataSource` and a stub `Dio` returning the contract response from [contracts/refresh-error-schema.md](contracts/refresh-error-schema.md).
- [X] T012 [P] [US1] Add a coalescing test in the same file: call `refreshTokens()` 3 times in quick succession; assert the mock backend was hit exactly ONCE and all three callers receive the same access token. (FR-008)

**Checkpoint**: A user with a valid refresh token never sees the sign-in screen due to natural rotation. Concurrent callers do not race.

---

## Phase 4: User Story 2 - Refresh failures do not log the user out (Priority: P1)

**Goal**: Network errors, timeouts, and 5xx responses during refresh never cause logout. Only explicit revocation does. Covers FR-004, FR-005, FR-006, FR-010, FR-012.

**Independent Test**: With app open and signed in, disable network. Trigger an action that forces a refresh (clock forward 16+ min so access token expires). Confirm the app is NOT returned to the sign-in screen. Re-enable network. Confirm action completes and the user remained signed in throughout.

### Implementation for User Story 2

- [X] T013 [US2] In `lib/core/services/token_refresh_service.dart`, implement `_isRevocationResponse(DioException e)`: returns `true` iff `e.response?.statusCode == 401` AND `e.response?.data` is a `Map` AND `data['message']` is one of `"Refresh token revoked"` or `"Invalid or expired refresh token"`. Wraps in a try/catch that returns `false` on any parsing error (treats malformed responses as transient).
- [X] T014 [US2] In the same file, wrap the HTTP refresh call inside `refreshTokens()` in a retry loop. On a caught `DioException`, call `_isRevocationResponse(e)`. If `true`: `_refreshCompleter!.completeError(const RevocationException())`, null out the completer, rethrow. If `false`: sleep with exponential backoff starting at 2s, doubling, capped at 60s; then loop. No max attempt count (FR-004). Add `debugPrint('[TokenRefreshService] Transient failure, retrying in ${delay}s: $e')` and `debugPrint('[TokenRefreshService] Revocation detected: logging out')` at the appropriate branches.
- [X] T015 [US2] In `lib/core/network/dio_client.dart`, the `onError` handler (modified in T008) MUST now wrap the `refreshTokens()` await in a try/catch. Catch only `RevocationException`: call `await _authLocal.deleteTokens()` then `globalOnUnauthorizedRedirect?.call()` and `return handler.next(e)`. Any other thrown error must NOT cause token deletion — it should propagate so the request fails naturally without ending the session.
- [X] T016 [US2] In `lib/core/network/socket_service.dart`, wrap the `refreshTokens()` call (modified in T009) in a try/catch. On `RevocationException`: `await getIt<AuthLocalDataSource>().deleteTokens()` and `globalOnUnauthorizedRedirect?.call()`. On any other error: log and let the socket stay disconnected — it will retry on the next reconnect event.
- [X] T017 [US2] In `lib/features/auth/presentation/bloc/auth_cubit.dart`, the proactive refresh path (modified in T010) should catch `RevocationException` and call `globalOnUnauthorizedRedirect` plus `deleteTokens`. Other exceptions stay silently swallowed (the next real request will surface them).
- [X] T018 [P] [US2] Add a revocation-detection test to `test/core/services/token_refresh_service_test.dart`: stub the mock `Dio` to throw a `DioException` with `response.statusCode == 401` and `response.data == {'message': 'Refresh token revoked'}`. Assert `refreshTokens()` throws `RevocationException` and that `deleteTokens()` was NOT called from inside the service (deletion is caller's responsibility).
- [X] T019 [P] [US2] Add a transient-retry test: stub `Dio` to throw a `DioException` with `type == DioExceptionType.connectionError` twice in a row, then succeed on the third call. Assert `refreshTokens()` returns the new token, the mock was called 3 times, and elapsed time is at least 2s + 4s = 6s (use `fakeAsync` from `package:fake_async` to control timing without real waits).
- [X] T020 [P] [US2] Add a "transient 5xx is retried" test: stub `Dio` to throw a `DioException` with `response.statusCode == 503` once, then succeed. Assert `refreshTokens()` succeeds and `RevocationException` is NOT thrown.
- [X] T021 [P] [US2] Add a "non-terminal 401 is retried" test: stub `Dio` to throw `DioException` with `response.statusCode == 401` and `response.data == {'message': 'Some other error'}`, then succeed. Assert no `RevocationException` is thrown — only the two known message strings are terminal per FR-005.

**Checkpoint**: All FR-004 / FR-005 acceptance scenarios pass. Logout happens only on the two backend signals; everything else retries until success.

---

## Phase 5: User Story 3 - Active sign-out paths still work cleanly (Priority: P2)

**Goal**: All existing sign-out paths (in-app button, backend revocation, password change broadcast, uninstall) continue to work and end the local session promptly. Covers FR-009, SC-003, SC-004.

**Independent Test**: (a) Tap "Sign Out" — within 2s the user lands on the sign-in screen. (b) On a second device, change the password / null the user's `refreshToken` field — the affected device returns to sign-in within 60s of its next backend interaction. (c) Uninstall + reinstall — fresh sign-in required.

### Implementation for User Story 3

- [X] T022 [US3] Manually inspect `lib/features/auth/presentation/bloc/auth_cubit.dart` `logOut()` (lines 150-176): confirm the V-A teardown order is unchanged (ChatCubit.reset → CallCubit.reset → SocketService.disconnect → PushNotificationService.dispose → ChatLocalDataSource.clearAllData → AuthLocalDataSource.deleteTokens). No code changes expected — this is a verification task. **Verified: V-A sequence preserved at auth_cubit.dart:142-156.**
- [X] T023 [US3] Verify that the `RevocationException` catch sites added in T015 / T016 / T017 invoke `globalOnUnauthorizedRedirect`, which already routes through `AuthCubit.logOut()` (via the router's redirect logic in `lib/core/routing/app_router.dart`). If the redirect bypasses the full V-A teardown, add a call to it. Read the router file once and verify. **Finding: previous redirect ONLY navigated to auth screen (steps 1-5 of V-A skipped). Fixed in main.dart:39-48 to invoke `AuthCubit.logOut()` with re-entrancy guard. Removed redundant inline `deleteTokens()` calls from the three catch sites.**
- [ ] T024 [US3] Run the quickstart scenarios 3 (revocation) and 5 (app killed mid-refresh) from [quickstart.md](quickstart.md) on a real device. Document any deviation in a comment on the task. **DEFERRED — requires physical device + backend access; flagged for the human runner.**

**Checkpoint**: Sign-out behaviours unchanged from today. Revocation propagates within 60s. Uninstall path unaffected.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Manual quickstart pass, removal of obsolete code paths, security audit. (Constitution sync was moved to Phase 2 as T005a.)

- [ ] T026 [P] Run quickstart scenarios 1 (happy path), 2 (offline resilience), 4 (concurrent coalescing), 6 (sign-out latency / SC-003), and 7 (cold-start latency / SC-006 / FR-011) from [quickstart.md](quickstart.md). Capture log output and timing measurements as evidence and attach to PR description. **DEFERRED — requires physical device.**
- [X] T027 Audit FR-012 (no security regression):
    a. ✓ `grep -r "deleteTokens" lib/` — only `AuthRepositoryImpl.logout()` calls it (single canonical site); the catch sites now route through `globalOnUnauthorizedRedirect` → `AuthCubit.logOut()` which runs the full V-A teardown.
    b. ✓ `grep -r "accessToken\|refreshToken" lib/` — every read/write flows through `AuthLocalDataSource` (FlutterSecureStorage). No SharedPreferences or plaintext paths.
    c. **DEFERRED — Scenario 3 latency comparison requires a running backend + physical device.**
- [X] T028 Confirm `lib/features/auth/data/repositories/auth_repository_impl.dart` `checkAuthStatus()` still returns `true` based on local-token existence only (no backend round-trip) per the FR-007 cold-start contract. No code change expected — verification only. **Verified at auth_repository_impl.dart:73-83.**

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup, backend)** — independent; can ship before any Flutter work. Backwards-compatible with existing 7-day-token clients.
- **Phase 2 (Foundational)** — depends on nothing; creates the new files and DI registration.
- **Phase 3 (US1)** — depends on Phase 2.
- **Phase 4 (US2)** — depends on Phase 3 (extends the same service and the same DioClient/SocketService call sites modified in US1).
- **Phase 5 (US3)** — depends on Phase 4 (verification of revocation path requires US2's catch sites).
- **Phase 6 (Polish)** — depends on Phases 3-5.

### Within-Story Dependencies

- T002 → T002a (constants extraction comes after the env wiring; same file).
- T006 → T007 (the coalescing gate wraps the happy path).
- T008, T009, T010 each depend on T006/T007 (they call the now-implemented `refreshTokens()`).
- T013 → T014 (retry loop calls the detector).
- T015, T016, T017 each depend on T013/T014 (catch the new exception path).
- T005a (constitution amendment) MUST ship in the same PR as T015 — its purpose is to keep the constitution coherent at the moment the deletion semantics change.
- Tests T011, T012, T018-T021 depend on the implementation tasks they cover being at least drafted (or use stubbed service + mock backend).

### Parallel Opportunities

- T001 and T002 (backend) parallel with everything in Phases 2-3.
- T003 and T004 parallel with each other.
- T008, T009, T010 modify three different files — parallel.
- T015, T016, T017 modify three different files — parallel.
- All test tasks (T011, T012, T018, T019, T020, T021) parallel with each other.

---

## Parallel Example: User Story 1 implementation

```bash
# After T006/T007 land, these three callers can be wired in parallel:
Task: T008 — wire DioClient to TokenRefreshService
Task: T009 — wire SocketService to TokenRefreshService
Task: T010 — wire AuthCubit._proactiveTokenRefreshIfNeeded to TokenRefreshService
```

## Parallel Example: User Story 2 tests

```bash
Task: T018 — revocation detection test
Task: T019 — transient connection retry test
Task: T020 — 5xx retry test
Task: T021 — non-terminal 401 retry test
```

---

## Implementation Strategy

### MVP Scope

**Phases 1 + 2 + 3 = MVP.** Once US1 ships, users with naturally-rotating tokens stop seeing involuntary logouts. The 365d TTL alone (Phase 1) provides immediate user-visible improvement even before Flutter changes ship — clients that get a 365d refresh token from the new backend will simply not hit JWT expiry in any realistic timeframe.

### Incremental Delivery Path

1. **Ship Phase 1 (T001, T002) alone**: backend changes are backwards-compatible. New refresh tokens live for 365 days, immediately reducing involuntary-logout rate.
2. **Ship Phases 2 + 3 (US1, MVP)**: client uses the shared service; coalescing prevents the race that today's ad-hoc refresh has.
3. **Ship Phase 4 (US2)**: retry/backoff means network errors stop causing logouts.
4. **Ship Phase 5 (US3, verification only)** + **Phase 6 (polish, constitution sync)**: final hardening.

### Notes

- `[P]` tasks = different files, no dependency on incomplete tasks above them.
- Each task description has the exact file path; an LLM can complete the task without re-deriving context.
- Backend tasks (T001/T002) live in a different repo from the Flutter tasks — coordinate the deploy order: backend first, then Flutter.
