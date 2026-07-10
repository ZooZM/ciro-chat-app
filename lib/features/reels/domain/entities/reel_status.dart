/// v3 (FR-061): the reel moderation status state machine. New uploads
/// default to [pendingModeration]; only [published] reels are ever visible
/// to non-owners on any surface. v4 (FR-070): [hidden] added — a report
/// auto-hide, resolved only by an admin restore (back to [published]) or
/// rejection ([rejected]); distinct from [pendingModeration] so the owner
/// sees "Under review" rather than "Processing" (FR-072).
enum ReelStatus {
  pendingModeration,
  published,
  rejected,
  hidden;

  static ReelStatus fromJson(String? value) {
    switch (value) {
      case 'pending_moderation':
        return ReelStatus.pendingModeration;
      case 'rejected':
        return ReelStatus.rejected;
      case 'hidden':
        return ReelStatus.hidden;
      case 'published':
      default:
        return ReelStatus.published;
    }
  }
}
