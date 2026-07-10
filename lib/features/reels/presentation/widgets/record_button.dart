import 'package:flutter/material.dart';

/// v5 (FR-079): the large red record toggle — tap starts a single continuous
/// clip, tap again stops it (no pause/resume segments, clarified). The
/// progress ring reflects [elapsed]/[cap] while recording.
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.progress,
    required this.onTap,
  });

  final bool isRecording;

  /// 0.0–1.0, meaningful only while [isRecording].
  final double progress;

  final VoidCallback onTap;

  static const _size = 76.0;
  static const _innerSize = 60.0;
  static const _innerSizeRecording = 30.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: _size,
              height: _size,
              child: CircularProgressIndicator(
                value: isRecording ? progress : 0,
                strokeWidth: 4,
                backgroundColor: Colors.white38,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isRecording ? _innerSizeRecording : _innerSize,
              height: isRecording ? _innerSizeRecording : _innerSize,
              decoration: BoxDecoration(
                color: Colors.red,
                // shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isRecording
                    ? BorderRadius.circular(8)
                    : BorderRadius.circular(100),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
