/// v3 (FR-061): the reel moderation status state machine. New uploads
/// default to [pendingModeration]; only [published] reels are ever visible
/// to non-owners on any surface.
enum ReelStatus {
  pendingModeration,
  published,
  rejected;

  static ReelStatus fromJson(String? value) {
    switch (value) {
      case 'pending_moderation':
        return ReelStatus.pendingModeration;
      case 'rejected':
        return ReelStatus.rejected;
      case 'published':
      default:
        return ReelStatus.published;
    }
  }
}
