import 'package:flutter/material.dart';
import '../data/mock_profile_data.dart';

class AppearanceThemeList extends StatelessWidget {
  final String selectedThemeId;
  final ValueChanged<String> onThemeSelected;

  const AppearanceThemeList({
    super.key,
    required this.selectedThemeId,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: MockProfileData.mockThemes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final theme = MockProfileData.mockThemes[index];
          final isSelected = theme.id == selectedThemeId;

          return GestureDetector(
            onTap: () => onThemeSelected(theme.id),
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFF4CA440) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  theme.thumbnailPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
