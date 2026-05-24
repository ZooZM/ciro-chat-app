# Contract: POST /auth/refresh — Error Responses

This contract governs how the Flutter client interprets error responses from
`POST /auth/refresh`. The client's revocation detection logic in
`TokenRefreshService._isRevocationResponse()` depends on these message strings
being stable.

---

## Success (200 OK)

```json
{
  "accessToken": "<JWT>",
  "refreshToken": "<JWT>",
  "user": { ... }
}
```

The client stores both tokens via `AuthLocalDataSource.saveTokens()` and
resolves the in-flight `Completer` with `accessToken`.

---

## Terminal failure — session is over (401 Unauthorized)

These responses cause `RevocationException` to be thrown, triggering the global
logout sequence. The `message` field is the discriminator.

| Scenario | `message` |
|---|---|
| Stored refresh token in DB was nulled or replaced | `"Refresh token revoked"` |
| Refresh token JWT signature invalid or TTL expired | `"Invalid or expired refresh token"` |

```json
{
  "statusCode": 401,
  "message": "Refresh token revoked",
  "error": "Unauthorized"
}
```

```json
{
  "statusCode": 401,
  "message": "Invalid or expired refresh token",
  "error": "Unauthorized"
}
```

**Client rule**: `statusCode == 401 && message ∈ {"Refresh token revoked", "Invalid or expired refresh token"}` → `RevocationException`.

---

## Transient failure — retry required (everything else)

Any response not matched by the terminal rule above is treated as transient.
This includes:

| Status | Example cause |
|---|---|
| No response (network error / timeout) | Device offline, DNS failure |
| 5xx | Backend crash, deploy in progress |
| 429 | Rate limiting |
| Any 401 with a different message | Clock skew, unexpected backend error text |

**Client rule**: retry with exponential backoff (2s → 4s → 8s … 60s cap). No
maximum retry count. The retry loop exits only when a success or terminal
failure is received.

---

## Stability guarantee

The two terminal `message` strings (`"Refresh token revoked"` and `"Invalid or
expired refresh token"`) are part of this contract. Any backend change that
renames or removes them MUST be coordinated with a Flutter update that adjusts
`TokenRefreshService._isRevocationResponse()`.
