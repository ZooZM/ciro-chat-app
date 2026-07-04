import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'domain/entities/reel.dart';

/// Shared tuning constants for the Reels feature (021-reels-video-feed).
class ReelsConstants {
  ReelsConstants._();

  /// Canonical deep-link base — see contracts/reels-api.md.
  /// A reel's public URL is `deepLinkBase + reelId`.
  static String get deepLinkBase =>
      dotenv.maybeGet('REELS_DEEP_LINK_BASE') ??
      const String.fromEnvironment(
        'REELS_DEEP_LINK_BASE',
        defaultValue: 'https://ciro.chat/reels/',
      );

  /// Custom-scheme fallback used until the production domain hosts the
  /// OS link-association files (research.md R7).
  static const String deepLinkScheme = 'cirochat';

  /// Page size for `GET /api/reels` pagination.
  static const int feedPageSize = 10;

  /// Page size for `GET /api/reels/:id/comments` pagination.
  static const int commentsPageSize = 20;

  /// Trigger the next page fetch once fewer than this many unseen reels
  /// remain ahead of the current index (FR-007).
  static const int prefetchPageThreshold = 3;

  /// Maximum simultaneously *live* media_kit players — current + immediate
  /// neighbors. Hard invariant per the sliding-window design (FR-013).
  static const int maxLivePlayers = 3;

  /// Approximate bytes to pre-buffer per live player (research.md R1).
  static const int playerBufferSizeBytes = 8 * 1024 * 1024;

  /// Approximate bytes to prefetch over HTTP for the N+2 neighbor, which
  /// gets no live controller (research.md R2).
  static const int prefetchRangeBytes = 1 * 1024 * 1024;

  /// Safety-net timeout: if a player never leaves the buffering state within
  /// this window (e.g. an unreachable host that neither errors nor resolves),
  /// it's treated as a failed item so the spinner doesn't spin forever (FR-035).
  static const Duration bufferingTimeout = Duration(seconds: 15);

  /// Recent-chats row cap in the share sheet (spec.md Assumptions).
  static const int recentChatsLimit = 10;
}

/// Deep-link derivation kept out of the domain entity (which must not
/// depend on `flutter_dotenv`) — constitution I, Clean Architecture.
extension ReelDeepLink on Reel {
  /// Canonical public URL for this reel (FR-038).
  String get deepLinkUrl => '${ReelsConstants.deepLinkBase}$id';
}
