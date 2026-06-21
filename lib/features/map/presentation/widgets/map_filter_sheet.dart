import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

enum StatusFilter { all, online, offline }

class MockGroup {
  final String name;
  final String members;
  final String initials;
  final Color color;
  MockGroup(this.name, this.members, this.initials, this.color);
}

class MapFilterSheet extends StatefulWidget {
  const MapFilterSheet({super.key});

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  final TextEditingController _searchController = TextEditingController();
  StatusFilter _selectedStatus = StatusFilter.all;
  String _selectedGroup = 'All';

  final List<MockGroup> mockGroupsList = [
    MockGroup('Tech Team', '8 members', 'TT', const Color(0xFF1E3A5F)),
    MockGroup('Design Squade', '8 members', 'DS', const Color(0xFFFFB74D)),
    MockGroup('Project', '8 members', 'P', const Color(0xFFD81B60)),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9), // Very light grey background for the sheet
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 16,
          right: 16,
          top: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter',
                  style: AppTypography.headline2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status Section
            _buildSectionCard(
              child: Column(
                children: [
                  _buildSectionHeader('Status', Icons.person_outline),
                  const SizedBox(height: 8),
                  _buildStatusItem('All Users', 'Show all users on the map', StatusFilter.all),
                  _buildStatusItem('Online Only', 'Show online users only', StatusFilter.online),
                  _buildStatusItem('Offline Only', 'Show offline users only', StatusFilter.offline, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Groups Section
            _buildSectionCard(
              child: Column(
                children: [
                  _buildSectionHeader('Groups', Icons.people_outline),
                  const SizedBox(height: 8),
                  _buildGroupItemRadio(
                    title: 'All Member',
                    subtitle: 'Show all Member on the map',
                    value: 'All',
                  ),
                  const SizedBox(height: 12),
                  // Search Bar inside Groups
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search groups',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Groups List
                  ...mockGroupsList.map((group) {
                    final isLast = mockGroupsList.last == group;
                    return _buildGroupAvatarItem(group, isLast);
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF555555),
          ),
        ),
        Icon(icon, color: Colors.grey.shade600, size: 22),
      ],
    );
  }

  Widget _buildStatusItem(String title, String subtitle, StatusFilter value, {bool isLast = false}) {
    final isSelected = _selectedStatus == value;
    return InkWell(
      onTap: () => setState(() => _selectedStatus = value),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body1.copyWith(fontWeight: FontWeight.w500, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption.copyWith(color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupItemRadio({required String title, required String subtitle, required String value}) {
    final isSelected = _selectedGroup == value;
    return InkWell(
      onTap: () => setState(() => _selectedGroup = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body1.copyWith(fontWeight: FontWeight.w500, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption.copyWith(color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatarItem(MockGroup group, bool isLast) {
    final isSelected = _selectedGroup == group.name;
    return InkWell(
      onTap: () => setState(() => _selectedGroup = group.name),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: group.color,
              child: Text(
                group.initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: AppTypography.body1.copyWith(fontWeight: FontWeight.w500, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(group.members, style: AppTypography.caption.copyWith(color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
