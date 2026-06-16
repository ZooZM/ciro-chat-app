import '../../domain/entities/caption.dart';

/// Wire format for a `topic: "translation"` LiveKit data-channel packet, per
/// `contracts/caption-data-channel.md`:
///
/// ```jsonc
/// {
///   "v": 1,
///   "type": "interim" | "final",
///   "speakerId": "string",
///   "sourceLanguage": "string",
///   "targetLanguage": "string",
///   "text": "string",
///   "segmentId": "string",
///   "seq": 0,
///   "ts": 0
/// }
/// ```
class CaptionModel {
  final int v;
  final String type;
  final String speakerId;
  final String sourceLanguage;
  final String targetLanguage;
  final String text;
  final String segmentId;
  final int seq;
  final int ts;

  const CaptionModel({
    required this.v,
    required this.type,
    required this.speakerId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.text,
    required this.segmentId,
    required this.seq,
    required this.ts,
  });

  /// Returns `null` on any parse failure (Constitution VII "Silent
  /// Failures") — required, non-empty `speakerId`/`segmentId`, `type` ∈
  /// {`interim`, `final`}. `seq`/`ts` default to `0` if missing/non-numeric.
  static CaptionModel? fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type != 'interim' && type != 'final') return null;

    final speakerId = json['speakerId'];
    if (speakerId is! String || speakerId.isEmpty) return null;

    final segmentId = json['segmentId'];
    if (segmentId is! String || segmentId.isEmpty) return null;

    final text = json['text'];
    if (text is! String) return null;

    final sourceLanguage = json['sourceLanguage'];
    final targetLanguage = json['targetLanguage'];
    if (sourceLanguage is! String || targetLanguage is! String) return null;

    final v = json['v'];

    return CaptionModel(
      v: v is int ? v : 1,
      type: type,
      speakerId: speakerId,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      text: text,
      segmentId: segmentId,
      seq: json['seq'] is int ? json['seq'] as int : 0,
      ts: json['ts'] is int ? json['ts'] as int : 0,
    );
  }

  Caption toEntity() {
    return Caption(
      speakerId: speakerId,
      text: text,
      type: type == 'final' ? CaptionType.final_ : CaptionType.interim,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      segmentId: segmentId,
      seq: seq,
      ts: ts,
    );
  }
}
