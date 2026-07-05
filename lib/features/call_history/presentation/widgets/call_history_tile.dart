import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/url_utils.dart';
import '../../domain/entities/call_history_record.dart';
import 'contact_avatar.dart';

/// One row of the Calls history list (FR-VoIP-04): leading avatar, contact
/// name + direction/time subtitle (red when missed), trailing call-type icon.
class CallHistoryTile extends StatelessWidget {
  final CallHistoryRecord record;
  final VoidCallback onTap;

  const CallHistoryTile({super.key, required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final missed = record.isMissed;
    final isOutgoing = record.direction == CallDirection.outgoing;
    
    // User request: name should be red ONLY if the other person called (incoming)
    final nameColor = (missed && !isOutgoing) ? Colors.red : Colors.black;
    // Similarly for the arrow to match the name
    final arrowColor = (missed && !isOutgoing) ? Colors.red : const Color(0xFF4CAF50);
    final arrowIcon = isOutgoing ? Icons.call_made : Icons.call_received;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ContactAvatar(
        initials: record.initials,
        avatarUrl: record.avatarUrl,
        colorSeed: record.avatarColorSeed,
        radius: 26,
      ),
      title: Text(
        record.contactName,
        style: TextStyle(color: nameColor, fontWeight: FontWeight.w500, fontSize: 16),
      ),
      subtitle: Row(
        children: [
          Icon(arrowIcon, color: arrowColor, size: 16),
          const SizedBox(width: 4),
          Text(_relativeTime(record.startedAt, context), style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
      trailing: Icon(
        record.callType == CallType.video ? Icons.videocam_outlined : Icons.call_outlined,
        color: Colors.grey[700],
        size: 26,
      ),
      onTap: onTap,
    );
  }

  static String _relativeTime(int epochMs, BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final now = DateTime.now();
    final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    
    final isArabic = context.locale.languageCode == 'ar';
    final ampm = dt.hour >= 12 
        ? (isArabic ? 'م' : 'PM') 
        : (isArabic ? 'ص' : 'AM');
    final time = '$hh:$mm $ampm';

    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return '${'calls_today'.tr()} $time';

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    if (isYesterday) return '${'calls_yesterday'.tr()} $time';

    return '${dt.month}/${dt.day}/${dt.year} $time';
  }
}
