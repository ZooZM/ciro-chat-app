import 'package:flutter/material.dart';
import '../data/mock_profile_data.dart';

class AppearanceBackgroundList extends StatelessWidget {
  final String selectedBgId;
  final ValueChanged<String> onBgSelected;

  const AppearanceBackgroundList({
    super.key,
    required this.selectedBgId,
    required this.onBgSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: MockProfileData.mockBackgrounds.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final bg = MockProfileData.mockBackgrounds[index];
          final isSelected = bg.id == selectedBgId;

          return GestureDetector(
            onTap: () => onBgSelected(bg.id),
            child: Container(
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFF4CA440) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: bg.isCustomAdd
                    ? Container(
                        color: const Color(0xFFF5F5F5),
                        child: const Center(
                          child: Icon(
                            Icons.add,
                            color: Colors.black54,
                            size: 28,
                          ),
                        ),
                      )
                    : Image.asset(
                        bg.imagePath,
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
