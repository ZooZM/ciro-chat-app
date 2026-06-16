import 'package:equatable/equatable.dart';

/// Stability of a caption update (FR-005/FR-006/FR-009).
///
/// `final_` because `final` is a Dart keyword.
enum CaptionType { interim, final_ }

/// A single translated (or transcribed) caption update for one speaker.
class Caption extends Equatable {
  final String speakerId;
  final String text;
  final CaptionType type;
  final String sourceLanguage;
  final String targetLanguage;
  final String segmentId;
  final int seq;
  final int ts;

  const Caption({
    required this.speakerId,
    required this.text,
    required this.type,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.segmentId,
    required this.seq,
    required this.ts,
  });

  @override
  List<Object?> get props => [
    speakerId,
    text,
    type,
    sourceLanguage,
    targetLanguage,
    segmentId,
    seq,
    ts,
  ];
}
