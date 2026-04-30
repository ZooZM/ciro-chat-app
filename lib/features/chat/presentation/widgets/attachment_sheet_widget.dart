import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_session.dart';
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
  AttachmentOptionModel(
    label: 'Video',
    icon: Icons.videocam_outlined,
    iconColor: const Color(0xFFD32F2F),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SHEET WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class AttachmentSheetWidget extends StatelessWidget {
  final ChatRoomType roomType;

  const AttachmentSheetWidget({Key? key, this.roomType = ChatRoomType.PRIVATE})
    : super(key: key);

  // ── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _handleGallery(BuildContext context) async {
    Navigator.pop(context);
    await context.read<ChatCubit>().sendImageMessage(context);
  }

  Future<void> _handleVideo(BuildContext context) async {
    Navigator.pop(context);
    await context.read<ChatCubit>().sendVideoMessage(context);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Contacts permission denied')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load contacts: $e')));
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
                subtitle: Text(c.phones.first.number),
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

    if (!context.mounted) return;
    final result = await LocationService.getCurrentLocation(context);

    if (result.isSuccess && context.mounted) {
      await context.read<ChatCubit>().sendLocationMessage(
        result.latitude!,
        result.longitude!,
        result.address!,
      );
    } else if (!result.isSuccess && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Location unavailable')),
      );
    }
  }

  Future<void> _handleAudio(BuildContext context) async {
    Navigator.pop(context);
    await context.read<ChatCubit>().sendAudioMessage(context);
  }

  Future<void> _handlePoll(BuildContext context) async {
    Navigator.pop(context);

    final questionController = TextEditingController();
    final optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    bool allowMultiple = false;

    // Dark themed constants
    const darkBg = Color(0xFF111111);
    const darkCard = Color(0xFF1E1E1E);

    await showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) {
          return Dialog.fullscreen(
            child: Scaffold(
              backgroundColor: darkBg,
              appBar: AppBar(
                backgroundColor: darkBg,
                elevation: 0,
                leading: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                leadingWidth: 80,
                title: const Text(
                  'Create poll',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                centerTitle: true,
                actions: [
                  TextButton(
                    onPressed: () {
                      final question = questionController.text.trim();
                      final opts = optionControllers
                          .map((c) => c.text.trim())
                          .where((t) => t.isNotEmpty)
                          .toList();
                      if (question.isNotEmpty && opts.length >= 2) {
                        Navigator.pop(ctx);
                        ctx2.read<ChatCubit>().sendPollMessage(
                          question,
                          opts,
                        );
                      }
                    },
                    child: Text(
                      'Send',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // QUESTION section
                    Text(
                      'QUESTION',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: questionController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Ask a question…',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // OPTIONS section
                    Text(
                      'OPTIONS',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          ...optionControllers.asMap().entries.map((entry) {
                            final i = entry.key;
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: entry.value,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: i < 2
                                              ? 'Option ${i + 1}'
                                              : 'Add',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Icon(
                                        Icons.drag_handle,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                if (i < optionControllers.length - 1)
                                  Divider(
                                    height: 1,
                                    indent: 14,
                                    color: Colors.grey[800],
                                  ),
                              ],
                            );
                          }),
                          // "Add" placeholder row
                          Divider(
                            height: 1,
                            indent: 14,
                            color: Colors.grey[800],
                          ),
                          InkWell(
                            onTap: () => setState(
                              () => optionControllers.add(
                                TextEditingController(),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Add',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Allow multiple answers toggle
                    Container(
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Allow multiple answers',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        value: allowMultiple,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => allowMultiple = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleEvent(BuildContext context) async {
    final c = context;
    Navigator.pop(c);

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locationController = TextEditingController();
    DateTime startDate = DateTime.now().add(const Duration(hours: 1));
    DateTime endDate = DateTime.now().add(const Duration(hours: 3));
    bool includeEndTime = true;
    bool allowGuests = false;
    bool callLink = false;
    String reminder = '1 hour before';

    const darkBg = Color(0xFF111111);
    const darkCard = Color(0xFF1E1E1E);
    final reminderOptions = [
      'At time of event',
      '5 minutes before',
      '15 minutes before',
      '30 minutes before',
      '1 hour before',
      '1 day before',
    ];

    String _fmtDate(DateTime d) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    }

    String _fmtTime(DateTime d) {
      final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
      final m = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour < 12 ? 'AM' : 'PM';
      return '$h:$m $ampm';
    }

    await showDialog(
      context: c,
      useSafeArea: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) {
          Future<void> pickDateTime(bool isStart) async {
            final date = await showDatePicker(
              context: ctx,
              initialDate: isStart ? startDate : endDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark(),
                child: child!,
              ),
            );
            if (date == null || !ctx.mounted) return;
            final time = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay.fromDateTime(
                isStart ? startDate : endDate,
              ),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark(),
                child: child!,
              ),
            );
            if (time == null) return;
            final merged = DateTime(
              date.year, date.month, date.day,
              time.hour, time.minute,
            );
            setState(() {
              if (isStart) {
                startDate = merged;
                if (endDate.isBefore(startDate)) {
                  endDate = startDate.add(const Duration(hours: 2));
                }
              } else {
                endDate = merged;
              }
            });
          }

          Widget _dateTimeChip(String label) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          );

          return Dialog.fullscreen(
            child: Scaffold(
              backgroundColor: darkBg,
              appBar: AppBar(
                backgroundColor: darkBg,
                elevation: 0,
                leading: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                leadingWidth: 80,
                title: const Text(
                  'Create event',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                centerTitle: true,
                actions: [
                  TextButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isNotEmpty) {
                        Navigator.pop(ctx);
                        ctx2.read<ChatCubit>().sendEventMessage(
                          title,
                          startDate,
                          descController.text.trim(),
                        );
                      }
                    },
                    child: const Text(
                      'Send',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + description card
                    Container(
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: titleController,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Add event name',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12,
                              ),
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey[800]),
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              TextField(
                                controller: descController,
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 14,
                                ),
                                maxLines: 4,
                                maxLength: 2048,
                                decoration: InputDecoration(
                                  hintText: 'Add description (optional)',
                                  hintStyle: TextStyle(color: Colors.grey[600]),
                                  border: InputBorder.none,
                                  counterStyle: TextStyle(
                                    color: Colors.grey[600], fontSize: 11,
                                  ),
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    14, 12, 14, 28,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Starts / Ends / Include end time card
                    Container(
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          // Starts row
                          InkWell(
                            onTap: () => pickDateTime(true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Starts',
                                    style: TextStyle(
                                      color: Colors.white, fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  _dateTimeChip(_fmtDate(startDate)),
                                  const SizedBox(width: 8),
                                  _dateTimeChip(_fmtTime(startDate)),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 1, indent: 14, color: Colors.grey[800]),
                          // Ends row
                          if (includeEndTime)
                            Column(
                              children: [
                                InkWell(
                                  onTap: () => pickDateTime(false),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Ends',
                                          style: TextStyle(
                                            color: Colors.white, fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        _dateTimeChip(_fmtDate(endDate)),
                                        const SizedBox(width: 8),
                                        _dateTimeChip(_fmtTime(endDate)),
                                      ],
                                    ),
                                  ),
                                ),
                                Divider(height: 1, indent: 14, color: Colors.grey[800]),
                              ],
                            ),
                          // Include end time toggle
                          SwitchListTile(
                            title: const Text(
                              'Include end time',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            value: includeEndTime,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => includeEndTime = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location + Call link card
                    Container(
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: locationController,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Add location (optional)',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12,
                              ),
                            ),
                          ),
                          Divider(height: 1, indent: 14, color: Colors.grey[800]),
                          SwitchListTile(
                            title: const Text(
                              'Voice call link',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            value: callLink,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => callLink = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reminder card
                    Container(
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text(
                              'Reminder',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            trailing: DropdownButton<String>(
                              value: reminder,
                              dropdownColor: const Color(0xFF2A2A2A),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              underline: const SizedBox(),
                              icon: const Icon(
                                Icons.unfold_more,
                                color: Colors.grey,
                                size: 18,
                              ),
                              items: reminderOptions
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => reminder = v);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16, right: 16, bottom: 10,
                            ),
                            child: Text(
                              'Guests also get notified at the time of the event.',
                              style: TextStyle(
                                color: Colors.grey[600], fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Allow guests card
                    Container(
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Allow guests',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            value: allowGuests,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => allowGuests = v),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16, right: 16, bottom: 10,
                            ),
                            child: Text(
                              'Allow people to bring one additional guest.',
                              style: TextStyle(
                                color: Colors.grey[600], fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(left: 16.resW, right: 16.resW, bottom: 16.resH),
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
              .where((opt) {
                // FR-008: Poll is only available in Group Chat rooms.
                if (opt.label == 'Poll' && roomType == ChatRoomType.PRIVATE) {
                  return false;
                }
                return true;
              })
              .map(
                (opt) => _AttachmentItem(
                  option: opt,
                  onTap: (context) => _routeTap(opt.label, context),
                ),
              )
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
      case 'Video':
        _handleVideo(context);
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
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
            ),
            child: Center(
              child: Icon(option.icon, color: option.iconColor, size: 26.resW),
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
