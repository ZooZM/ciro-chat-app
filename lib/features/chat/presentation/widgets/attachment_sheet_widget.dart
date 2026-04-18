import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class AttachmentOptionModel {
  final String label;
  final IconData icon;
  final Color baseColor;

  AttachmentOptionModel({
    required this.label,
    required this.icon,
    required this.baseColor,
  });
}

final List<AttachmentOptionModel> _attachmentOptions = [
  AttachmentOptionModel(label: "Gallery", icon: Icons.image, baseColor: const Color(0xFF4A90E2)),
  AttachmentOptionModel(label: "Camera", icon: Icons.camera_alt, baseColor: const Color(0xFF757575)),
  AttachmentOptionModel(label: "Location", icon: Icons.location_on, baseColor: const Color(0xFF1ABC9C)),
  AttachmentOptionModel(label: "Contact", icon: Icons.person, baseColor: const Color(0xFF757575)),
  AttachmentOptionModel(label: "Document", icon: Icons.insert_drive_file, baseColor: const Color(0xFF9B59B6)),
  AttachmentOptionModel(label: "Audio", icon: Icons.headset, baseColor: const Color(0xFFF39C12)),
  AttachmentOptionModel(label: "Poll", icon: Icons.poll, baseColor: const Color(0xFFF1C40F)),
];

class AttachmentSheetWidget extends StatelessWidget {
  const AttachmentSheetWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 24.resH, left: 24.resW, right: 24.resW, bottom: 40.resH),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.resR)),
      ),
      child: Wrap(
        spacing: 24.resW,
        runSpacing: 24.resH,
        alignment: WrapAlignment.start,
        children: _attachmentOptions.map((attachment) {
          return GestureDetector(
            onTap: () {
              // Trigger actual attachment feature later
              print('${attachment.label} clicked');
            },
            child: SizedBox(
              width: 70.resW,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30.resR,
                  backgroundColor: AppColors.background, // Light gray
                  child: Icon(
                    attachment.icon,
                    color: attachment.baseColor,
                    size: 28.resW,
                  ),
                ),
                SizedBox(height: 8.resH),
                Text(
                  attachment.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                )
              ],
            ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
