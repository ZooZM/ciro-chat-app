import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/url_utils.dart';
import '../data/mock_call_data.dart';

class ContactAvatar extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  final int colorSeed;
  final double radius;
  final double? fontSize;

  const ContactAvatar({
    super.key,
    required this.initials,
    this.avatarUrl,
    required this.colorSeed,
    this.radius = 24.0,
    this.fontSize,
  });

  Color get _avatarColor => kAvatarPalette[colorSeed.abs() % kAvatarPalette.length];

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _avatarColor,
      backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
          ? CachedNetworkImageProvider(UrlUtils.resolveMediaUrl(avatarUrl))
          : null,
      child: (avatarUrl == null || avatarUrl!.isEmpty)
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
              ),
            )
          : null,
    );
  }
}
