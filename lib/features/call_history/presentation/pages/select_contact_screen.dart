import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/helpers/responsive.dart';
import '../../../../core/routing/app_router.dart';
import '../widgets/contact_avatar.dart';
import '../data/mock_call_data.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final List<MockContact> _selectedContacts = [];

  void _toggleSelection(MockContact contact) {
    setState(() {
      if (_selectedContacts.any((c) => c.id == contact.id)) {
        _selectedContacts.removeWhere((c) => c.id == contact.id);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  void _removeSelection(String id) {
    setState(() {
      _selectedContacts.removeWhere((c) => c.id == id);
    });
  }

  Widget _buildContactTile(MockContact contact) {
    final isSelected = _selectedContacts.any((c) => c.id == contact.id);

    return ListTile(
      leading: ContactAvatar(
        initials: contact.initials,
        avatarUrl: contact.avatarUrl,
        colorSeed: contact.avatarColorSeed,
        radius: 24.resR,
        fontSize: 18.resSp,
      ),
      title: Text(
        contact.name,
        style: AppTypography.subtitle2.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected ? AppColors.primary : Colors.grey[400],
        size: 24.resW,
      ),
      onTap: () => _toggleSelection(contact),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.resW, 24.resH, 16.resW, 8.resH),
      child: Text(
        title,
        style: AppTypography.subtitle2.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 14.resSp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'calls_select_title'.tr(),
              style: AppTypography.headline3.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'calls_select_count'.tr(args: ['261']),
              style: AppTypography.caption,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_selectedContacts.isNotEmpty)
              Column(
                children: [
                  Container(
                    height: 100.resH,
                    padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 12.resH),
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedContacts.length,
                            itemBuilder: (context, index) {
                              final contact = _selectedContacts[index];
                              return Padding(
                                padding: EdgeInsets.only(right: 16.resW),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ContactAvatar(
                                          initials: contact.initials,
                                          avatarUrl: contact.avatarUrl,
                                          colorSeed: contact.avatarColorSeed,
                                          radius: 22.resR,
                                          fontSize: 16.resSp,
                                        ),
                                        Positioned(
                                          right: -4,
                                          bottom: -4,
                                          child: GestureDetector(
                                            onTap: () => _removeSelection(contact.id),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[700],
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                              padding: EdgeInsets.all(2.resW),
                                              child: Icon(Icons.close, size: 10.resW, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 6.resH),
                                    SizedBox(
                                      width: 48.resW,
                                      child: Text(
                                        contact.name,
                                        style: AppTypography.caption.copyWith(color: Colors.grey[500], fontSize: 11.resSp),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 8.resW),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.call_outlined),
                              onPressed: () {},
                              color: Colors.grey[700],
                            ),
                            IconButton(
                              icon: const Icon(Icons.videocam_outlined),
                              onPressed: () {},
                              color: Colors.grey[700],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[100]),
                ],
              ),
            Expanded(
              child: ListView(
                children: [
                  if (_selectedContacts.isEmpty) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 24.resR,
                        child: const Icon(Icons.person_add, color: Colors.white),
                      ),
                      title: Text(
                        'calls_select_new_contact'.tr(),
                        style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => context.push(AppRouterName.newContact),
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 24.resR,
                        child: const Icon(Icons.dialpad, color: Colors.white),
                      ),
                      title: Text(
                        'calls_select_call_number'.tr(),
                        style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => context.push(AppRouterName.dialpad),
                    ),
                  ],
                  _buildSectionHeader('calls_select_frequently'.tr()),
                  ...mockFrequentContacts.map(_buildContactTile),
                  _buildSectionHeader('calls_select_contacts'.tr()),
                  ...mockAllContacts.map(_buildContactTile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
