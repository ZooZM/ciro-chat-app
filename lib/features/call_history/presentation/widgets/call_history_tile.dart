import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/url_utils.dart';
import '../../domain/entities/call_history_record.dart';

/// One row of the Calls history list (FR-VoIP-04): leading avatar, contact
/// name + direction/time subtitle (red when missed), trailing call-type icon.
class CallHistoryTile extends StatelessWidget {
  final CallHistoryRecord record;
  final VoidCallback onTap;

  const CallHistoryTile({super.key, required this.record, required this.onTap});

  static const _avatarPalette = [
    Color(0xFF8E6FB1),
    Color(0xFF4F8A6E),
    Color(0xFFB14F6F),
    Color(0xFF6F8AB1),
    Color(0xFFB1956F),
    Color(0xFF6FB18E),
  ];

  Color get _avatarColor => _avatarPalette[record.avatarColorSeed.abs() % _avatarPalette.length];

  @override
  Widget build(BuildContext context) {
    final missed = record.isMissed;
    final nameColor = missed ? Colors.red : Colors.black;
    final arrow = record.direction == CallDirection.outgoing ? '↗' : '↙';

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: _avatarColor,
        backgroundImage: record.avatarUrl != null && record.avatarUrl!.isNotEmpty
            ? CachedNetworkImageProvider(UrlUtils.resolveMediaUrl(record.avatarUrl))
            : null,
        child: (record.avatarUrl == null || record.avatarUrl!.isEmpty)
            ? Text(record.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
            : null,
      ),
      title: Text(
        record.contactName,
        style: TextStyle(color: nameColor, fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Row(
        children: [
          Text(arrow, style: TextStyle(color: missed ? Colors.red : Colors.green)),
          const SizedBox(width: 4),
          Text(_relativeTime(record.startedAt), style: const TextStyle(color: Colors.grey)),
        ],
      ),
      trailing: Icon(
        record.callType == CallType.video ? Icons.videocam_outlined : Icons.call_outlined,
        color: Colors.grey[700],
      ),
      onTap: onTap,
    );
  }

  static String _relativeTime(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final now = DateTime.now();
    final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$hh:$mm $ampm';

    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return 'Today $time';

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    if (isYesterday) return 'Yesterday $time';

    return '${dt.month}/${dt.day}/${dt.year} $time';
  }
}
