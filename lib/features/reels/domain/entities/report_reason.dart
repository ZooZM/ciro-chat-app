/// v4 (FR-069): preset report reasons; [other] requires a non-empty custom
/// reason from the caller (validated server-side too — the cap never
/// relies on client behavior alone).
enum ReportReason {
  spam,
  nudity,
  violence,
  hateSpeech,
  other;

  String toJson() {
    switch (this) {
      case ReportReason.spam:
        return 'spam';
      case ReportReason.nudity:
        return 'nudity';
      case ReportReason.violence:
        return 'violence';
      case ReportReason.hateSpeech:
        return 'hate_speech';
      case ReportReason.other:
        return 'other';
    }
  }
}
