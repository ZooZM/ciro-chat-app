import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';

class ProfileVerificationStepper extends StatelessWidget {
  final int currentStep;
  final List<String> stepLabels;

  const ProfileVerificationStepper({
    super.key,
    required this.currentStep,
    required this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.resH),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(stepLabels.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(top: 14.resH), // Align with center of the circle (which is 28x28)
                height: 2.resH,
                color: isCompleted ? AppColors.primary : AppColors.border,
              ),
            );
          } else {
            // Node
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            final isActive = stepIndex == currentStep;

            return SizedBox(
              width: 60.resW, // Fixed width to accommodate text wrapping if needed, but keeping it tight
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28.resW,
                    height: 28.resW,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted || isActive ? AppColors.primary : AppColors.surface,
                      border: Border.all(
                        color: isCompleted || isActive ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isCompleted
                        ? Icon(Icons.check, size: 16.resW, color: Colors.white)
                        : Text(
                            '${stepIndex + 1}',
                            style: AppTypography.body2.copyWith(
                              color: isCompleted || isActive ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  SizedBox(height: 8.resH),
                  Text(
                    stepLabels[stepIndex],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: AppTypography.caption.copyWith(
                      color: isActive
                          ? AppColors.primary
                          : (isCompleted ? AppColors.textPrimary : AppColors.textSecondary),
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 11.resSp,
                    ),
                  ),
                ],
              ),
            );
          }
        }),
      ),
    );
  }
}
