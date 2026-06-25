import 'package:cached_network_image/cached_network_image.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/map/domain/entities/map_user.dart';
import 'package:ciro_chat_app/features/map/presentation/utils/map_color_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MapAvatarMarker extends StatelessWidget {
  const MapAvatarMarker({super.key, required this.user, this.onTap});

  final MapUser user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = user.isOnline
        ? AppColors.primary
        : const Color(0xFF9E9E9E);
    final resolvedAvatarUrl = UrlUtils.resolveMediaUrl(user.avatarUrl);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: MapColorUtils.forId(user.id),
                  backgroundImage: resolvedAvatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(resolvedAvatarUrl)
                      : null,
                  child: resolvedAvatarUrl.isEmpty
                      ? Text(
                          user.initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
              if (user.isOnline)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 80),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              user.isCurrentUser ? 'map_you'.tr() : user.name,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
