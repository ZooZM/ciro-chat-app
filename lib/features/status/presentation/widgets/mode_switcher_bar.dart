import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ModeSwitcherBar extends StatelessWidget {
  final StatusContentType activeMode;
  final ValueChanged<StatusContentType> onModeChanged;

  const ModeSwitcherBar({
    super.key,
    required this.activeMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXs, vertical: AppConstants.spacingXs / 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeItem(context, StatusContentType.video, 'status.video'.tr()),
          _buildModeItem(context, StatusContentType.image, 'status.image'.tr()),
          _buildModeItem(context, StatusContentType.text, 'status.text'.tr()),
          _buildModeItem(context, StatusContentType.voice, 'status.voice'.tr()),
        ],
      ),
    );
  }

  Widget _buildModeItem(BuildContext context, StatusContentType mode, String label) {
    final isSelected = activeMode == mode;
    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: AppConstants.spacingSm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
