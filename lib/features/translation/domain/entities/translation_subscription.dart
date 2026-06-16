import 'package:equatable/equatable.dart';

/// State machine for a listener's per-speaker translation toggle.
///
/// ```text
/// off --(user enables)--> pending
/// pending --(translation:subscribed)--> active
/// pending --(translation:denied)--> denied
/// active --(user changes language)--> pending
/// active --(translation_unavailable)--> unavailable
/// unavailable --(translation:subscribed)--> active
/// {pending, active, denied, unavailable} --(user disables)--> off
/// {pending, active, unavailable} --(speaker leaves call)--> off
/// ```
enum TranslationStatus { off, pending, active, denied, unavailable }

/// A listener's translation toggle/status for one speaker.
class TranslationSubscription extends Equatable {
  final String speakerId;
  final String targetLanguage;
  final TranslationStatus status;

  /// Set when [status] == [TranslationStatus.unavailable]:
  /// `language_undetected` | `unsupported_language` | `service_outage`.
  final String? unavailableReason;

  /// Set when [status] == [TranslationStatus.denied]:
  /// `insufficient_credits` | `not_a_participant` | `unsupported_language` |
  /// `unauthenticated`.
  final String? deniedReason;

  const TranslationSubscription({
    required this.speakerId,
    required this.targetLanguage,
    required this.status,
    this.unavailableReason,
    this.deniedReason,
  });

  TranslationSubscription copyWith({
    String? speakerId,
    String? targetLanguage,
    TranslationStatus? status,
    String? unavailableReason,
    String? deniedReason,
    bool clearUnavailableReason = false,
    bool clearDeniedReason = false,
  }) {
    return TranslationSubscription(
      speakerId: speakerId ?? this.speakerId,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      status: status ?? this.status,
      unavailableReason: clearUnavailableReason
          ? null
          : (unavailableReason ?? this.unavailableReason),
      deniedReason: clearDeniedReason
          ? null
          : (deniedReason ?? this.deniedReason),
    );
  }

  @override
  List<Object?> get props => [
    speakerId,
    targetLanguage,
    status,
    unavailableReason,
    deniedReason,
  ];
}
