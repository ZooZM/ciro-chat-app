# Ciro Chat — Engineering Constitution

> These rules are non-negotiable. Every spec, plan, task, and PR in this
> repository must comply. When a rule conflicts with a convenience or
> deadline, the rule wins.

---

## C-01 · Latency Budget (send → deliver)

| Path | p99 target |
|------|-----------|
| Online sender → online recipient (WS) | **< 500 ms** |
| Online sender → offline recipient (push notification appears) | **< 2 s** |

Measurements are taken from the moment the user taps Send to the moment the
recipient's device renders the message or shows the notification. Tasks that
touch the send path **must** include a latency regression test or a manual
measurement protocol.

## C-02 · At-Least-Once Delivery + Idempotency

Every message **must** survive a mid-send network drop and be delivered exactly
once to the recipient, even if the sender retries.

- **Client side**: every outbound message carries a `clientMessageId` (UUID v4)
  generated at compose time and stored in SQLite before the socket emit.
  Retry loops replay the same `clientMessageId`.
- **Server side**: `chat.service.ts:83–90` already enforces this via
  `findByClientMessageId` before MongoDB insert. This guard **must not be
  removed or bypassed**.
- Any new message-sending code path (REST fallback, push-triggered re-send,
  etc.) **must** reuse the same `clientMessageId` and go through the same
  idempotency guard.

## C-03 · Optimistic UI

The sender's bubble **must** appear in the UI (status: `pending`, single clock
icon) before any network call is made. The user must never wait on I/O to see
their own message. Tasks that modify `sendLocalMessage` or any
`send*Message` method must verify this property.

## C-04 · Flutter UI Isolate Constraint

No CPU-heavy work on the Flutter main isolate. Specifically banned on the main
isolate:

- Video thumbnail extraction (`VideoThumbnail.thumbnailFile`)
- Image decoding/compression
- Large JSON serialisation (> ~50 KB)
- SQLite writes that are not fire-and-forget (must use `compute()` or
  `Isolate.run()` for anything > a single row)

Any task that introduces background work must document the isolate it runs on.

## C-05 · Spec → Plan → Tasks → Analyze Approval Chain

No code is merged without completing the full chain in order:

```
/specify  →  /clarify  →  /plan  →  /tasks  →  /analyze  →  (approval)  →  /implement
```

- `/specify` defines WHAT. No implementation details.
- `/clarify` resolves unknowns. Must wait for answers before `/plan`.
- `/plan` defines HOW with exact file paths and line ranges from the audit.
- `/tasks` breaks the plan into atomic, independently mergeable units.
- `/analyze` cross-checks spec ↔ tasks. Orphans block merge.
- Implementation stops at milestone boundaries and waits for review.

Skipping or reordering steps is a constitution violation.

## C-06 · Commit Message BN-xx Citation

Every commit that resolves an audit finding **must** include `Resolves BN-xx`
in the commit message body, where `xx` matches the finding ID in
`docs/chat-lifecycle-audit.md`. After the milestone is merged, the audit doc
is updated with `✅` next to the closed finding and a commit message
`docs(audit): close BN-xx (resolved in M<n>)`.

Example:
```
fix(db): add SQLite indexes for messages and contacts

Resolves BN-01 — eliminates full-table scans on messages(room_id) and
contacts(phoneNumber). DB version bumped 1→2; onUpgrade runs CREATE INDEX.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

---

*Last updated: 2026-05-12 · Applies to all specs ≥ 006.*
