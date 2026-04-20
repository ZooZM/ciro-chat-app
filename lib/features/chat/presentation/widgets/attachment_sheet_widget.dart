import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class AttachmentOptionModel {
  final String label;
  final IconData icon;
  final Color iconColor;

  AttachmentOptionModel({
    required this.label,
    required this.icon,
    required this.iconColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTIONS  —  11 items arranged in a 4-column grid
// ─────────────────────────────────────────────────────────────────────────────

final List<AttachmentOptionModel> _attachmentOptions = [
  // Row 1
  AttachmentOptionModel(
    label: 'Gallery',
    icon: Icons.image_outlined,
    iconColor: const Color(0xFF2B7FE8),
  ),
  AttachmentOptionModel(
    label: 'Camera',
    icon: Icons.camera_alt_outlined,
    iconColor: const Color(0xFF757575),
  ),
  AttachmentOptionModel(
    label: 'Location',
    icon: Icons.location_on_outlined,
    iconColor: const Color(0xFF00E676),
  ),
  AttachmentOptionModel(
    label: 'Contact',
    icon: Icons.person_outline,
    iconColor: const Color(0xFF757575),
  ),
  // Row 2
  AttachmentOptionModel(
    label: 'Document',
    icon: Icons.insert_drive_file_outlined,
    iconColor: const Color(0xFF8E24AA),
  ),
  AttachmentOptionModel(
    label: 'Audio',
    icon: Icons.headphones_outlined,
    iconColor: const Color(0xFFF9A825),
  ),
  AttachmentOptionModel(
    label: 'Poll',
    icon: Icons.view_headline_outlined,
    iconColor: const Color(0xFFFBC02D),
  ),
  AttachmentOptionModel(
    label: 'Event',
    icon: Icons.calendar_today_outlined,
    iconColor: const Color(0xFFE53935),
  ),
  // Row 3
  AttachmentOptionModel(
    label: 'Invoice',
    icon: Icons.receipt_long_outlined,
    iconColor: const Color(0xFF8D6E63),
  ),
  AttachmentOptionModel(
    label: 'Chip in',
    icon: Icons.monetization_on_outlined,
    iconColor: const Color(0xFFFFB300),
  ),
  AttachmentOptionModel(
    label: 'Ai images',
    icon: Icons.auto_awesome_outlined,
    iconColor: const Color(0xFF2B7FE8),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class AttachmentSheetWidget extends StatelessWidget {
  const AttachmentSheetWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(
          left: 16.resW,
          right: 16.resW,
          bottom: 16.resH, // Floats nicely above the text input
        ),
        padding: EdgeInsets.only(
          top: 32.resH,
          left: 12.resW,
          right: 12.resW,
          bottom: 24.resH,
        ),
        decoration: BoxDecoration(
          color: Colors.white, // Pure white background
          borderRadius: BorderRadius.circular(24.resR), // Rounded all corners
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 24.resH,
          crossAxisSpacing: 0,
          childAspectRatio: 0.8,
          children: _attachmentOptions
              .map((opt) => _AttachmentItem(option: opt))
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE ITEM
// ─────────────────────────────────────────────────────────────────────────────

class _AttachmentItem extends StatelessWidget {
  final AttachmentOptionModel option;
  const _AttachmentItem({required this.option});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: wire up actual attachment feature
        debugPrint('${option.label} tapped');
        Navigator.pop(context); // Close the sheet on tap
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── White circle with light gray border + icon ──────────────────
          Container(
            width: 52.resW,
            height: 52.resW,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey[300]!, // Thin light gray border
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                option.icon,
                color: option.iconColor,
                size: 26.resW,
              ),
            ),
          ),
          SizedBox(height: 8.resH),
          // ── Label ──────────────────────────────────────────────────────
          Text(
            option.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
