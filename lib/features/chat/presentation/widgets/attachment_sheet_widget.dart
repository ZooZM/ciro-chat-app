import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../bloc/chat_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class AttachmentOptionModel {
  final String label;
  final IconData icon;
  final Color iconColor;

  AttachmentOptionModel({
    required this.label,
    required this.icon,
    required this.iconColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTIONS  —  11 items arranged in a 4-column grid
// ─────────────────────────────────────────────────────────────────────────────

final List<AttachmentOptionModel> _attachmentOptions = [
  // Row 1
  AttachmentOptionModel(
    label: 'Gallery',
    icon: Icons.image_outlined,
    iconColor: const Color(0xFF2B7FE8),
  ),
  AttachmentOptionModel(
    label: 'Camera',
    icon: Icons.camera_alt_outlined,
    iconColor: const Color(0xFF757575),
  ),
  AttachmentOptionModel(
    label: 'Location',
    icon: Icons.location_on_outlined,
    iconColor: const Color(0xFF00E676),
  ),
  AttachmentOptionModel(
    label: 'Contact',
    icon: Icons.person_outline,
    iconColor: const Color(0xFF757575),
  ),
  // Row 2
  AttachmentOptionModel(
    label: 'Document',
    icon: Icons.insert_drive_file_outlined,
    iconColor: const Color(0xFF8E24AA),
  ),
  AttachmentOptionModel(
    label: 'Audio',
    icon: Icons.headphones_outlined,
    iconColor: const Color(0xFFF9A825),
  ),
  AttachmentOptionModel(
    label: 'Poll',
    icon: Icons.view_headline_outlined,
    iconColor: const Color(0xFFFBC02D),
  ),
  AttachmentOptionModel(
    label: 'Event',
    icon: Icons.calendar_today_outlined,
    iconColor: const Color(0xFFE53935),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SHEET WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class AttachmentSheetWidget extends StatelessWidget {
  const AttachmentSheetWidget({Key? key}) : super(key: key);

  // ── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _handleGallery(BuildContext context) async {
    Navigator.pop(context);
    await context.read<ChatCubit>().sendImageMessage(context);
  }

  Future<void> _handleDocument(BuildContext context) async {
    Navigator.pop(context);
    await context.read<ChatCubit>().sendFileMessage(context);
  }

  Future<void> _handleContact(BuildContext context) async {
    Navigator.pop(context);

    // Request contacts permission first.
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
      }
      return;
    }

    // Fetch all contacts with phone numbers.
    List<Contact> contacts;
    try {
      contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone, ContactProperty.name},
      );
      contacts = contacts.where((c) => c.phones.isNotEmpty).toList();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load contacts: $e')),
        );
      }
      return;
    }

    if (contacts.isEmpty || !context.mounted) return;

    // Show a simple list picker dialog.
    final Contact? picked = await showDialog<Contact>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick a contact'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: contacts.length,
            itemBuilder: (_, i) {
              final c = contacts[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(c.displayName ?? ''),
                subtitle: Text(c.phones.first.number ?? ''),
                onTap: () => Navigator.pop(ctx, c),
              );
            },
          ),
        ),
      ),
    );

    if (picked == null || !context.mounted) return;
    await context.read<ChatCubit>().sendContactMessage(picked);
  }

  Future<void> _handleCamera(BuildContext context) async {
    Navigator.pop(context);
    await context.read<ChatCubit>().sendCameraMessage(context);
  }

  Future<void> _handleLocation(BuildContext context) async {
    Navigator.pop(context);

    final status = await Permission.location.request();
    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      String address = "Unknown Location";
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = "${p.street}, ${p.locality}, ${p.country}";
      }

      if (context.mounted) {
        await context.read<ChatCubit>().sendLocationMessage(
              position.latitude,
              position.longitude,
              address,
            );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  Future<void> _handleAudio(BuildContext context) async {
    Navigator.pop(context);
    await context.read<ChatCubit>().sendAudioMessage(context);
  }

  Future<void> _handlePoll(BuildContext context) async {
    Navigator.pop(context);

    final questionController = TextEditingController();
    final optionControllers = [TextEditingController(), TextEditingController()];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Create Poll'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  decoration: const InputDecoration(labelText: 'Question'),
                ),
                ...optionControllers.asMap().entries.map((entry) {
                  return TextField(
                    controller: entry.value,
                    decoration:
                        InputDecoration(labelText: 'Option ${entry.key + 1}'),
                  );
                }),
                TextButton(
                  onPressed: () =>
                      setState(() => optionControllers.add(TextEditingController())),
                  child: const Text('Add Option'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final question = questionController.text.trim();
                final options = optionControllers
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();
                if (question.isNotEmpty && options.length >= 2) {
                  Navigator.pop(ctx);
                  context.read<ChatCubit>().sendPollMessage(question, options);
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _handleEvent(BuildContext context) async {
    Navigator.pop(context);

    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Event Title'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Select Date'),
              subtitle: Text(selectedDate.toString()),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  selectedDate = date;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(ctx);
                context.read<ChatCubit>().sendEventMessage(
                    title, selectedDate, descController.text.trim());
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(
          left: 16.resW,
          right: 16.resW,
          bottom: 16.resH,
        ),
        padding: EdgeInsets.only(
          top: 32.resH,
          left: 12.resW,
          right: 12.resW,
          bottom: 24.resH,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.resR),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 24.resH,
          crossAxisSpacing: 0,
          childAspectRatio: 0.8,
          children: _attachmentOptions
              .map((opt) => _AttachmentItem(
                    option: opt,
                    onTap: (context) => _routeTap(opt.label, context),
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _routeTap(String label, BuildContext context) {
    switch (label) {
      case 'Gallery':
        _handleGallery(context);
        break;
      case 'Camera':
        _handleCamera(context);
        break;
      case 'Document':
        _handleDocument(context);
        break;
      case 'Contact':
        _handleContact(context);
        break;
      case 'Location':
        _handleLocation(context);
        break;
      case 'Audio':
        _handleAudio(context);
        break;
      case 'Poll':
        _handlePoll(context);
        break;
      case 'Event':
        _handleEvent(context);
        break;
      default:
        // Not yet implemented options — close the sheet.
        Navigator.pop(context);
        debugPrint('[AttachmentSheet] $label tapped — not yet implemented');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE ITEM
// ─────────────────────────────────────────────────────────────────────────────

class _AttachmentItem extends StatelessWidget {
  final AttachmentOptionModel option;
  final void Function(BuildContext context) onTap;

  const _AttachmentItem({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icon circle ─────────────────────────────────────────────────────
          Container(
            width: 52.resW,
            height: 52.resW,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                option.icon,
                color: option.iconColor,
                size: 26.resW,
              ),
            ),
          ),
          SizedBox(height: 8.resH),
          // ── Label ───────────────────────────────────────────────────────────
          Text(
            option.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
── Label ───────────────────────────────────────────────────────────
          Text(
            option.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
