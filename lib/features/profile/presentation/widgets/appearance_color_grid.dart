import 'package:flutter/material.dart';
import '../data/mock_profile_data.dart';

class AppearanceColorGrid extends StatelessWidget {
  final String selectedColorId;
  final ValueChanged<String> onColorSelected;

  const AppearanceColorGrid({
    super.key,
    required this.selectedColorId,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: MockProfileData.mockColors.map((colorOption) {
          final isSelected = colorOption.id == selectedColorId;
          return GestureDetector(
            onTap: () => onColorSelected(colorOption.id),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorOption.color,
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
