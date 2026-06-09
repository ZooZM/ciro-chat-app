# Bug Reports from Feature 008 Testing

## Bug #1: Video Playback Fails with OSStatus Error -9405

**Title:** Video fails to load with OSStatus error -9405 in media gallery viewer

**Description:**
Video fails to load when opened on another device after being sent.

**Error Message:**
```
PlatformException (PlatformException(VideoError, Failed to load video: The operation could not be completed: An unknown error occurred (-9405): The operation couldn't be completed. (OSStatus error -9405.), null, null))
```

**Location:**
`lib/features/chat/presentation/widgets/media_gallery_viewer.dart` line 124

**Steps to Reproduce:**
1. Send video from Device A to Device C
2. On Device B, open the video from gallery viewer
3. Video fails to load with OSStatus -9405

**Expected Behavior:**
Video should play without errors

**Actual Behavior:**
Video fails to load with platform exception

**Environment:**
- Found during T020 regression testing
- Affects video playback only (sending works)
- Text and image messages work fine

**Labels:** `bug`, `video`, `media`, `P2`

---

## Bug #2: Voice Note Recording Succeeds But Message Doesn't Send

**Title:** Voice note file saves but message doesn't appear in chat

**Description:**
User can successfully record a voice note and file is saved to disk, but the message never appears in the chat.

**Logs:**
```
I/flutter (19260): [ChatInputBar] Recording started successfully.
I/MPEG4Writer(19260): Earliest track starting time: 0
I/flutter (19260): [ChatInputBar] Calling recorderController.stop()... (savedPath=/data/user/0/com.example.ciro_chat_app/app_flutter/voice_note_1779191952533.m4a)
```

**Steps to Reproduce:**
1. Device B (Android emulator): Tap voice note button in chat input
2. Record audio (swipe up to lock)
3. Release to send
4. Voice note file is saved to `/data/user/0/com.example.ciro_chat_app/app_flutter/voice_note_TIMESTAMP.m4a`

**Expected Behavior:**
Voice note message appears in chat

**Actual Behavior:**
Audio saved to file but message doesn't send/appear in chat. No error displayed to user.

**Environment:**
- Android emulator only
- Works correctly on iOS simulator
- Found during T020 regression testing

**Labels:** `bug`, `voice`, `media`, `android`, `P1`

---

## Bug #3: Message Delivered State Not Visually Displayed

**Title:** Message jumps from sent to read, skipping delivered state

**Description:**
Message status transitions directly from `sent` to `read` without displaying the `delivered` state visually to the sender, even though delivered messages are being received.

**Steps to Reproduce:**
1. Device A: Send message
2. Message shows as `sent` (single checkmark)
3. Device B: Receives message (message is in delivered state)
4. Device B: Opens chat
5. Device A: Message jumps directly to `read` (double checkmark)

**Expected Behavior:**
Message status should show: `sent` → `delivered` → `read`
- Single checkmark (sent)
- Double checkmark (delivered) 
- Double checkmark filled in blue (read)

**Actual Behavior:**
Message skips the delivered state visually and goes directly from sent to read

**Likely Cause:**
Message marked as read immediately upon being received, causing delivered state to be skipped in visual update

**Context:**
- Found during T016 single-device regression test
- Not related to feature 008 (multi-device read suppression)
- May be pre-existing issue

**Labels:** `bug`, `ui`, `message-status`, `P2`

---

## How to Create These Issues on GitHub

1. Go to: https://github.com/YOUR_REPO/issues/new
2. Click "New Issue"
3. Copy title and description from above
4. Add labels from the "Labels" section
5. Create issue

Or use GitHub CLI:
```bash
gh issue create --title "Bug: Video playback fails with OSStatus error -9405" --body "$(cat << 'EOF'
... [paste description] ...
EOF
)" --label "bug,video,media"
```
