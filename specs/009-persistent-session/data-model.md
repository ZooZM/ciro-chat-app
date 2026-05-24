# Data Model: Persistent Session (009)

No new persistent entities are introduced. The feature reuses the existing
`FlutterSecureStorage` keys (`accessToken`, `refreshToken`) unchanged.

---

## New Classes (in-memory / runtime only)

### `RevocationException`

A custom exception thrown by `TokenRefreshService` when the backend explicitly
signals that the session is no longer valid. It is NOT a domain `Failure`
because it does not return through the repository layer — it is caught directly
by `DioClient` and `SocketService` interceptors to trigger the global logout
sequence.

```dart
// lib/core/error/revocation_exception.dart
class RevocationException implements Exception {
  final String message;
  const RevocationException([this.message = 'Session revoked by server']);
}
```

---

### `TokenRefreshService`

Singleton in `lib/core/services/token_refresh_service.dart`.

| Field | Type | Purpose |
|---|---|---|
| `_refreshCompleter` | `Completer<String>?` | Coalesces concurrent callers behind a single in-flight refresh. Non-null while a refresh is in progress. |
| `_authLocal` | `AuthLocalDataSource` | Reads/writes tokens from `FlutterSecureStorage`. |

| Method | Signature | Behaviour |
|---|---|---|
| `refreshTokens()` | `Future<String>` | Returns the new access token. Retries transient failures with exponential backoff. Throws `RevocationException` on backend revocation. |
| `_isRevocationResponse()` | `bool` (private) | Returns `true` if a `DioException` carries a 401 with message `'Refresh token revoked'` or `'Invalid or expired refresh token'` (backend-permanent errors). |

**State transitions:**

```
Idle (_refreshCompleter == null)
  │
  ├─ refreshTokens() called ──► InFlight (new Completer created)
  │                                │
  │                         ┌──── success ────► Idle, completer resolved with new token
  │                         └──── revocation ──► Idle, completer errored with RevocationException
  │                         └──── transient ───► retry loop (stays InFlight, backs off)
  │
  └─ refreshTokens() called while InFlight ──► awaits existing completer (no new request)
```

---

## Backend: User document (existing, changed field)

| Field | Type | Change |
|---|---|---|
| `refreshToken` | `String?` | Unchanged in structure. Populated with a JWT signed with `JWT_REFRESH_EXPIRES_IN = '365d'` (was `'7d'`). |

No schema migration required — the field already exists; only the token's
embedded `exp` claim changes.

---

## Existing entities unchanged

- `AuthLocalDataSource` / `AuthLocalDataSourceImpl` — no changes
- `DioClient` — internal refresh logic replaced; public API unchanged
- `SocketService` — `_isRefreshing` field removed; `_handleTokenRefresh()` replaced; public API unchanged
- `AuthCubit` — `_proactiveTokenRefreshIfNeeded` delegates to `TokenRefreshService`; public API unchanged
