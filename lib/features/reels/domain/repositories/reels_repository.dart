import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:fpdart/fpdart.dart';
import '../entities/creator_profile.dart';
import '../entities/followed_user.dart';
import '../entities/reel.dart';
import '../entities/reel_comment.dart';
import '../entities/reels_page.dart';
import '../entities/report_reason.dart';
import '../entities/search_user.dart';
import '../entities/upload_cancel_token.dart';

abstract class ReelsRepository {
  /// v3 (FR-060): uploads a new reel — created `pending_moderation`
  /// (FR-061). [onSendProgress] receives `(sent, total)` bytes;
  /// [cancelToken] lets the caller abort a still-uploading request.
  Future<Either<Failure, Reel>> uploadReel({
    required String videoPath,
    String? thumbnailPath,
    required String description,
    void Function(int sent, int total)? onSendProgress,
    UploadCancelToken? cancelToken,
  });

  /// v3 (FR-067): owner-only, any status.
  Future<Either<Failure, Unit>> deleteReel(String id);
  /// Main feed when [creatorId]/[hashtag] are null (loops the catalog,
  /// FR-007); creator-scoped (FR-026) or hashtag-scoped (FR-047a) otherwise
  /// — both finite.
  Future<Either<Failure, ReelsPage>> fetchFeed({
    String? cursor,
    String? creatorId,
    String? hashtag,
  });

  /// Single reel fetch — used for deep-link entry (FR-040).
  Future<Either<Failure, Reel>> fetchReel(String id);

  Future<Either<Failure, ({bool liked, int likesCount})>> toggleLike(String id);

  Future<Either<Failure, ({List<ReelComment> items, String? nextCursor, int commentsCount})>>
      fetchComments(String id, {String? cursor});

  Future<Either<Failure, ({ReelComment comment, int commentsCount})>> postComment(
    String id,
    String text,
  );

  Future<Either<Failure, int>> recordShare(String id);

  Future<Either<Failure, CreatorProfile>> fetchProfile(String userId);

  Future<Either<Failure, ({bool following, int followersCount})>> toggleFollow(String userId);

  /// FR-048: fire-and-forget on playback start; deduped server-side per
  /// user per reel.
  Future<Either<Failure, int>> recordView(String id);

  /// FR-049: private toggle, no public counter.
  Future<Either<Failure, bool>> toggleSave(String id);

  /// FR-051: caller's Liked Videos, newest-liked-first.
  Future<Either<Failure, ReelsPage>> fetchLiked({String? cursor});

  /// FR-050: caller's Saved Videos, newest-saved-first.
  Future<Either<Failure, ReelsPage>> fetchSaved({String? cursor});

  /// v6: a user's public Reposts list, newest-repost-first. [userId] null →
  /// the caller's own reposts.
  Future<Either<Failure, ReelsPage>> fetchReposted({String? userId, String? cursor});

  /// FR-057: reels whose hashtags contain [query] (case-insensitive substring).
  Future<Either<Failure, ReelsPage>> searchReels(String query, {String? cursor});

  /// FR-057: users whose username/name contain [query].
  Future<Either<Failure, ({List<SearchUser> items, String? nextCursor})>> searchUsers(
    String query, {
    String? cursor,
  });

  /// FR-052: toggles the shared block relationship with [userId].
  Future<Either<Failure, bool>> toggleBlock(String userId);

  /// v4 (FR-069): reports [id] with [reason] (+ [customReason] iff
  /// `reason == ReportReason.other`). Reports only against `published`
  /// reels; own reels are rejected server-side. Returns whether this was
  /// already reported by the caller (a duplicate — no-op, no re-count) so
  /// the UI can show a distinct notice; a 429 (daily limit) surfaces as
  /// [RateLimitedFailure].
  Future<Either<Failure, bool>> reportReel(
    String id,
    ReportReason reason, {
    String? customReason,
  });

  /// v4 (FR-073): explicit repost — NOT a toggle. Never on the viewer's own
  /// reels (rejected server-side).
  Future<Either<Failure, Unit>> repostReel(String id);

  /// v4 (FR-073): explicit un-repost — idempotent no-op if none existed.
  Future<Either<Failure, Unit>> unrepostReel(String id);

  /// v4 (FR-075): Following tab — original reels only from users the
  /// caller follows; finite (no catalog looping), no reposts.
  Future<Either<Failure, ReelsPage>> fetchFollowing({String? cursor});

  /// v5 (FR-084): the caller's followees, most-recently-followed first —
  /// feeds the post-details `@`-mention suggestion overlay (FR-083).
  Future<Either<Failure, ({List<FollowedUser> items, String? nextCursor})>> getFollowingUsers({
    String? cursor,
  });

  /// v6: everyone who reposted [reelId], most-recent-first — the reposters
  /// bottom sheet.
  Future<Either<Failure, ({List<FollowedUser> items, String? nextCursor})>> fetchReposters(
    String reelId, {
    String? cursor,
  });
}
