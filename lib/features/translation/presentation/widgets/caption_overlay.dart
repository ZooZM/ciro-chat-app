import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/caption.dart';

/// Renders the live translated caption for one speaker over their video tile
/// (FR-004). Bound directly to `TranslationCubit.captionNotifier(speakerId)` —
/// only this widget rebuilds on a caption update (FR-007/FR-015).
class CaptionOverlay extends StatelessWidget {
  final ValueListenable<Caption?> caption;

  const CaptionOverlay({super.key, required this.caption});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Caption?>(
      valueListenable: caption,
      builder: (context, value, _) {
        if (value == null || value.text.isEmpty) return const SizedBox.shrink();

        final isFinal = value.type == CaptionType.final_;
        return Container(
          constraints: const BoxConstraints(maxHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: isFinal ? 0.7 : 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontStyle: isFinal ? FontStyle.normal : FontStyle.italic,
              fontWeight: isFinal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      },
    );
  }
}
