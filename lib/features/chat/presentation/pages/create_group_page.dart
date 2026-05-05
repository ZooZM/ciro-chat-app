import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedContactIds = {};
  bool _isCreating = false;

  void _toggleSelection(String contactId) {
    debugPrint('Selected contact: $contactId');
    setState(() {
      if (_selectedContactIds.contains(contactId)) {
        _selectedContactIds.remove(contactId);
      } else {
        _selectedContactIds.add(contactId);
      }
    });
  }

  void _createGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    setState(() => _isCreating = true);
    debugPrint('Creating group: $groupName');
    debugPrint('Selected contacts: ${_selectedContactIds.toList()}');
    await context.read<ChatCubit>().createGroup(
      groupName,
      _selectedContactIds.toList(),
      avatarUrl: null,
    );

    if (mounted) {
      setState(() => _isCreating = false);
      // Wait for cubit state to settle before checking error
      final state = context.read<ChatCubit>().state;
      if (state is ChatError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        // Success. The Cubit emits ChatRoomActive but we just go back to home.
        context.go(AppRouterName.home);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'New Group',
          style: AppTypography.headline2.copyWith(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.resW),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: Text(
                'Create',
                style: AppTypography.subtitle1.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.resW),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Group Name',
                hintStyle: AppTypography.body1.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: const UnderlineInputBorder(),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              style: AppTypography.subtitle1,
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 16.resW,
              vertical: 8.resH,
            ),
            color: Colors.grey[100],
            child: Text(
              'SELECT CONTACTS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatSession>>(
              stream: context.read<ChatCubit>().watchLocalContacts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contacts = snapshot.data ?? [];

                if (contacts.isEmpty) {
                  return Center(
                    child: Text(
                      'No contacts found.',
                      style: AppTypography.body1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final isSelected = _selectedContactIds.contains(
                      contact.phoneNumber,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: contact.avatarUrl.isNotEmpty
                            ? NetworkImage(contact.avatarUrl)
                            : null,
                        child: contact.avatarUrl.isEmpty
                            ? Text(
                                contact.name.isNotEmpty
                                    ? contact.name[0].toUpperCase()
                                    : '?',
                                style: AppTypography.subtitle1.copyWith(
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      title: Text(contact.name, style: AppTypography.subtitle1),
                      subtitle: Text(
                        contact.phoneNumber,
                        style: AppTypography.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (val) =>
                            _toggleSelection(contact.phoneNumber),
                        activeColor: AppColors.primary,
                      ),
                      onTap: () => _toggleSelection(contact.phoneNumber),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
