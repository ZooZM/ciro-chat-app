# Feature Specification: Reels / Short Videos Feed

**Feature Branch**: `021-reels-video-feed`
**Created**: 2026-07-02
**Status**: Draft (updated 2026-07-02 with interaction overlay, creator profiles, follow system; updated again 2026-07-02 with custom share sheet and deep linking; updated again 2026-07-02 with own-profile access from the Reels screen; updated again 2026-07-02 with core backend architecture — user accounts, blocking, reel descriptions, views, saves, liked-videos history, notification triggers; updated 2026-07-03 with the reel upload flow and automated explicit/NSFW content moderation for App Store UGC compliance)
**Input**: User description: "Integrate a new Reels/Short Videos feature into the existing CiroChat project. Replace the Call tab in the bottom navigation with a Reels tab that opens a full-screen, vertical swipeable (TikTok-style) video feed with infinite scrolling, intelligent preloading of adjacent videos, auto-play of the visible video, strict disposal of off-screen videos to protect device memory, and integration with the existing Node.js backend to fetch video lists. Swiping must feel completely smooth with zero lag. Update: add a video interaction overlay (Love/Comment/Share floating actions with real-time counters, comment bottom sheet, native share sheet), a Creator Profile screen (user info, stats, 3-column video grid that opens a feed starting from the tapped video), and a foundational follow system (Follow/Following toggle on overlay and profile), with backend endpoints for likes, comments, profiles, and follow/unfollow backed by relational mock data. Second update: replace the native platform share sheet with a custom in-app share bottom sheet (top row: horizontal recent chats from CiroChat messaging that send the video's deep link on tap; bottom row: prominent Copy Link plus standard external share targets), and implement a full deep linking system — a unique standard URL per video (https://ciro.chat/reels/:id) that opens the app from outside, routes straight to the Reels screen with a loading skeleton if needed, and starts the infinite feed at that exact video. Third update: a current-user profile icon at the top-left of the Reels screen routing to the user's own profile page. Fourth update: core backend architecture for users, reels, and engagement — user account profile data (username, full name, profile picture, bio) with optimized counter fields (followersCount, followingCount, totalLikes), a user blocking system that mutually hides reels between blocker and blocked, a reel text description supporting hashtags and user mentions, a views metric alongside likes/comments/shares, indexed follow relations able to answer 'reels from users I follow', a likes history exposing the user's Liked Videos list, private saves/bookmarks with a Saved Videos list, and schema-level notification triggers (new follower, new like on a reel, mention in a description) ready for push delivery; the architecture must be read-optimized for fast feed generation, an ERD/schema design must be approved before implementation, and live streaming, wallets, and coin/diamond systems are explicitly out of scope for this phase. Fifth update: reel upload flow plus automated explicit/NSFW content moderation for App Store UGC compliance — a reel moderation status state machine (pending review → published or rejected) where new uploads default to pending review and stay invisible to all public surfaces, a background automated analysis of each uploaded video by a third-party AI video moderation service, auto-publish on a clean verdict (triggering the existing mention-notification logic at publish time), rejection with soft-deletion/hiding and a recorded community-guidelines violation notice for the uploader when flagged, and uploader-facing 'Processing' / 'Removed due to policy violations' states in the app."

## Clarifications

### Session 2026-07-02

- Q: When the Reels tab is active, should the bottom navigation bar remain visible over the full-screen video? → A: Keep nav bar visible — video fills the screen behind a dark-themed bottom nav bar (TikTok-style); one tap returns to any other tab.
- Q: How should the Share counter behave in v1? → A: Tapping Share opens an in-app share sheet with recent chats and a Copy Link button; the counter increments (via a backend share endpoint) only when the user sends the reel to a recent chat in-app or taps Copy Link.
- Q: What happens to the Calls tab once Reels is added? → A: Keep the Call icon/tab as-is and add the Reels icon as a new tab directly after it (bottom bar grows to 6 items). The original "remove the Call tab" instruction is superseded; call history stays reachable from its tab.
- Q: When the user reaches the end of the available mock videos, what should the feed do? → A: Loop content — the backend keeps serving pages by cycling through the catalog, so the main feed never dead-ends in v1.
- Q: Where should the seeded mock videos be hosted in v1? → A: Public sample URLs (e.g., well-known public test MP4 buckets); no backend-hosted video assets required, internet connectivity assumed for playback.
- Q: How should the external share icons in the share sheet's bottom row work? → A: Only the OS share sheet — the bottom row is a prominent Copy Link button plus a single "Share via…" action that opens the native platform share sheet; no per-app branded icons.
- Q: How should a shared reel link appear in the recipient's chat? → A: Rich preview card — a dedicated chat bubble showing the reel's thumbnail, creator name, and a play badge; tapping it opens the reel in-app. Introduces a reel-share message subtype (supersedes the earlier "no new message type" assumption).
- Q: What happens when a reel link is opened without the app installed (or on desktop)? → A: Store fallback — the link serves a very basic auto-redirect page from the backend that sends iOS users to the App Store and Android users to Google Play; no full web landing page in v1.
- Q: When the user returns to the Reels tab within the same app session, where should the feed be? → A: Resume position — the feed stays on the same video (paused while away, resumes on return); a fresh feed only on app restart or explicit refresh.
- Q: Should the core backend architecture (accounts, reels, engagement, blocks, saves, notification events) run on mock data or a real database in this phase? → A: Implement a real database now — the schema, indexes, and stored counter fields live in the DB, seeded with demo/mock content. This supersedes the earlier "mock data MAY be used" allowance (FR-033).
- Q: How does the Reels "User Account" relate to the existing CiroChat user? → A: One shared identity — the existing CiroChat user model is extended with the Reels profile fields (unique username, bio) and counter fields; chat and Reels share the same user record, avatar, and blocking relationships.
- Q: Where does the Reels screen's top-left own-profile icon navigate — the existing Profile tab or a reels-style profile? → A: The reels-style own profile (the US4 creator-profile surface rendered for self: avatar, username, stats, video grid, Liked/Saved lists), a separate screen from the bottom bar's Profile tab, which is unchanged.
- Q: Should push notifications be delivered end-to-end in this phase, or only recorded as events? → A: Full delivery now — push notifications are actually sent to recipients' devices for new follower, new like on a reel, and mentions, in addition to the recorded events (supersedes the "delivery pipeline may land separately" caveat).
- Q: Are hashtags and mentions in reel descriptions tappable in v1? → A: Both tappable — a mention opens that user's profile, a hashtag opens a hashtag feed. Additionally, a Search screen is added: searching a string returns reels whose description hashtags contain the searched string (Videos group) and users whose names contain it (Users group).

### Session 2026-07-03

- Q: Reel uploading was previously listed as out of scope — is it now part of this feature? → A: Yes — an upload flow is added (users publish their own reels with a description), superseding the earlier out-of-scope assumption. Every upload must pass automated content moderation before it becomes publicly visible (App Store UGC compliance).
- Q: How is explicit/NSFW user-generated content handled? → A: Fully automated AI moderation — each reel carries a moderation status (pending review, published, rejected). New uploads default to pending review and are hidden from every public surface; a background step sends the uploaded video to a third-party AI video moderation service; a clean verdict auto-publishes the reel (firing the existing mention-notification logic at publish time), while a flagged verdict rejects it (video soft-deleted/hidden, uploader notified of the community-guidelines violation). No human review or appeals process in v1.
- Q: What are the length constraints for an uploaded reel video? → A: Max 60 seconds per reel. Longer source videos are never hard-rejected — the app presents an in-app trim/segment selector (WhatsApp Status-style) so the user picks which ≤60-second portion to upload.
- Q: Does automated moderation cover only the video, or the description text too? → A: Both — the video and the reel's description text are screened in the same background moderation step; a flag on either one rejects the reel. Comment text moderation remains out of scope for v1.
- Q: Can users delete their own uploaded reels? → A: Yes — owners can delete any of their own reels in any status (published, processing, or rejected) from their profile; a deleted reel vanishes from every surface and its links follow the existing unknown-reel error path.
- Q: Do moderation outcomes reach the uploader as push notifications? → A: Push on rejection only — the community-guidelines violation notice is delivered as a push notification through the existing pipeline; a clean publish is silent (the status simply updates on the owner's profile).
- Q: Are there account-level consequences for repeat violators? → A: No — in v1 each rejection stands alone; strike/suspension systems are deferred until human review and an appeals flow exist.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Discover and Watch Reels from the Main Screen (Priority: P1)

A CiroChat user opens the app and sees a Reels entry (video play icon) in the bottom navigation bar, right after the Calls tab. Tapping it takes them to a full-screen vertical video feed. The first video starts playing automatically, and the user swipes up to move to the next video and down to return to the previous one.

**Why this priority**: This is the core of the feature — without the entry point and the basic watch experience, nothing else in this feature delivers value. It is independently shippable as a minimal viable Reels experience.

**Independent Test**: Can be fully tested by launching the app, tapping the new Reels icon in the bottom bar, and confirming that a full-screen video feed opens, the visible video auto-plays, and vertical swipes move between videos.

**Acceptance Scenarios**:

1. **Given** the app's main screen is displayed, **When** the user looks at the bottom navigation bar, **Then** a Reels (video play) item is shown directly after the existing Calls item, and all pre-existing tabs (including Calls) remain present.
2. **Given** the main screen is displayed, **When** the user taps the Reels item, **Then** a full-screen vertical video feed opens and the first video begins playing automatically without any user action.
3. **Given** a video is playing in the feed, **When** the user swipes up, **Then** the next video fills the screen and begins playing automatically, and the previous video's audio stops immediately.
4. **Given** the user has swiped forward at least once, **When** the user swipes down, **Then** the previous video is shown again and begins playing automatically.
5. **Given** the user is viewing the Reels feed, **When** they navigate to another tab (e.g., Chats), **Then** all video playback and audio stop immediately.

---

### User Story 2 - Smooth, Uninterrupted Infinite Browsing (Priority: P2)

A user browses the Reels feed continuously. New videos keep appearing as they swipe (infinite feed), each video starts playing essentially instantly after a swipe because upcoming videos are prepared in the background, and scrolling always feels perfectly fluid with no stutter, freezes, or memory-related slowdowns — even after watching many videos in one session.

**Why this priority**: Perceived smoothness is the defining quality bar for a short-video feed; a stuttering or slow feed will not be used. It builds directly on User Story 1.

**Independent Test**: Can be tested by swiping through 50+ videos in a single session while observing that each video starts within a fraction of a second of the swipe settling, scrolling never visibly stutters, and the app remains responsive and stable throughout.

**Acceptance Scenarios**:

1. **Given** a video at position N is playing, **When** the user swipes to position N+1, **Then** the next video begins playing without a visible loading wait in the common case (previously prepared in the background).
2. **Given** the user approaches the end of the currently loaded list, **When** they continue swiping, **Then** the next batch of videos is fetched from the backend in the background and browsing continues without interruption or a dead end.
3. **Given** the user has browsed a long session (e.g., 100+ videos), **When** they continue swiping, **Then** scrolling remains as fluid as at the start of the session and the app does not slow down, drop frames noticeably, or crash due to memory pressure.
4. **Given** a video is more than 2 positions away from the visible one, **When** the user keeps browsing, **Then** that video's playback resources are fully released without any visible hitch on the currently visible video.
5. **Given** the device is on a slow network, **When** a video cannot start instantly, **Then** a lightweight buffering indicator is shown on that video only, and the rest of the screen remains responsive.

---

### User Story 3 - React, Comment, and Share via the Interaction Overlay (Priority: P3)

While watching a reel, the user sees floating action buttons overlaid on the video — Love, Comment, and Share — each with a live counter (e.g., "1.2K"). Tapping Love toggles the reaction with a small delightful animation and updates the counter instantly. Tapping Comment opens a lightweight bottom sheet with a scrollable list of comments and an input field to add one. Tapping Share opens the device's native share sheet. The user can also tap the video itself to pause/resume playback.

**Why this priority**: Engagement actions complete the expected short-video experience and generate the interaction data that makes the feed social, but the core browsing loop (US1/US2) delivers value without them.

**Independent Test**: Can be tested by opening any video in the feed and exercising each overlay control: toggling Love (animation + counter), opening the comment sheet and posting a comment, invoking the share sheet, and tapping to pause/resume — all while the video continues playing smoothly underneath.

**Acceptance Scenarios**:

1. **Given** a video is playing, **When** the user looks at the screen, **Then** floating Love, Comment, and Share actions are overlaid on the video, each showing its current count in compact form (e.g., 1.2K).
2. **Given** the Love action is inactive, **When** the user taps it, **Then** it switches to the active state with a micro-animation, the counter increments immediately, and the reaction is recorded on the backend; tapping again reverses all of this.
3. **Given** a video is playing, **When** the user taps the Comment action, **Then** a lightweight bottom sheet slides up showing a scrollable list of comments and an input field, while the video remains visible behind it.
4. **Given** the comment sheet is open, **When** the user submits a non-empty comment, **Then** the comment appears in the list immediately and the comment counter on the overlay updates.
5. **Given** a video is playing, **When** the user taps the Share action, **Then** a custom in-app share sheet opens instantly over the still-playing video with two rows: a horizontally scrollable top row of the user's recent chats (circular avatar + name, from CiroChat's existing conversations) and a bottom row with a prominent Copy Link button followed by a single "Share via…" action for the native platform share sheet.
6. **Given** the share sheet is open, **When** the user taps a recent chat, **Then** a reel-share message is sent to that chat immediately (no extra confirmation), the sheet confirms and closes, and the share counter increments; the recipient sees a rich preview card (thumbnail, creator name, play badge) that opens the reel in-app when tapped.
7. **Given** the share sheet is open, **When** the user taps Copy Link, **Then** the video's link is copied to the clipboard with a confirmation notice and the share counter increments; choosing "Share via…" opens the native platform share sheet without affecting the counter.
8. **Given** a video is playing, **When** the user taps once on the video (outside overlay controls), **Then** playback pauses with a clear paused indicator, and a second tap resumes from the same position.
9. **Given** any overlay interaction (love toggle, counter update, comment count change, share sheet opening), **When** the state changes, **Then** only the affected overlay element updates — video playback continues with no visible glitch, stutter, or full-page refresh.

---

### User Story 4 - Explore a Creator's Profile and Their Videos (Priority: P4)

While watching a reel, the user taps the creator's username or profile picture on the video overlay and lands on a dedicated Creator Profile screen. There they see the creator's avatar, name, and bio; their stats (followers, following, total likes); and a 3-column grid of thumbnails for every video that creator has published. Tapping any thumbnail opens the vertical video feed starting from that exact video.

**Why this priority**: Profiles deepen engagement and give the follow system somewhere to live, but they depend on the feed and overlay existing first.

**Independent Test**: Can be tested by tapping a creator's name/avatar on any reel, verifying the profile screen renders info, stats, and the video grid, then tapping a grid item and confirming a vertical feed opens starting at that video.

**Acceptance Scenarios**:

1. **Given** a reel is playing with the creator's username and avatar overlaid, **When** the user taps either of them, **Then** the app navigates to that creator's profile screen.
2. **Given** the profile screen is open, **When** it loads, **Then** it displays the creator's avatar, name, and bio, plus followers count, following count, and total likes.
3. **Given** the profile screen is open, **When** the user scrolls, **Then** all of that creator's published videos appear as thumbnails in a 3-column grid.
4. **Given** the video grid is displayed, **When** the user taps any thumbnail, **Then** a full-screen vertical feed opens starting at that video, and the user can swipe through the rest of that creator's videos.
5. **Given** the creator has published no videos, **When** the profile opens, **Then** a friendly empty state is shown in place of the grid.

---

### User Story 5 - Follow a Creator (Priority: P5)

The user discovers a creator they enjoy and taps the prominent Follow button — available both on the video overlay and on the Creator Profile screen. The button flips to "Following" instantly. Tapping again unfollows. The creator's follower count reflects the change.

**Why this priority**: The follow system is foundational for future feed personalization but delivers the least standalone value today; it requires profiles (US4) to be meaningful.

**Independent Test**: Can be tested by tapping Follow on a reel's overlay, confirming the state flips to "Following" instantly, opening the creator's profile to see the same state and an updated follower count, then unfollowing from the profile.

**Acceptance Scenarios**:

1. **Given** a reel from a creator the user does not follow, **When** the user looks at the overlay or opens the creator's profile, **Then** a prominent "Follow" button is visible in both places.
2. **Given** the button reads "Follow", **When** the user taps it, **Then** it switches to "Following" instantly (no waiting on the network) and the follow is recorded on the backend.
3. **Given** the button reads "Following", **When** the user taps it, **Then** it switches back to "Follow" instantly and the unfollow is recorded on the backend.
4. **Given** the user follows/unfollows from the overlay, **When** they open that creator's profile, **Then** the button state and follower count there are consistent with the action taken.
5. **Given** the backend rejects or fails a follow/unfollow, **When** the failure is detected, **Then** the button reverts to its previous state and a non-intrusive notice is shown.

---

### User Story 6 - Open a Shared Reel from Anywhere (Deep Linking) (Priority: P6)

A user receives a reel link — inside a CiroChat conversation, in another messaging app, or anywhere else. Tapping `https://ciro.chat/reels/<id>` opens the CiroChat app directly on the Reels screen. If the video data needs a moment to load, a loading skeleton is shown; then that exact video plays full-screen, and swiping up continues seamlessly into the regular infinite feed.

**Why this priority**: Deep links make shared reels actually clickable end-to-end and close the loop on User Story 3's share flow; but the share sheet still delivers value without them (links can be pasted/read), so this lands after the interaction features.

**Independent Test**: Can be tested by triggering a reel URL from outside the app (and from a chat message inside the app) and confirming the app opens on the Reels screen, shows a skeleton while fetching, plays the exact linked video, and lets the user swipe onward into the feed.

**Acceptance Scenarios**:

1. **Given** the app is installed and the user is logged in, **When** they tap a `https://ciro.chat/reels/<id>` link outside the app, **Then** the OS opens CiroChat directly on the Reels screen and that exact video plays.
2. **Given** the linked video's data is still being fetched, **When** the Reels screen opens via a link, **Then** a loading skeleton is displayed until the video is ready — never a blank screen or frozen frame.
3. **Given** the linked video is playing, **When** the user swipes up, **Then** the infinite feed continues from that video as the starting index.
4. **Given** a reel-share card (or a pasted reel URL) is received inside a CiroChat conversation, **When** the user taps it, **Then** the app navigates internally to the Reels screen for that video (no browser round-trip).
5. **Given** the user is logged out, **When** they open a reel link, **Then** they complete the normal login flow first and are then taken to the linked reel.
6. **Given** the link references an unknown or deleted reel, **When** the app opens it, **Then** a friendly error is shown and the user lands on the regular Reels feed instead.

---

### User Story 7 - Jump to My Own Profile from the Reels Screen (Priority: P7)

While browsing the Reels feed, the user sees their own profile icon (their current avatar) pinned at the top-left corner of the Reels screen. Tapping it takes them directly to their own User Profile Page, where their profile picture — the same avatar stored on their existing user account — is fetched and displayed alongside the rest of their profile information.

**Why this priority**: A convenient shortcut that improves navigation and self-service, but it layers on top of the existing profile screen (US4) and delivers less standalone value than the watching, engagement, and sharing loops.

**Independent Test**: Can be tested by opening the Reels feed, confirming the current user's avatar icon is visible at the top-left corner over the playing video, tapping it, and verifying the app lands on the user's own profile page with their account profile picture displayed.

**Acceptance Scenarios**:

1. **Given** the Reels feed is open with a video playing, **When** the user looks at the top-left corner of the screen, **Then** a profile icon showing the current user's avatar is visible, overlaid on the video, without obstructing the creator info or interaction overlay.
2. **Given** the Reels feed is open, **When** the user taps the top-left profile icon, **Then** the app navigates directly to that user's own User Profile Page (a single tap, no intermediate menu), and video playback in the feed stops per the existing leave-feed rules.
3. **Given** the user's own profile page opens, **When** it loads, **Then** the user's profile picture is fetched from their existing user account data and displayed as the page's avatar, together with their name and profile details.
4. **Given** the user has no profile picture set on their account, **When** their profile page opens, **Then** a standard placeholder avatar is shown instead of a broken or empty image.
5. **Given** the user is viewing their own profile page (reached via this icon), **When** they look for a Follow button, **Then** none is available (a user cannot follow themselves), consistent with the existing own-profile rule.
6. **Given** the user navigates back from their profile page, **When** they return to the Reels feed within the same session, **Then** the feed resumes at the same video per the existing resume-position rule.

---

### User Story 8 - Save Reels and Revisit Liked & Saved Videos (Priority: P8)

While watching a reel, the user taps a Save (bookmark) action on the overlay to keep it for later. From their own profile page they can open two private lists — "Liked Videos" (every reel they have loved) and "Saved Videos" (every reel they have bookmarked) — and tap any item to watch it again in the full-screen feed. These lists are visible only to the user themselves.

**Why this priority**: Personal engagement history rounds out the interaction system and gives saves/likes lasting value, but it depends on the overlay (US3) and own-profile page (US7) already existing.

**Independent Test**: Can be tested by saving a reel from the overlay, loving another, opening the own profile page, verifying both reels appear in the Saved Videos and Liked Videos lists respectively, tapping one to play it, then unsaving/unloving and confirming the lists update.

**Acceptance Scenarios**:

1. **Given** a video is playing, **When** the user looks at the interaction overlay, **Then** a Save (bookmark) action is available alongside Love, Comment, and Share.
2. **Given** a reel is not saved, **When** the user taps Save, **Then** the action flips to the saved state instantly (optimistic) and the save is recorded on the backend; tapping again unsaves; a failed request reverts the state with a non-intrusive notice.
3. **Given** the user has loved and saved some reels, **When** they open their own profile page, **Then** they can access a "Liked Videos" list and a "Saved Videos" list containing those reels.
4. **Given** a Liked or Saved list is open, **When** the user taps any item, **Then** a full-screen vertical feed opens starting at that video, scoped to that list.
5. **Given** another user views a profile, **When** they look for that profile's Liked or Saved videos, **Then** neither list is visible — both are private to the owner.
6. **Given** the user has never loved or saved anything, **When** they open either list, **Then** a friendly empty state is shown.

---

### User Story 9 - Search Reels by Hashtag and Find Users (Priority: P9)

From the Reels screen, the user opens a Search screen and types a query. Results come back in two groups: **Videos** — reels that have at least one hashtag containing the searched string — and **Users** — accounts whose name contains the searched string. Tapping a video result plays it in the full-screen feed; tapping a user opens their profile. Tapping a hashtag anywhere (in a description) similarly opens a feed of all reels carrying that hashtag.

**Why this priority**: Search and hashtag discovery open up content exploration beyond the algorithmic feed, but they depend on descriptions/hashtags (FR-047) and profiles (US4) existing first.

**Independent Test**: Can be tested by opening Search from the Reels screen, typing a string known to appear in seeded hashtags and in a seeded user's name, verifying both result groups populate correctly, tapping a video result to play it, tapping a user result to reach their profile, and tapping a hashtag in any reel description to open that hashtag's feed.

**Acceptance Scenarios**:

1. **Given** the Reels screen is open, **When** the user taps the search entry point, **Then** a Search screen opens with a text input focused and ready.
2. **Given** the user submits a query, **When** results return, **Then** a **Videos** group lists reels having at least one hashtag that contains the query string (case-insensitive), shown as thumbnails, and a **Users** group lists accounts whose username or full name contains the query string, shown with avatar and name.
3. **Given** video results are shown, **When** the user taps a thumbnail, **Then** a full-screen vertical feed opens at that reel, scoped to the result set.
4. **Given** user results are shown, **When** the user taps one, **Then** that user's profile screen opens.
5. **Given** a reel description contains a hashtag, **When** the user taps it, **Then** a hashtag feed opens showing all reels carrying that hashtag, newest first.
6. **Given** a query matches nothing, **When** results return, **Then** a friendly empty state is shown (per group or overall); blocked users and their reels never appear in either group.

---

### User Story 10 - Upload a Reel with Automatic Content Review (Priority: P10)

A user taps the upload entry point on the Reels screen, picks or records a video, writes a description (with hashtags and mentions), and submits it. The upload completes quickly and the new reel appears on the user's own profile marked as **"Processing"** — it is not yet visible to anyone else. Behind the scenes the video is automatically reviewed for explicit/NSFW content. If it is clean, the reel goes live: it appears in public feeds, on the creator's profile, in search and hashtag feeds, and any users mentioned in the description are notified. If it is flagged, the reel is rejected: the uploader sees it marked **"Removed due to policy violations"**, receives a violation notice, and the reel never appears publicly.

**Why this priority**: Uploading turns viewers into creators and completes the UGC loop, but every prior story delivers value on the seeded catalog without it. Automated moderation is inseparable from upload — App Store UGC compliance forbids shipping the one without the other — so they land together as a single story.

**Independent Test**: Can be tested by uploading a benign video and confirming it shows as "Processing" (invisible to a second account) and then transitions to published (visible everywhere, mention notification delivered), then uploading a video known to trigger the moderation flag and confirming it transitions to "Removed due to policy violations", stays invisible to the second account, and produces a violation notice instead of mention notifications.

**Acceptance Scenarios**:

1. **Given** the Reels screen is open, **When** the user activates the upload entry point, selects or records a video (≤60 seconds), adds a description, and submits, **Then** the upload completes with clear progress feedback and the new reel appears on their own profile with a visible "Processing" indicator.
1a. **Given** the user picks a source video longer than 60 seconds, **When** the video is selected, **Then** an in-app trim/segment selector (WhatsApp Status-style) opens so the user chooses which ≤60-second portion to upload — the video is not rejected, and only the chosen segment is uploaded.
2. **Given** a reel is in the pending-review state, **When** any other user browses the main feed, the creator's profile grid, search results, hashtag feeds, or opens the reel's deep link, **Then** the reel is nowhere visible and the deep link follows the unknown-reel error path — pending reels are indistinguishable from nonexistent ones for everyone but the owner.
3. **Given** a pending reel's automated review returns a clean verdict, **When** the review completes, **Then** the reel's status becomes published, it becomes eligible for all public surfaces, and mention notifications for resolvable @mentions in its description are sent at that moment — exactly once, never before publication.
4. **Given** a pending reel's automated review flags explicit/NSFW content, **When** the review completes, **Then** the reel's status becomes rejected, its video is hidden (soft-deleted), the owner sees it marked "Removed due to policy violations" on their profile, and a violation notice is recorded for the owner stating the reel violated community guidelines.
5. **Given** a reel was rejected, **When** the owner or anyone else looks for it in public surfaces or via its link, **Then** it appears nowhere publicly (unknown-reel path for non-owners) and no mention notifications are ever sent for it.
6. **Given** the automated moderation service is unreachable or errors, **When** a reel is awaiting review, **Then** the reel remains in "Processing" — it is never published without a clean verdict — and the review is retried automatically.

---

### Edge Cases

- **Empty feed**: The backend returns no videos — the feed shows a friendly empty state with a retry option instead of a blank screen.
- **Feed fetch failure**: The backend is unreachable when opening the feed — an error state with retry is shown; retry re-attempts the fetch.
- **Mid-scroll fetch failure**: Pagination fails while browsing — already-loaded videos remain watchable and a non-blocking retry affordance appears near the end of the list.
- **Broken video**: A specific video fails to load/play — the feed shows an error placeholder for that item only and the user can swipe past it; adjacent videos are unaffected.
- **Very fast swiping**: The user flings through many videos rapidly — no video audio overlaps, no stale video plays on the wrong page, and the feed does not stutter or crash.
- **App backgrounded / interrupted**: The app goes to background or a call/notification interrupts — playback and audio pause immediately and resume state is sane when returning.
- **Crowded bottom bar**: With 6 fixed tabs, labels and icons must remain legible and tappable on small screens; no tab is hidden behind an overflow.
- **Low memory devices**: On memory-constrained devices, the strict cap on simultaneously prepared videos prevents the OS from killing the app during long sessions.
- **Network transitions**: Switching between Wi-Fi and cellular mid-playback continues or recovers playback without crashing.
- **Rapid reaction/follow toggling**: The user taps Love, Save, or Follow many times quickly — the final visible state matches the final recorded state (no double counts, no flicker storms).
- **Engagement action fails**: A love, comment, save, or follow request fails — the optimistic UI change reverts and a non-intrusive notice appears; the video keeps playing.
- **Mention of an unknown user**: A reel description mentions a username that doesn't resolve to an existing account — it renders as plain text and triggers no notification.
- **Block takes effect mid-session**: A block is created while the other party is browsing — already-loaded items may finish naturally, but every subsequent feed page, profile grid, or refresh excludes the blocked party's reels; a deep link to a blocked party's reel follows the unknown-reel error path.
- **Empty Liked/Saved lists**: A user with no loved or saved reels sees a friendly empty state, never a blank screen.
- **Self-engagement**: A user loving their own reel or mentioning themselves generates no notification event or push.
- **Notifications disabled/unreachable device**: The event is still recorded; delivery fails silently and nothing is surfaced to the actor.
- **Search with no matches**: Both result groups show a friendly empty state; a whitespace-only query triggers no search.
- **Hashtag with a single reel**: Tapping it still opens a valid feed containing just that reel.
- **Search while blocked**: Neither a blocked user's name nor their reels ever appear in the other party's search results or hashtag feeds.
- **Empty or whitespace comment**: Submission is prevented; the input stays focused.
- **Share sheet dismissed**: The user opens and dismisses the share sheet without sending or copying — playback state is unchanged, no error is shown, and the share counter does not change.
- **Profile fetch failure**: The Creator Profile screen fails to load — an error state with retry is shown instead of a partial screen.
- **Own profile**: The user taps through to their own profile — the Follow button is hidden or disabled (a user cannot follow themselves).
- **Own avatar fails to load**: The top-left profile icon on the Reels screen, or the avatar on the user's own profile page, fails to fetch — a standard placeholder avatar is shown; the icon remains tappable and the profile page still renders its other content.
- **Own-profile icon vs. overlay**: The top-left profile icon must not overlap or steal taps from the creator info, interaction overlay, or system status bar on any supported screen size.
- **Long bios / large counts**: Bio text truncates gracefully; counters use compact notation (1.2K, 3.4M) everywhere.
- **No recent chats**: A user with no conversations sees the share sheet without the recent-chats row (or an inviting empty hint); Copy Link and external targets still work.
- **Deep link on cold start**: The app is not running when the link is tapped — startup proceeds directly to the linked reel (after auth), skeleton shown while fetching.
- **Deep link while a reel is already playing**: The current video stops immediately and the linked reel takes over as the new feed start.
- **Malformed reel URL**: Unparseable links fall back to opening the app on its default screen without crashing.
- **App not installed**: The link opens in the browser and auto-redirects to the correct app store; store URLs must be configured (see Assumptions).
- **Link fetch failure**: The linked reel fetch fails (offline/server error) — an error state with retry is shown on the Reels screen.
- **Upload interrupted**: The app is killed or loses connectivity mid-upload — no phantom reel is created; the user can retry the upload cleanly.
- **Moderation service outage**: The third-party moderation service is down or times out — affected reels stay in "Processing" indefinitely rather than ever publishing unreviewed; the analysis is retried automatically and the uploader's status updates whenever the verdict lands.
- **App closed during review**: The user uploads and immediately closes the app — the review proceeds server-side; on next visit their profile shows the reel's final state (published or removed), and a rejection notice is not lost.
- **Deep link to a pending or rejected reel**: Anyone other than the owner follows the unknown-reel error path (FR-043) — a shared link to a reel that is later rejected goes dark the same way a deleted reel does.
- **Mentions in a rejected reel**: Users mentioned in a rejected reel's description receive no notification of any kind; mention notifications exist only for published reels.
- **Block created during review**: If a block is created (in either direction) between the uploader and a mentioned user while the reel is pending review, publication sends no mention notification to that user — the block relationship is re-checked at publish time.
- **Pending/rejected reels and counters**: Reels that are not published contribute nothing to public-facing counts (the creator's video grid count seen by others, total likes, hashtag feeds, search results).
- **Reel deleted while others are watching**: Copies already on-screen may finish playing, but every subsequent feed page, profile grid, search result, or refresh excludes the deleted reel, and its deep link follows the unknown-reel path — mirroring the mid-session block behavior.
- **Deleting a reel with engagement**: Deleting a reel with likes/comments/saves removes it from other users' Liked/Saved lists and adjusts the creator's public counts; no notification is sent to anyone.

## Requirements *(mandatory)*

### Functional Requirements

#### Navigation & Entry Point

- **FR-001**: The bottom navigation bar MUST retain all existing tabs, including the Call tab and its call-history screen, unchanged.
- **FR-002**: The bottom navigation bar MUST display a new Reels item with a video play icon positioned directly after the Call tab (6 items total: Chats, Updates, Map, Calls, Reels, Profile).
- **FR-003**: Tapping the Reels item MUST open a full-screen vertical video feed; the bottom navigation bar remains visible (dark-themed to blend with the video) so other tabs stay one tap away.
- **FR-004**: Leaving the Reels feed (switching tabs, navigating back, or backgrounding the app) MUST immediately stop all video playback and audio.
- **FR-004a**: Returning to the Reels tab within the same app session MUST resume at the same video position (playback restarts automatically); a fresh feed is loaded only on app restart or an explicit refresh action.

#### Feed Behavior

- **FR-005**: The feed MUST present one video at a time, full-screen, with vertical swipe gestures moving to the next (swipe up) and previous (swipe down) video.
- **FR-006**: The feed MUST fetch its video list from the existing CiroChat backend.
- **FR-007**: The feed MUST support infinite scrolling: as the user nears the end of the loaded list, the next page of videos MUST be fetched in the background without interrupting browsing. When the catalog is exhausted, the backend cycles through it again so the main feed never reaches a dead end (v1 behavior; the creator-scoped feed remains finite).
- **FR-008**: The visible video MUST start playing automatically, with sound, without user interaction.
- **FR-009**: Exactly one video MUST be audible/playing at any time; off-screen videos MUST be paused.

#### Performance & Resource Management

- **FR-010**: While the video at position N is playing, the system MUST proactively prepare (pre-buffer the first seconds of) the videos at positions N+1 and N+2 in the background so that a forward swipe starts playback without a visible loading wait in the common case.
- **FR-011**: Preparing upcoming videos and fetching feed pages MUST never block or degrade the responsiveness of the visible video or the swipe gesture; swiping MUST remain fluid at the device's native refresh rate.
- **FR-012**: When a video is 2 or more positions away from the visible video, its playback resources MUST be fully released, and this release MUST NOT cause any visible hitch or frame drop on the visible video.
- **FR-013**: The number of simultaneously prepared/held videos MUST be strictly capped (visible video plus its immediate neighbors within the preload window) so that memory use stays bounded regardless of session length.
- **FR-014**: Localized state changes (buffering indicator, play/pause state, reaction/comment/follow counters, button states) MUST update only the affected on-screen element and MUST NOT visibly interrupt, re-render, or drop frames on the playing video. This applies to the interaction overlay and the Creator Profile screen alike.

#### Playback Controls

- **FR-015**: Tapping the visible video (outside overlay controls) MUST toggle pause/resume, with a clear visual indication of the paused state.
- **FR-016**: A video that is still buffering MUST show a lightweight loading indicator on that video only.

#### Interaction Overlay (Love / Comment / Share)

- **FR-017**: Each full-screen video MUST display an overlay of floating action buttons for Love, Comment, and Share, each with a real-time counter shown in compact notation (e.g., 1.2K).
- **FR-018**: Tapping Love MUST toggle between active and inactive states instantly with a micro-animation, update the counter optimistically, and record the change on the backend; a failed request MUST revert the state.
- **FR-019**: Tapping Comment MUST open a lightweight bottom sheet containing a scrollable list of the video's comments and an input field; the video MUST remain visible and unaffected behind it.
- **FR-020**: Submitting a non-empty comment MUST append it to the visible list immediately, update the comment counter, and record it on the backend; empty/whitespace submissions MUST be rejected without side effects.
- **FR-021**: Tapping Share MUST open a custom in-app share bottom sheet laid out as: (a) **top row** — a horizontally scrollable list of the user's recent chats sourced from CiroChat's existing messaging data, each shown as a circular avatar with name, where a single tap instantly sends a reel-share message to that chat; (b) **bottom row** — a prominent Copy Link button followed by a single "Share via…" action that opens the device's native platform share sheet (no per-app branded icons). Dismissing the sheet at any point MUST leave playback state unchanged.
- **FR-021a**: The share counter MUST increment (recorded via the backend) only when the user sends the reel to a recent chat in-app or taps Copy Link; opening the sheet, dismissing it, or sharing through an external target MUST NOT increment the counter.
- **FR-021b**: The share sheet MUST render instantly and MUST NOT interrupt, stutter, or pause the video playing behind it; a user with no conversations sees the sheet without the recent-chats row while Copy Link and "Share via…" remain available.
- **FR-021c**: A reel shared in-app MUST appear in the conversation as a rich preview card — reel thumbnail, creator name, and a play badge — carried by a dedicated reel-share message subtype. Tapping the card MUST open the reel in-app (per FR-042). Message delivery, statuses, and offline queueing follow the existing chat message rules unchanged.
- **FR-022**: The creator's username and profile picture MUST be visible on the video overlay.

#### Creator Profile & Video Grid

- **FR-023**: Tapping the creator's username or profile picture on the overlay MUST navigate to that creator's dedicated profile screen.
- **FR-024**: The Creator Profile screen MUST display the creator's avatar, name, and bio, plus stats: followers count, following count, and total likes.
- **FR-025**: The Creator Profile screen MUST display all videos published by that creator as thumbnails in a 3-column grid.
- **FR-026**: Tapping any thumbnail in the grid MUST open a full-screen vertical feed starting at that video, scoped to that creator's videos.
- **FR-027**: A creator with no published videos MUST see a friendly empty state in place of the grid; a failed profile load MUST show an error state with retry.

#### Follow System

- **FR-028**: A prominent Follow button MUST appear on both the video interaction overlay and the Creator Profile screen.
- **FR-029**: Tapping the button MUST toggle between "Follow" and "Following" instantly (optimistic), with the action recorded on the backend and the state reverted on failure.
- **FR-030**: Follow state and follower counts MUST be consistent between the overlay and the profile screen for the same creator within a session.
- **FR-031**: Users MUST NOT be able to follow themselves; the button is hidden or disabled on their own profile.

#### Own Profile Access (Reels Screen)

- **FR-044**: The Reels screen MUST display a "Current User Profile" icon — rendered with the logged-in user's avatar — positioned at the top-left corner of the screen, overlaid on the playing video, on every video in the feed. It MUST NOT obstruct the creator info, the interaction overlay, or the system status bar. If the user has no avatar set (or it fails to load), a standard placeholder avatar is shown and the icon remains functional.
- **FR-045**: Tapping the top-left profile icon MUST route the user directly to their own User Profile Page in a single tap (no intermediate menu or confirmation). This page is the reels-style profile (the US4 profile surface rendered for self — avatar, username, stats, video grid, Liked/Saved lists), not the bottom bar's Profile tab, which remains unchanged (clarified). Leaving the feed this way follows the existing playback-stop rule (FR-004), and returning follows the existing resume-position rule (FR-004a).
- **FR-046**: The destination User Profile Page MUST fetch and display the user's profile picture using the profile picture URL already stored on the existing User Account schema (the same `avatarUrl` field extended per FR-055, not a new one). The page shows the avatar together with the user's name and profile details, and (being the user's own profile) offers no Follow button per FR-031.

#### Deep Linking

- **FR-038**: Every reel MUST have a unique, standard web URL of the form `https://ciro.chat/reels/<id>`; this exact URL is what all share actions (chat send, Copy Link, external targets) distribute.
- **FR-039**: Tapping a reel URL outside the app MUST open the CiroChat app via OS-level link handling on both iOS and Android (with the app installed).
- **FR-039a**: When the app is NOT installed, the reel URL MUST resolve in the browser to a minimal auto-redirect page (served by the backend, no authentication) that forwards iOS devices to the App Store and Android devices to Google Play; other platforms (e.g., desktop) see a basic page with links to both stores. No richer web experience is built in v1.
- **FR-040**: On opening via a reel link, the app MUST navigate directly to the Reels screen, fetch that specific video from the backend, and start the infinite feed with that video as the initial index; swiping onward continues into the regular feed.
- **FR-041**: While the linked video's data is being fetched, the Reels screen MUST display a loading skeleton (never a blank screen), and playback MUST begin as soon as the video is ready.
- **FR-042**: Reel links tapped inside a CiroChat conversation MUST navigate internally to the same experience without leaving the app.
- **FR-043**: A link to an unknown, deleted, or malformed reel MUST show a friendly error and land the user on the regular Reels feed; a failed fetch MUST offer retry. If the user is logged out, the normal login flow completes first and then continues to the linked reel.

#### Reel Content & Metrics

- **FR-047**: Each reel MUST carry a text description that supports hashtags (e.g., `#travel`) and user mentions (e.g., `@username`). The description is displayed on the video overlay, truncating gracefully when long; mentions that resolve to existing accounts are recognized as such, while unresolvable mentions render as plain text.
- **FR-047a**: Hashtags and resolvable mentions MUST be visually distinct and tappable (clarified): tapping a mention navigates to that user's profile screen; tapping a hashtag opens a hashtag feed — a full-screen vertical feed of all reels whose descriptions carry that hashtag, newest first, with the standard feed playback/overlay behavior.
- **FR-048**: Each reel MUST track a views count in addition to its likes, comments, and shares counts. A view is recorded when a user starts playback of the reel (counted once per user per reel).

#### Saved & Liked Videos

- **FR-049**: The interaction overlay MUST include a Save (bookmark) action that toggles instantly (optimistic), records the save/unsave on the backend, and reverts with a non-intrusive notice on failure. Saves are private — no public save counter is required.
- **FR-050**: The user MUST be able to fetch and browse their private "Saved Videos" list — every reel they have bookmarked — accessible from their own profile page and visible only to them. Tapping an item opens a full-screen vertical feed scoped to that list, starting at that video.
- **FR-051**: The user MUST be able to fetch and browse their private "Liked Videos" list — every reel they have loved — with the same access, privacy, and playback behavior as FR-050.

#### Search & Discovery

- **FR-057**: A Search screen MUST be reachable from the Reels screen (search entry point in the top area of the screen, opposite the own-profile icon). Submitting a query returns two result groups: **Videos** — reels having at least one hashtag containing the query string — and **Users** — accounts whose username or full name contains the query string. Matching is case-insensitive substring; whitespace-only queries are ignored.
- **FR-058**: Tapping a video result MUST open the full-screen vertical feed starting at that reel, scoped to the result set; tapping a user result MUST open that user's profile screen. Result lists paginate as needed and show a friendly empty state when nothing matches.
- **FR-059**: Search results and hashtag feeds MUST respect blocking (FR-052/FR-053): blocked parties and their reels never appear in the other party's results.

#### Privacy & Blocking

- **FR-052**: The system MUST support a directed block relationship between users. When user A blocks user B, B's reels MUST no longer appear in A's feed and A's reels MUST no longer appear in B's feed (mutual exclusion), enforced by the backend on every feed page it serves.
- **FR-053**: Block enforcement MUST extend beyond the main feed: blocked parties' reels are excluded from profile grids and Liked/Saved lists served to the other party, and a deep link to a blocked party's reel follows the unknown-reel error path (FR-043). Blocks created mid-session take effect from the next page fetch or refresh.

#### Notification Triggers

- **FR-054**: The backend MUST record a notification event AND deliver a push notification to the recipient's device (clarified: end-to-end delivery ships in this phase) for: a new follower, a new like on one of the user's reels, and a mention of the user in a reel's description. A user's actions on their own content (e.g., loving their own reel, mentioning themselves) MUST NOT generate events or notifications. If the recipient's device is unreachable or notifications are disabled, the event is still recorded and delivery fails silently (no error surfaced to the actor). Tapping a delivered notification opens the relevant destination in-app (the reel for likes/mentions, the follower's profile for new followers).

#### Reel Upload & Content Moderation

- **FR-060**: The Reels screen MUST offer an upload entry point through which an authenticated user can select or record a video, add a description (supporting hashtags and mentions per FR-047), and submit it as a new reel, with clear upload progress feedback. This supersedes the earlier assumption that uploading is out of scope. An interrupted or failed upload MUST NOT create a partial/phantom reel and MUST be cleanly retryable.
- **FR-060a**: A reel video is capped at **60 seconds**. Videos of 60 seconds or less upload as-is. When the user picks a longer source video, the app MUST present an in-app trim/segment selector (WhatsApp Status-style) letting them choose which contiguous ≤60-second portion to upload — over-length videos are never hard-rejected in the app, and the segment chosen is exactly what is uploaded and moderated. The backend MUST independently enforce the 60-second cap at upload time (rejecting over-length submissions from non-official clients), so the cap never relies on client behavior alone.
- **FR-061**: Every reel MUST carry a moderation status that is exactly one of: **pending review** (`pending_moderation`), **published**, or **rejected**. A newly uploaded reel MUST default to pending review. Only published reels may appear on any surface served to users other than the owner — the main feed, other users' views of the creator's profile grid, search results, hashtag feeds, Liked/Saved lists, follow-based queries, and share previews. For non-owners, a deep link to a non-published reel MUST follow the unknown-reel error path (FR-043). Seeded demo catalog content is vetted at seed time and enters directly as published.
- **FR-062**: After an uploaded reel's video is stored in the platform's media storage (CDN-hosted in production, per the existing media-hosting assumption), the system MUST automatically analyze both the video **and the reel's description text** for explicit, nudity, or NSFW content via a third-party AI moderation service, as a single background step that never blocks or delays the upload response to the user. A flag on either the video or the description rejects the reel (FR-064). Comment text moderation is out of scope for v1.
- **FR-063**: When the analysis returns a clean verdict, the reel's status MUST transition to published, making it eligible for all public surfaces, and the existing mention-notification logic (FR-054) MUST be triggered at that moment for resolvable @mentions in the description — exactly once per reel, and never before publication. Publication itself is silent: the uploader receives no notification for a clean verdict (the reel simply shows as live on their profile).
- **FR-064**: When the analysis flags the video or the description text as explicit/NSFW, the reel's status MUST transition to rejected, its video MUST be soft-deleted or hidden (retained internally per the moderation-retention assumption, but unreachable through any user-facing surface), and a notification/error record MUST be created for the uploader stating that the reel was removed for violating community guidelines — recorded as a notification event AND delivered as a push notification through the existing pipeline, following the FR-054 delivery semantics (event persists even if delivery fails silently); tapping it lands the uploader on their own profile, where the rejected reel is shown with its "Removed due to policy violations" state. A rejected reel MUST never send mention notifications and MUST accept no engagement (likes, comments, shares, saves, views).
- **FR-065**: The app MUST surface moderation states to the uploading user on their own profile (and any owner-facing reel view): a pending reel is clearly marked as **"Processing"**, and a rejected reel as **"Removed due to policy violations"**; published reels display normally with no moderation badge. Other users never see moderation states — for them, non-published reels simply do not exist.
- **FR-066**: If the moderation analysis fails, times out, or the service is unavailable, the reel MUST remain in pending review — a reel is never published without an explicit clean verdict — and the analysis MUST be retried automatically until a verdict is obtained.
- **FR-067**: The owner MUST be able to delete any of their own reels — published, pending review, or rejected — from their own profile (with a confirmation prompt; no other user can delete a reel). Deletion removes the reel from every surface (feeds, profile grids, search, hashtag feeds, Liked/Saved lists), adjusts the creator's public counts accordingly, and makes its deep link follow the unknown-reel error path (FR-043). Copies already loaded on other users' screens may finish playing, but every subsequent fetch or refresh excludes the deleted reel.

#### Backend Foundation

- **FR-032**: The backend MUST expose capabilities to: serve the paginated video feed, fetch a single video by its identifier (for deep links), toggle a like on a video, record a view, fetch and post comments for a video, record share events, toggle a save/bookmark, fetch the current user's Liked Videos and Saved Videos lists, fetch a user profile together with that user's published video list, follow/unfollow a user, block/unblock a user, record notification events and deliver push notifications for the triggers in FR-054, search reels by hashtag and users by name (FR-057), serve hashtag-scoped feeds (FR-047a), serve the unauthenticated store-redirect fallback page for reel URLs opened without the app, accept a new reel upload (video media + description) creating it in pending review, run the background automated moderation pipeline with its publish/reject transitions (FR-061–FR-064, FR-066), serve the owner their own reels with moderation status included (FR-065), and delete a reel on its owner's request (FR-067).
- **FR-033**: These capabilities MUST be backed by a real database implemented in this phase (clarified; supersedes the earlier mock-data allowance). The schema is relationally structured (videos ↔ creators ↔ likes ↔ comments ↔ follows ↔ saves ↔ blocks ↔ notification events), and the database is seeded with demo content so the feature is fully exercisable before real user-generated content exists.
- **FR-055**: The data architecture MUST be read-optimized for fast feed generation: follower/following/total-likes counts on user accounts and views/likes/comments/shares counts on reels are maintained as stored counter fields (kept consistent with the underlying relations) so displaying any count never requires scanning relation records, and the follow/like/save/block relations are indexed such that queries like "reels from users I follow" and "reels liked/saved by me" stay fast as data grows. Hashtags extracted from descriptions and user names MUST likewise be indexed so hashtag feeds and search queries (FR-057) stay fast at scale.
- **FR-056**: The complete schema design — an entity-relationship diagram covering users, reels, follows, likes, comments, saves, blocks, and notification events, including the counter fields and indexes from FR-055 — MUST be produced and approved before implementation begins (delivered as the planning phase's data model).

#### Error Handling

- **FR-034**: If the initial feed fetch fails or returns no videos, the feed MUST show an appropriate empty/error state with a retry action.
- **FR-035**: If an individual video fails to load or play, the feed MUST show an error placeholder for that item only and MUST allow the user to swipe past it.
- **FR-036**: If a pagination request fails, previously loaded videos MUST remain browsable and the fetch MUST be retryable.
- **FR-037**: Failed engagement actions (love, comment, follow) MUST revert their optimistic UI change and surface a non-intrusive notice without interrupting playback.

### Key Entities

- **Reel (Video Item)**: A short video available in the feed. Key attributes: unique identifier, video media location (CDN-hosted in production), optional thumbnail/preview image, creator reference, text description (supporting #hashtags and @mentions), **moderation status** (pending review / published / rejected — defaults to pending review on upload; only published reels are publicly servable, per FR-061), views count, likes count, comments count, shares count, creation time (used for feed sorting), current viewer's like and save states, and a canonical deep link URL derived from its identifier (`https://ciro.chat/reels/<id>`).
- **Moderation Result**: The recorded outcome of a reel's automated content review, covering both the video and the description text (FR-062). Key attributes: reel reference, verdict (clean/flagged), flagged source (video and/or description) and categories where applicable (explicit, nudity, NSFW), provider reference/raw result for audit, completion time. Drives the reel's status transition (FR-063/FR-064) and supports retry on failure (FR-066).
- **Creator (User Account / Profile)**: The publisher of reels — the existing CiroChat user record extended with Reels profile fields (clarified: one shared identity for chat and Reels, not a separate profile entity). Key attributes: identifier, unique username, full name, avatar (profile picture — the same one used across chat), bio, followers count, following count, total likes across their videos (all three maintained as stored counter fields per FR-055), list of published reels, current viewer's follow state.
- **Comment**: A viewer's text remark on a specific Reel. Key attributes: identifier, author (user), reel reference, text, creation time.
- **Like**: A user's reaction to a specific Reel; connects a user to a Reel, adjusts the Reel's likes count and the creator's total likes, and collectively forms the user's Liked Videos list.
- **Save (Bookmark)**: A private user↔Reel relationship marking a reel as saved; collectively forms the user's Saved Videos list, visible only to that user.
- **Follow**: A directed relationship from one user to another; adjusts followers/following counts on both profiles and must be efficiently queryable as "reels from users I follow".
- **Block**: A directed relationship from one user to another that mutually excludes each party's reels from the other's feed surfaces (FR-052/FR-053).
- **Hashtag**: A normalized tag extracted from reel descriptions; many-to-many with Reels and indexed so hashtag feeds and hashtag search stay fast (FR-055).
- **Notification Event**: A recorded trigger that drives push delivery (FR-054). Key attributes: type (new follower, new like, mention, reel rejected for policy violation — FR-064), actor (who caused it; system-originated for rejections), recipient (who gets notified), subject reel reference where applicable, creation time.
- **Feed Page**: An ordered batch of Reels returned by the backend for a given position in the feed (block-filtered per viewer), with an indicator of whether more content is available (for infinite scrolling).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a forward swipe to an already-prepared video, playback begins within 300 ms of the swipe settling in at least 95% of transitions on a normal network.
- **SC-002**: Swiping through the feed produces no user-perceivable stutter: scroll animation runs at the device's native refresh rate with no visible dropped frames during transitions, video start, or video disposal.
- **SC-003**: A user can browse 100+ videos in a single session with no crash, no progressive slowdown, and app memory use remaining bounded (no growth proportional to the number of videos watched).
- **SC-004**: At no point is more than one video audible; audio from a previous video stops within 100 ms of the next video becoming visible.
- **SC-005**: Users can reach the Reels feed from the main screen in a single tap, and the first video is playing within 2 seconds of opening the feed on a normal network.
- **SC-006**: Love, comment-count, and follow interactions reflect on screen within 100 ms of the tap, and none of them causes a visible frame drop or glitch in the playing video.
- **SC-007**: The comment sheet and the share sheet each open within 300 ms of tapping their action, and the video behind them keeps playing uninterrupted with no dropped frames.
- **SC-007a**: Tapping a reel deep link (app installed, logged in, normal network) shows the linked video playing within 3 seconds, with a skeleton — never a blank screen — covering any fetch delay.
- **SC-007b**: Sending a reel to a recent chat from the share sheet takes exactly one tap and completes without leaving the Reels screen.
- **SC-008**: The Creator Profile screen displays user info, stats, and the video grid within 2 seconds of navigation on a normal network, and tapping a grid thumbnail starts that video's feed playback within the same bound as SC-005.
- **SC-009**: Follow/unfollow state is consistent across the overlay and the profile screen 100% of the time within a session.
- **SC-010**: 100% of feed/network/engagement failures result in an explanatory state or reverted action with a retry path — never a blank screen, frozen UI, stuck counter, or crash.
- **SC-011**: From the Reels feed, the user reaches their own profile page in exactly one tap on the top-left profile icon, and their account profile picture is visible on that page within 2 seconds on a normal network (placeholder shown otherwise — never a broken image).
- **SC-012**: Save/unsave reflects on the overlay within 100 ms of the tap with no visible frame drop in the playing video, and the Liked Videos and Saved Videos lists each display within 2 seconds of opening on a normal network.
- **SC-013**: After a block is in place, 0 reels from either blocked party appear on any feed surface served to the other (main feed pages, profile grids, Liked/Saved lists) — verified across pagination and refresh.
- **SC-014**: 100% of qualifying actions (new follower, new like on a reel, resolvable mention in a description) produce exactly one recorded notification event, and 0 events are produced for a user's actions on their own content. When the recipient's device is reachable with notifications enabled, the push notification arrives within 10 seconds of the triggering action.
- **SC-015**: Displaying any counter (followers, following, total likes, views, likes, comments, shares) never degrades as data grows — counts render as instantly on large datasets as on small ones.
- **SC-016**: Search results (both Videos and Users groups) appear within 2 seconds of submitting a query on a normal network, and a hashtag feed opens and starts playing within the same bound as SC-005.
- **SC-017**: 0 reels are ever visible to a non-owner before receiving a clean moderation verdict, and 0 flagged reels ever appear on any public surface — verified across the main feed, profile grids, search, hashtag feeds, and deep links, including under moderation-service outages.
- **SC-018**: For a reel video (≤60 seconds per FR-060a) on a normal network, a moderation verdict is reached and the uploader's displayed state transitions out of "Processing" (to published or "Removed due to policy violations") within 5 minutes of upload completion, and the state shown to the uploader matches the recorded status 100% of the time.
- **SC-019**: 100% of rejected uploads produce exactly one community-guidelines violation notice for the uploader, and 0 mention notifications are ever sent for a reel that was not published.

## Assumptions

- **Consumption, engagement, and creation (v1)**: Users watch, love, save, comment on, share, follow — and upload their own reels (added 2026-07-03, superseding the earlier "recording/uploading is out of scope" assumption; every upload passes automated moderation per FR-060–FR-066). Editing/deleting comments and editing a reel after upload remain out of scope.
- **Automated moderation only (v1)**: Content review is performed exclusively by a third-party AI moderation service covering both video and text (candidate providers: AWS Rekognition Content Moderation, Google Cloud Video Intelligence, Sightengine — the concrete choice is an implementation-plan decision; description-text screening may use the same provider's text endpoint or a companion service). There is no human review queue, no appeals flow, and no user-facing "report content" mechanism in this phase. The service's default explicit/nudity/NSFW detection categories and confidence thresholds are used as the flag/clean boundary. Comment text is not moderated in v1. There are no account-level consequences for repeat violators in v1 (clarified) — each rejection stands alone; strike/throttle/suspension systems are deferred until human review and an appeals flow exist, since automated-only moderation can produce false positives.
- **Rejected media is soft-deleted, not purged**: A rejected reel's record and media are hidden from every user-facing surface but retained internally for a reasonable period (audit trail, potential future appeals) before permanent deletion; retention specifics are an implementation-plan decision.
- **Moderation applies to new uploads**: The pre-vetted seeded demo catalog enters the database directly as published; only user-uploaded reels flow through the pending-review pipeline.
- **Explicitly out of scope this phase** (stakeholder direction): live streaming, wallets, and coin/diamond systems — none of these appear in the schema or interfaces.
- **Call functionality fully unchanged**: The Calls tab, call history, and all calling flows are untouched; Reels is purely additive to the navigation bar (superseding the original "replace the Call tab" instruction per clarification).
- **Backend provides the catalog and engagement capabilities on a real, seeded database**: The existing CiroChat backend will expose the paginated feed, like/view recording, comments fetch/post, share recording, save toggling, liked/saved lists, profile-with-videos, follow/unfollow, block/unblock, and notification-event capabilities, all backed by the real database schema delivered this phase (per clarification; supersedes the earlier mock-data direction). Seeded videos point at public sample MP4 URLs (no backend-hosted video assets in v1). Defining/implementing these backend capabilities is part of this feature's delivery.
- **Comments and other engagement records persist**: with the real database in place, posted comments, likes, saves, follows, and blocks are durably stored (supersedes the earlier session-only persistence caveat); seeded demo comments coexist with real ones.
- **Share distributes the reel's canonical deep link** (`https://ciro.chat/reels/<id>`). In-app sharing sends a reel-share message through the existing chat infrastructure — a dedicated message subtype whose metadata carries the reel id, thumbnail, and creator name so the bubble renders as a rich preview card (clarified; supersedes the earlier plain-text-message default). External sharing goes exclusively through the OS share sheet ("Share via…"), receives the plain link, and is untracked.
- **Deep link domain ownership**: `ciro.chat` (or the final production domain) must serve the OS link-association files (Apple App Site Association / Android Asset Links) for links to open the app directly, and must route `/reels/:id` browser requests to the backend's store-redirect page. App Store and Google Play listing URLs are configuration values (placeholders until the app is published). Until domain hosting exists, development builds rely on a custom URL scheme fallback and platform tooling to simulate link taps; the in-app URL structure is identical either way.
- **Recent chats** in the share sheet are the user's most recent conversations from the existing chat feature (both direct and group), capped to a small number (e.g., 10) for instant rendering.
- **Feed ordering is backend-driven**: The feed order is whatever the backend returns (e.g., recency-based). Personalized ranking/recommendation (including follow-based ranking) is out of scope; the follow system only lays the foundation.
- **Authenticated users only**: The feed is available to logged-in CiroChat users, reusing the app's existing authentication/session.
- **Videos play with sound on by default**, consistent with mainstream short-video experiences; device silent-mode behavior follows platform conventions.
- **Preload window of 2**: "Intelligent preloading" means preparing the next two videos (and keeping the immediately previous one warm), matching the stated constraint that resources are released when an item is 2+ positions out of view.
- **Own profile page reuses existing building blocks**: The "User Profile Page" reached from the Reels screen's top-left icon is the user's own profile view (the same profile surface as US4, rendered for self, with Follow hidden per FR-031). Its avatar comes from the profile picture URL on the User Account schema. The Liked Videos and Saved Videos lists (US8) also surface from this page as owner-only sections.
- **Block management entry point**: This feature guarantees backend block/unblock capability and automatic feed enforcement (FR-052/FR-053). The block action's UI entry point is assumed to be an option on the Creator Profile screen (and/or CiroChat's existing user-blocking surface if one exists); a dedicated block-management settings screen is not part of this feature.
- **View counting definition**: A view is counted when playback of a reel starts for a user, deduplicated per user per reel. Watch-time analytics and completion rates are out of scope.
- **Search scope and ranking (v1 defaults)**: Video matching is by hashtag substring only (full-text description search is out of scope); user matching is by username/full-name substring. Ranking is simple — recency for videos, closest-match/alphabetical for users; no personalized or engagement-weighted ranking. The search entry point sits in the Reels screen's top area opposite the own-profile icon.
- **Push delivery infrastructure**: Push notifications are delivered end-to-end in this phase (clarified) through the app's push infrastructure (stakeholder-specified as FCM), reusing CiroChat's existing device-token registration where available. Notification preferences/settings and an in-app notification center remain out of scope — delivery uses sensible defaults (all three event types on).
- **CDN media hosting is the production target**: The schema stores CDN-integrated video and thumbnail URLs. In v1 the seeded catalog continues to point at public sample URLs (per earlier clarification); swapping to CDN-hosted assets changes data values only, not structure.
- **ERD approval gate**: Per stakeholder acceptance criteria, the schema design (ERD with relations, counter fields, and indexes) is delivered for approval — as the planning phase's `data-model.md` — before implementation of these backend modules begins (FR-056).
- **Stakeholder-provided engineering constraints** (asynchronous initialization, granular rebuilds, pre-buffering strategy, disposal policy, overlay/profile sub-widget isolation) are recorded as the performance requirements FR-010 through FR-014 in behavior form; the concrete technical approach will be defined in the implementation plan.
