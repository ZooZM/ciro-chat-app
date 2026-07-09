import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';

class ChatSearchBar extends StatefulWidget {
  final VoidCallback onClose;
  final Function(Message) onResultTap;

  const ChatSearchBar({
    Key? key,
    required this.onClose,
    required this.onResultTap,
  }) : super(key: key);

  @override
  State<ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<ChatSearchBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<ChatCubit>().searchMessages(query);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ChatCubit>();

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Search Input
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16.resW,
              vertical: 8.resH,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                    size: 24.resW,
                  ),
                  onPressed: widget.onClose,
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search in chat...',
                      hintStyle: AppTypography.body1.copyWith(
                        color: AppColors.textHint,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: AppTypography.body1.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 20.resW,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: ValueListenableBuilder<List<Message>>(
              valueListenable: cubit.searchResults,
              builder: (context, results, child) {
                if (_searchController.text.isEmpty) {
                  return const SizedBox.shrink();
                }

                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages found',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final msg = results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 24.resW,
                        vertical: 4.resH,
                      ),
                      leading: Icon(
                        msg.type == MessageType.text
                            ? Icons.chat_bubble_outline
                            : Icons.attach_file,
                        color: AppColors.textSecondary,
                        size: 20.resW,
                      ),
                      title: Text(
                        msg.text.isNotEmpty ? msg.text : 'Media message',
                        style: AppTypography.body1.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _formatDate(msg.timestamp),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                      onTap: () {
                        widget.onResultTap(msg);
                      },
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
