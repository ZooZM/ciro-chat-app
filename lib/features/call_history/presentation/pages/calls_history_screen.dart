import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  void _openCallInfo(BuildContext context, CallHistoryRecord record) {
    context.push(AppRouterName.callInfo, extra: record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4CAF50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: () => context.push(AppRouterName.selectContact),
        child: const Icon(Icons.add_call, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'calls_title'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                      letterSpacing: 0,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    width: 225,
                    height: 30,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (q) => context.read<CallHistoryCubit>().search(q),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: 'calls_search_hint'.tr(),
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Icon(Icons.search, color: Colors.grey[400], size: 16),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 30),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.only(top: 10, bottom: 10, left: 10, right: 15),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.green.withOpacity(0.3), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.green, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'calls_recent'.tr(),
                style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
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
                            onTap: () => _openCallInfo(context, record),
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
