import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../video_call/presentation/bloc/call_cubit.dart';
import '../../domain/entities/call_history_record.dart';
import '../bloc/call_history_cubit.dart';
import '../widgets/call_history_tile.dart';

/// The in-app "Calls" tab (FR-VoIP-04): large title, search, "Recent" list,
/// and a new-call action — matches images_ui/call_history.png.
class CallsHistoryScreen extends StatelessWidget {
  const CallsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CallHistoryCubit>()..load(),
      child: const _CallsHistoryView(),
    );
  }
}

class _CallsHistoryView extends StatefulWidget {
  const _CallsHistoryView();

  @override
  State<_CallsHistoryView> createState() => _CallsHistoryViewState();
}

class _CallsHistoryViewState extends State<_CallsHistoryView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Tapping a row redials the contact using the record's call type (T038).
  /// Group-call rows have no single callee to redial — fall back to contacts.
  void _redial(BuildContext context, CallHistoryRecord record) {
    if (record.isGroup) {
      context.push(AppRouterName.contacts);
      return;
    }
    getIt<CallCubit>().initiateCall(
      targetUserId: record.contactUserId,
      targetName: record.contactName,
      targetAvatarUrl: record.avatarUrl ?? '',
      isVideo: record.callType == CallType.video,
    );
    context.push(
      AppRouterName.outgoingCall,
      extra: {'contactName': record.contactName, 'avatarUrl': record.avatarUrl ?? ''},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => context.push(AppRouterName.contacts),
        child: const Icon(Icons.call, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'calls_title'.tr(),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (q) => context.read<CallHistoryCubit>().search(q),
                decoration: InputDecoration(
                  hintText: 'calls_search_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'calls_recent'.tr(),
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: BlocBuilder<CallHistoryCubit, CallHistoryState>(
                builder: (context, state) {
                  switch (state) {
                    case CallHistoryLoading():
                      return const Center(child: CircularProgressIndicator());
                    case CallHistoryError(:final message):
                      return Center(child: Text(message));
                    case CallHistoryLoaded(:final records):
                      if (records.isEmpty) {
                        return Center(
                          child: Text('calls_empty'.tr(), style: const TextStyle(color: Colors.grey)),
                        );
                      }
                      return ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return CallHistoryTile(
                            record: record,
                            onTap: () => _redial(context, record),
                          );
                        },
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
