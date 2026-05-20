class VoiceWaveformGeometry {
  final String messageId;
  final List<double> samples;
  final int? duration;

  const VoiceWaveformGeometry({
    required this.messageId,
    required this.samples,
    this.duration,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceWaveformGeometry &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          duration == other.duration &&
          _listEquals(samples, other.samples);

  @override
  int get hashCode => messageId.hashCode ^ duration.hashCode ^ samples.length.hashCode;

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.0001) return false;
    }
    return true;
  }
}
