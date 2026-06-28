import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:flutter/material.dart';

class ColorPalettePicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPalettePicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  static const List<Color> _curatedColors = [
    Color(0xFFE57373), Color(0xFFF06292), Color(0xFFBA68C8), Color(0xFF9575CD),
    Color(0xFF7986CB), Color(0xFF64B5F6), Color(0xFF4FC3F7), Color(0xFF4DD0E1),
    Color(0xFF4DB6AC), Color(0xFF81C784), Color(0xFFAED581),
    //  Color(0xDCE775),
    Color(0xFFFFF176), Color(0xFFFFD54F), Color(0xFFFFB74D), Color(0xFFFF8A65),
    Color(0xFFA1887F), Color(0xFF90A4AE), Color(0xFF333333), Color(0xFF555555),
    Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFF8D6E63), Color(0xFFB0BEC5),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: AppConstants.spacingXs,
        crossAxisSpacing: AppConstants.spacingXs,
      ),
      itemCount: _curatedColors.length,
      itemBuilder: (context, index) {
        final color = _curatedColors[index];
        final isSelected = color.value == selectedColor.value;

        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: AppConstants.statusColorSwatchSize,
            height: AppConstants.statusColorSwatchSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    size: 20,
                  )
                : null,
          ),
        );
      },
    );
  }
}
