# Feature Specification: Persistent Session (Stay Logged In Indefinitely)

**Feature Branch**: `009-persistent-session`
**Created**: 2026-05-19
**Status**: Draft
**Input**: User description: "i need you update refreshToken logic to refresh will and i need the user stay login forever"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - User never has to sign in again after the first time (Priority: P1)

A user signs in to the app once. From that point on, the user can open the app any number of times, after any length of break, and arrive directly at their conversations without seeing a sign-in screen. The only situations that end this session are: the user explicitly signing out, the user changing their password, the user uninstalling and reinstalling the app, or the backend explicitly revoking the session for security reasons. Plain elapsed time MUST never end a session.

**Why this priority**: Today users get logged out periodically because the refresh-token rotation can fail (transient network issues, near-expiry windows, app-being-closed-during-refresh). Each forced re-login is a friction point that risks lost users. This story is the entire point of the feature.

**Independent Test**: Sign in on a fresh install. Use the app for one day. Close the app. Leave the device offline for 7+ days. Open the app — the user lands on the conversations list without a sign-in prompt.

**Acceptance Scenarios**:

1. **Given** a user signed in on 2026-05-01, **When** the user opens the app on 2026-08-01 (3 months later) with network connectivity, **Then** the user lands on the conversations list without being prompted to sign in.
2. **Given** a user signed in and the app has been closed for an arbitrary duration, **When** the user opens the app, **Then** the app obtains a fresh session silently (transparent to the user) and the user proceeds directly to their conversations.
3. **Given** a user has been continuously using the app for hours, **When** the underlying credentials rotate in the background, **Then** the user observes no interruption, no error toast, no logout, and no re-authentication prompt.
4. **Given** the user explicitly taps "Sign out", **When** the action completes, **Then** the session ends, all local credentials are removed, and the user is returned to the sign-in screen (existing behavior preserved).

---

### User Story 2 - Refresh failures do not log the user out (Priority: P1)

Today, certain refresh-token failures (network unavailable, server transient error, race conditions during app resume) cause the app to discard credentials and return the user to the sign-in screen. After this feature, only an explicit backend statement that "this session is no longer valid" can end the session. Network errors and transient server errors MUST cause the app to retry indefinitely, with backoff, never to log out.

**Why this priority**: Equal priority to story 1 because the bug that frustrates users is rarely "my token expired naturally" — it's "I had no internet for 30 seconds and now I have to log in again". This story addresses that root cause.

**Independent Test**: With the app open and signed in, disable network. Wait long enough that a refresh attempt would normally run and fail. Re-enable network. Confirm the user was never returned to the sign-in screen and the app resumes normally.

**Acceptance Scenarios**:

1. **Given** the user is signed in and the app is in the foreground, **When** the device loses network connectivity for an arbitrary duration, **Then** the user remains signed in and the app retries credential refresh in the background once connectivity is restored; the user is never returned to the sign-in screen due to this.
2. **Given** the credential refresh request returns a transient server error (5xx) or a network error, **When** the failure is observed, **Then** the app retries with exponential backoff and continues retrying as long as the user has not explicitly signed out; the user is never returned to the sign-in screen.
3. **Given** the credential refresh request returns an explicit "session revoked" or "session invalid" response from the backend, **When** that response is observed, **Then** the app ends the session, clears local credentials, and returns the user to the sign-in screen (this is the only error-based path that ends the session).

---

### User Story 3 - Active sign-out paths still work cleanly (Priority: P2)

The feature must NOT make sign-out harder. All existing ways to end a session (the in-app Sign Out button, server-side admin revocation, password change on another device, account deletion) MUST continue to work and MUST end the local session promptly when the device next contacts the backend.

**Why this priority**: Security and data hygiene depend on these paths working. They are lower priority than P1 only because they exist today and the feature must preserve them, not invent them.

**Independent Test**: Sign in on Device A. On Device B, change the account password. On Device A, perform any action that touches the backend. Within 1 minute, Device A should be returned to the sign-in screen.

**Acceptance Scenarios**:

1. **Given** the user is signed in on Device A, **When** the user taps "Sign Out", **Then** local credentials are deleted, the socket is disconnected, push notifications are unregistered, and the user is returned to the sign-in screen.
2. **Given** the user is signed in on Device A, **When** the account password is changed on Device B (or the backend revokes Device A's session for any reason), **Then** the next backend interaction on Device A results in a "session revoked" response and Device A returns the user to the sign-in screen.
3. **Given** the user uninstalls and reinstalls the app, **When** the user opens the app, **Then** no prior session is present and the user must sign in fresh (standard install behavior preserved).

---

### Edge Cases

- The device's system clock drifts significantly: the app MUST tolerate clock skew and not log the user out on the basis of local-clock expiry alone; it relies on the backend's authority over session validity.
- The app is killed mid-refresh: on next launch, the partial state must not cause a logout; the app should treat the credentials as still valid and re-attempt refresh.
- Concurrent refresh attempts (e.g., a network request and a socket reconnect both detect expiry at the same time): only one refresh must be in flight at a time; others wait for its result. A single network-blip refresh failure must not be observed multiple times and must not log the user out.
- The user has been signed in for many months and has accumulated very long-lived refresh credentials: the credentials must still be accepted by the backend; there is no fixed maximum age before forced re-authentication.
- The backend deprecates an older credential format and requires re-issuance: this is a controlled rollout; the backend handles re-issuance silently using the existing valid credentials during the rollout window.
- The user signs in on a new device: no impact on existing devices unless the backend's security policy chooses to revoke them (out of scope for this feature; existing policy preserved).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A signed-in user MUST remain signed in indefinitely, ending the session only when one of the following occurs: (a) the user explicitly signs out, (b) the backend explicitly revokes the session, (c) the user changes their password, or (d) the app data is cleared / reinstalled.
- **FR-002**: Mere elapsed time, regardless of duration, MUST NOT end a user's session.
- **FR-003**: Credential rotation MUST be performed silently in the background without any user-visible interruption (no spinners, no toasts, no screen transitions).
- **FR-004**: A credential rotation failure that is NOT an explicit backend revocation (i.e., network error, request timeout, 5xx, refresh request cancelled by app lifecycle) MUST NOT end the user's session. The app MUST retry with backoff and continue retrying until the credential rotation succeeds, the backend explicitly revokes the session, or the user signs out.
- **FR-005**: Only an explicit backend signal of "session revoked" or "session invalid" — distinct from a generic auth error — MUST cause the app to end the session and return the user to the sign-in screen.
- **FR-006**: When the backend explicitly revokes the session, the app MUST end the session within 60 seconds of the next backend interaction (HTTP request OR socket event) on the affected device.
- **FR-007**: At app cold-start, if locally stored credentials exist, the app MUST attempt to use them and refresh them as needed, navigating the user directly to their conversations without showing a sign-in screen as an interstitial. The sign-in screen MUST only appear if the credentials are explicitly rejected by the backend as revoked/invalid.
- **FR-008**: Concurrent credential-refresh attempts MUST be coalesced; at most one refresh request is in flight per device at any time. Other consumers of the refreshed credential wait for the in-flight refresh's result.
- **FR-009**: All existing sign-out paths (in-app sign-out button, server-side revocation, password change broadcast) MUST continue to work and MUST trigger the full local teardown sequence (clear credentials, disconnect socket, unregister push, clear local app data per existing logout flow).
- **FR-010**: The credential refresh logic MUST be resilient to app-process termination: a refresh that was in progress when the app was killed MUST be re-attempted on the next launch without ending the session.
- **FR-011**: Users MUST experience no measurable degradation in app responsiveness or socket latency as a result of background credential rotation.
- **FR-012**: The feature MUST NOT weaken any existing security guarantees: passwords are still hashed server-side, credentials are still stored in the device's secure storage area, and revocation propagates as quickly as today.

### Key Entities *(include if feature involves data)*

- **User Session**: The user's authenticated state on a single device. Defined by the credentials stored locally and recognized by the backend. Ends only via FR-001 conditions.
- **Credential Set**: A pair (or set) of tokens stored locally; one used to make backend requests, one used to obtain a new request token without re-authenticating. The exact technology is an implementation choice for the planning phase.
- **Revocation Signal**: An explicit backend response indicating that a particular session is no longer valid (the only error type that ends a session per FR-005).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user who has signed in once experiences zero involuntary sign-outs over a 90-day measurement window, except for the explicit conditions listed in FR-001.
- **SC-002**: Across all opens of the app by signed-in users during a 30-day window, fewer than 0.1% of opens result in the user being shown a sign-in screen for reasons other than the explicit conditions listed in FR-001.
- **SC-003**: When a user signs out via the in-app button, the local session ends within 2 seconds of confirmation and the user lands on the sign-in screen.
- **SC-004**: When the backend revokes a user's session for security reasons, the device returns the user to the sign-in screen on the next backend interaction within 60 seconds (SC-004 covers the propagation latency required by FR-006).
- **SC-005**: 100% of network-error-only failures during credential refresh observed in production telemetry result in a successful retry (not a logout) within the same network session, once connectivity is restored.
- **SC-006**: Cold start to "conversations list visible" elapsed time for a signed-in user is no greater than the current measured value, regardless of whether a silent credential refresh runs during start-up.

## Assumptions

- The backend supports issuing long-lived refresh credentials and rotating them silently. If the backend currently caps refresh-credential lifetime, that cap will be removed or extended as part of the implementation phase.
- The backend has, or will gain, a clear distinction in its error responses between "this session is revoked / invalid" (terminal) and "this request failed transiently" (retryable). This distinction is the foundation of FR-005.
- The existing local credential storage continues to be used; this feature does not introduce new storage of sensitive data.
- "Forever" in this spec means "until one of the explicit termination conditions is met" — it does NOT mean "even against backend-initiated termination". Backend revocation always wins.
- The existing logout teardown sequence (clear credentials → disconnect socket → unregister push → clear local data) is preserved unchanged; only the conditions that trigger it are tightened.
- Existing security review processes for session management apply; this feature does not bypass any of them.
- The application supports a single account per device session today; multi-account support is out of scope for this feature.
- Compliance and regulatory requirements may require periodic re-authentication for certain user classes (e.g., enterprise accounts). If such a requirement exists or is added later, it overrides "forever" for those users. This spec defines the default behavior for ordinary users.
