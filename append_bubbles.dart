// ─────────────────────────────────────────────────────────────────────────────
// Location bubble
// ─────────────────────────────────────────────────────────────────────────────

class _LocationBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _LocationBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final address = meta['address'] as String? ?? 'Shared Location';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            height: 150.resH,
            width: 250.resW,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12.resR),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, color: AppColors.primary, size: 32.resW),
                  SizedBox(height: 8.resH),
                  Text(
                    address,
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio bubble
// ─────────────────────────────────────────────────────────────────────────────

class _AudioBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _AudioBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final fileName = meta['fileName'] as String? ?? 'Audio file';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: isMine ? Colors.white24 : AppColors.primary.withOpacity(0.1),
                child: Icon(
                  Icons.headphones,
                  color: isMine ? Colors.white : AppColors.primary,
                ),
              ),
              SizedBox(width: 12.resW),
              Flexible(
                child: Text(
                  fileName,
                  style: AppTypography.body2.copyWith(
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Poll bubble
// ─────────────────────────────────────────────────────────────────────────────

class _PollBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _PollBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final question = meta['question'] as String? ?? 'Poll';
    final options = (meta['options'] as List<dynamic>?)?.cast<String>() ?? [];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            '📊 $question',
            style: AppTypography.body1.copyWith(
              fontWeight: FontWeight.bold,
              color: isMine ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.resH),
          ...options.map((opt) => Padding(
                padding: EdgeInsets.only(bottom: 4.resH),
                child: Container(
                  width: 200.resW,
                  padding: EdgeInsets.symmetric(vertical: 6.resH, horizontal: 12.resW),
                  decoration: BoxDecoration(
                    color: isMine ? Colors.white24 : AppColors.divider,
                    borderRadius: BorderRadius.circular(8.resR),
                  ),
                  child: Text(
                    opt,
                    style: AppTypography.caption.copyWith(
                      color: isMine ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              )),
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event bubble
// ─────────────────────────────────────────────────────────────────────────────

class _EventBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _EventBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final title = meta['title'] as String? ?? 'Event';
    final dateStr = meta['dateTime'] as String?;
    final desc = meta['description'] as String? ?? '';
    
    DateTime? date;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                color: isMine ? Colors.white : AppColors.primary,
                size: 20.resW,
              ),
              SizedBox(width: 8.resW),
              Flexible(
                child: Text(
                  title,
                  style: AppTypography.body1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (date != null) ...[
            SizedBox(height: 4.resH),
            Text(
              DateFormat('MMM d, yyyy • h:mm a').format(date),
              style: AppTypography.caption.copyWith(
                color: isMine ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
          if (desc.isNotEmpty) ...[
            SizedBox(height: 4.resH),
            Text(
              desc,
              style: AppTypography.caption.copyWith(
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
    );
  }
}
