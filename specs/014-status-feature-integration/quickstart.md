# Quickstart: Status Feature Backend & Logic Integration

This feature touches two sibling repositories. Both must be running locally
to exercise the feature end-to-end.

## 1. Backend (`chat-app-backend`)

```bash
cd "/Volumes/Zeyad/Documents/work/Node js/chat-app-backend"
npm install        # if dependencies changed (none expected for this feature)
npm run start:dev  # Nest watch mode
```

- Requires the existing `.env` (MongoDB URI, JWT secret, Redis URL) - no new
  environment variables are introduced by this feature.
- Verify the new module loads: server log should show `StatusModule`
  dependencies (`StatusController`, `StatusService`) initialize without
  errors, alongside existing `ChatModule`/`UsersModule`.
- Mongo: confirm the TTL index exists after first run:
  ```js
  db.statuses.getIndexes()
  // expect an entry: { key: { expiresAt: 1 }, expireAfterSeconds: 0 }
  ```

### Backend tests

```bash
npm run test -- status         # new StatusService/StatusController specs
npm run test -- chat.gateway    # extended ChatGateway specs (status events)
npm run test -- users.service   # extended UsersService specs (syncedContacts, mutual contacts)
```

## 2. Frontend (`ciro-chat-app`, this repo)

```bash
cd "/Volumes/Zeyad/Documents/work/Flutter/ciro-chat-app"
flutter pub get
flutter run
```

- `.env` `API_URL` should point at the backend above (e.g.,
  `http://localhost:3000` or the LAN IP for a physical device).
- No new packages are required (`cached_network_image`,
  `video_player`, `sqflite`, `socket_io_client` are already dependencies).

### Frontend tests

```bash
flutter test test/features/status
```

## 3. Manual end-to-end smoke test (maps to Independent Tests in spec.md)

1. **US1** - On Device A (User A), grant contacts permission so
   `ContactsService.syncContacts()` runs (persists `syncedContacts`
   server-side). Repeat on Device B (User B), ensuring A and B have each
   other's numbers saved (mutual contacts). Post a text status as User A
   with "Public" privacy. On Device B, open the Updates screen - the status
   should appear in "Recent status" within 5 seconds (SC-001) without
   restarting the app.
2. **US2** - With Device B's Updates screen open, post a second status from
   User A and confirm it appears live via `statusReceived` (no manual
   refresh).
3. **US3** - Confirm a status posted >24h ago (adjust `expiresAt` directly
   in Mongo for testing, or wait) no longer appears in `GET /status/feed`
   and the Mongo document is gone (TTL).
4. **US4** - On Device B, open User A's status (triggers `statusViewed`).
   On Device A (online), confirm a real-time `statusViewerAdded` event is
   received and `GET /status/:id/viewers` lists User B.
5. **US5** - On Device B, send a reaction and a text reply while viewing
   User A's status. Confirm User A receives `statusReacted` in real time,
   and (with User A online) the reply arrives in real time via the existing
   `newMessage` event as a new message in the A↔B chat conversation tagged
   with `statusRef` (FR-010) - no separate "reply" event is expected.
6. **US6** - Post a "Private" status from User A selecting only User B.
   Confirm a third mutual contact, User C, gets neither `statusReceived`
   nor sees it in `GET /status/feed`/`GET /status/media/...` (403/404).
   Start a second "Private" status as User A and confirm User B is
   pre-selected (`GET /status/audience/default`). Separately, post a
   "Show on Map" status from User A and confirm it appears in User B's
   Updates feed exactly like a "Public" status (FR-004), in addition to
   being surfaced via the map for permitted contacts.
7. **Mutual-contact edge case** - Have User C remove User A's number from
   their contacts (re-sync contacts so `syncedContacts` updates), making
   the relationship one-directional. Confirm User A's next "Public" status
   is **not** delivered to or retrievable by User C (SC-008).
8. **Offline queue** - Enable airplane mode on Device A, post a status
   (`sync_status = 'pending'` locally), confirm it renders immediately
   (optimistic). Disable airplane mode and confirm it's submitted within
   30s with no duplicate (SC-006), and `sync_status` becomes `'synced'`.
9. **Media access control** - Copy a `mediaUrl` from a Private status's
   `GET /status/feed` response and attempt to fetch
   `GET /status/media/<statusId>/<filename>` without an Authorization
   header, and as User C (not in audience) - both should fail
   (401/403/404), unlike the existing unauthenticated `/uploads/<uuid>`
   pattern (SC-003).

## 4. No UI changes expected

Per SC-007, the existing Status Updates screen, creation bottom sheet, and
viewer should require **zero** layout/visual changes. If a manual smoke test
reveals a screen needs new widgets/fields to surface data from this feature
(e.g., a viewer-count badge), flag it during `/speckit-tasks` rather than
silently adding UI - it may indicate a spec gap.
