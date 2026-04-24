import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import '../widgets/group_participant_tile.dart';

class GroupInfoPage extends StatefulWidget {
  final ChatSession chatData;

  const GroupInfoPage({
    Key? key,
    required this.chatData,
  }) : super(key: key);

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = context.read<ChatCubit>().currentUserId;
  }

  bool get _isAdmin => widget.chatData.admins.contains(_currentUserId);

  void _showAddParticipants() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _AddParticipantsSheet(
          roomId: widget.chatData.id,
          existingParticipants: widget.chatData.participants,
        );
      },
    );
  }

  void _removeParticipant(String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: Text('Are you sure you want to remove $phoneNumber from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatCubit>().removeParticipant(widget.chatData.id, phoneNumber);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatCubit>().leaveGroup(widget.chatData.id);
              context.go('/home');
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Group Info', style: AppTypography.headline3.copyWith(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20.resH),
            CircleAvatar(
              radius: 50.resR,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: widget.chatData.avatarUrl.isNotEmpty 
                  ? NetworkImage(widget.chatData.avatarUrl) 
                  : null,
              child: widget.chatData.avatarUrl.isEmpty
                  ? Icon(Icons.group, size: 50.resR, color: AppColors.primary)
                  : null,
            ),
            SizedBox(height: 16.resH),
            Text(
              widget.chatData.name,
              style: AppTypography.headline2.copyWith(color: Colors.black),
            ),
            Text(
              '${widget.chatData.participants.length} participants',
              style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: 24.resH),
            
            // Actions Section
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.person_add_outlined, color: AppColors.primary),
                title: const Text('Add Participants'),
                onTap: _showAddParticipants,
              ),
            
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Leave Group', style: TextStyle(color: Colors.red)),
              onTap: _leaveGroup,
            ),

            const Divider(),
            
            // Participants List
            Padding(
              padding: EdgeInsets.all(16.resW),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Participants',
                  style: AppTypography.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.chatData.participants.length,
              itemBuilder: (context, index) {
                final phone = widget.chatData.participants[index];
                return GroupParticipantTile(
                  phoneNumber: phone,
                  isAdmin: widget.chatData.admins.contains(phone),
                  isMe: phone == _currentUserId,
                  showRemoveAction: _isAdmin,
                  onRemove: () => _removeParticipant(phone),
                );
              },
            ),
            SizedBox(height: 40.resH),
          ],
        ),
      ),
    );
  }
}

class _AddParticipantsSheet extends StatefulWidget {
  final String roomId;
  final List<String> existingParticipants;

  const _AddParticipantsSheet({
    required this.roomId,
    required this.existingParticipants,
  });

  @override
  State<_AddParticipantsSheet> createState() => _AddParticipantsSheetState();
}

class _AddParticipantsSheetState extends State<_AddParticipantsSheet> {
  final Set<String> _selectedPhones = {};
  bool _isSubmitting = false;

  void _toggleSelection(String phone) {
    setState(() {
      if (_selectedPhones.contains(phone)) {
        _selectedPhones.remove(phone);
      } else {
        _selectedPhones.add(phone);
      }
    });
  }

  void _submit() async {
    if (_selectedPhones.isEmpty) return;
    setState(() => _isSubmitting = true);
    await context.read<ChatCubit>().addParticipants(widget.roomId, _selectedPhones.toList());
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.resW),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Participants', style: AppTypography.headline3),
                if (_isSubmitting)
                  const CircularProgressIndicator()
                else
                  TextButton(
                    onPressed: _selectedPhones.isEmpty ? null : _submit,
                    child: const Text('Add'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatSession>>(
              stream: context.read<ChatCubit>().watchLocalContacts,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final contacts = snapshot.data!
                    .where((c) => !widget.existingParticipants.contains(c.phoneNumber))
                    .toList();
                
                if (contacts.isEmpty) {
                  return const Center(child: Text('No new contacts to add'));
                }

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final isSelected = _selectedPhones.contains(contact.phoneNumber);
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(contact.name.isNotEmpty ? contact.name[0] : '?'),
                      ),
                      title: Text(contact.name),
                      subtitle: Text(contact.phoneNumber),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(contact.phoneNumber),
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
