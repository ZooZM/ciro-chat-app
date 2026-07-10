import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// v5 (FR-080): the "Video | 15s | 30s | 60s" selector above the record
/// button. "Video" is a static mode label (no other capture modes exist);
/// 15s/30s/60s pick the recording auto-stop cap. Disabled while recording
/// (clarified).
class CaptureDurationSelector extends StatelessWidget {
  const CaptureDurationSelector({
    super.key,
    required this.cap,
    required this.enabled,
    required this.onCapSelected,
  });

  final Duration cap;
  final bool enabled;
  final ValueChanged<Duration> onCapSelected;

  static const _fifteenSeconds = Duration(seconds: 15);
  static const _thirtySeconds = Duration(seconds: 30);
  static const _sixtySeconds = Duration(seconds: 60);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeLabel(label: 'reels.capture_mode_video'.tr()),
        const SizedBox(width: 16),
        _DurationChip(
          label: 'reels.capture_duration_15s'.tr(),
          selected: cap == _fifteenSeconds,
          enabled: enabled,
          onTap: () => onCapSelected(_fifteenSeconds),
        ),
        const SizedBox(width: 12),
        _DurationChip(
          label: 'reels.capture_duration_30s'.tr(),
          selected: cap == _thirtySeconds,
          enabled: enabled,
          onTap: () => onCapSelected(_thirtySeconds),
        ),
        const SizedBox(width: 12),
        _DurationChip(
          label: 'reels.capture_duration_60s'.tr(),
          selected: cap == _sixtySeconds,
          enabled: enabled,
          onTap: () => onCapSelected(_sixtySeconds),
        ),
      ],
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: selected ? 16 : 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
        ),
      ),
    );
  }
}
