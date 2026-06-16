import 'package:cached_network_image/cached_network_image.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:flutter/material.dart';

/// Circular preview of a status's most recent content: the background
/// color/text for text statuses, a scaled-down image for image/video
/// statuses, or a fallback icon when there is nothing to show yet.
class StatusAvatarPreview extends StatelessWidget {
  final StatusEntity? status;
  final double size;

  const StatusAvatarPreview({super.key, this.status, required this.size});

  Color _parseColor(String hexCode) {
    var hex = hexCode.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, color: Colors.white, size: size * 0.55),
      );
    }

    switch (s.contentType) {
      case StatusContentType.text:
        final bgColor = (s.backgroundColor?.isNotEmpty ?? false)
            ? _parseColor(s.backgroundColor!)
            : Colors.grey[700]!;
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: bgColor,
          child: (s.textContent?.isNotEmpty ?? false)
              ? Padding(
                  padding: EdgeInsets.all(size * 0.1),
                  child: FittedBox(
                    child: Text(
                      s.textContent!,
                      maxLines: 3,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontFamily: (s.fontStyle?.isNotEmpty ?? false)
                            ? s.fontStyle
                            : null,
                      ),
                    ),
                  ),
                )
              : null,
        );

      case StatusContentType.image:
        if (s.mediaUrl?.isNotEmpty ?? false) {
          return CircleAvatar(
            radius: size / 2,
            backgroundColor: Colors.grey[200],
            backgroundImage: CachedNetworkImageProvider(
              s.mediaUrl!,
              headers: UrlUtils.authHeaders,
            ),
          );
        }
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey[300],
          child: Icon(Icons.image, color: Colors.white, size: size * 0.45),
        );

      case StatusContentType.video:
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.black87,
          child: Icon(Icons.videocam, color: Colors.white, size: size * 0.45),
        );

      case StatusContentType.voice:
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.deepPurple,
          child: Icon(Icons.mic, color: Colors.white, size: size * 0.45),
        );
    }
  }
}
