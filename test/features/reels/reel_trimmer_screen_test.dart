import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ciro_chat_app/features/reels/presentation/pages/reel_trimmer_screen.dart';

void main() {
  group('ReelTrimmerScreen maxDuration (v5, FR-081/binding rule 15)', () {
    // Widget construction only — pumping would drive `VideoEditorController`
    // to hit the real `video_player` platform channel, which isn't
    // available in a plain widget test. The parameter itself (the trimmer's
    // capture-cap contract) is what this test verifies.
    test('defaults to 60 seconds when not specified (gallery-pick path)', () {
      final widget = ReelTrimmerScreen(sourceFile: File('irrelevant.mp4'));
      expect(widget.maxDuration, const Duration(seconds: 60));
    });

    test('honors a 15s cap passed from the capture screen', () {
      final widget = ReelTrimmerScreen(
        sourceFile: File('irrelevant.mp4'),
        maxDuration: const Duration(seconds: 15),
      );
      expect(widget.maxDuration, const Duration(seconds: 15));
    });

    test('honors a 60s cap passed from the capture screen', () {
      final widget = ReelTrimmerScreen(
        sourceFile: File('irrelevant.mp4'),
        maxDuration: const Duration(seconds: 60),
      );
      expect(widget.maxDuration, const Duration(seconds: 60));
    });
  });
}
