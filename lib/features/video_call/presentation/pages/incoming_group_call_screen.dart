import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../bloc/call_cubit.dart';

class IncomingGroupCallScreen extends StatelessWidget {
  final String chatRoomId;
  final String callerName;
  final String groupName;
  final bool isVideo;

  const IncomingGroupCallScreen({
    super.key,
    required this.chatRoomId,
    required this.callerName,
    required this.groupName,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = groupName.isNotEmpty ? groupName : callerName;

    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is CallActive && state.isGroupCall) {
          context.pushReplacement(
            '/group_call/${state.chatRoomId}',
          );
        } else if (state is CallEnded || state is CallIdle) {
          if (context.canPop()) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF616161),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 60.resH),

              // ── Group name ────────────────────────────────────────────────
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.resH),

              Text(
                'call_group_call'.tr(),
                style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 16),
              ),

              const Spacer(),

              // ── Center Group Icon ──────────────────────────────────────────────
              Container(
                width: 160.resW,
                height: 160.resW,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEEEEE),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.group,
                    size: 80,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),

              const Spacer(),

              // ── Bottom Action Card ────────────────────────────────────────────
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 20.resH),
                padding: EdgeInsets.symmetric(horizontal: 20.resW, vertical: 20.resH),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B3B3B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caller info row
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 10.resW),
                        Expanded(
                          child: Text(
                            'call_is_calling_you'.tr(namedArgs: {'name': callerName}),
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ),
                        // Mini Avatars (stacked)
                        SizedBox(
                          width: 80.resW,
                          height: 32.resH,
                          child: Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              Positioned(
                                right: 0,
                                child: CircleAvatar(
                                  radius: 14.resR,
                                  backgroundColor: const Color(0xFF2E7D32),
                                  child: const Text('S', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ),
                              Positioned(
                                right: 20.resW,
                                child: CircleAvatar(
                                  radius: 14.resR,
                                  backgroundColor: const Color(0xFF388E3C),
                                  child: const Text('M', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ),
                              Positioned(
                                right: 40.resW,
                                child: CircleAvatar(
                                  radius: 14.resR,
                                  backgroundColor: const Color(0xFF4CAF50),
                                  child: const Text('+', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.resH),
                    // Ignore / Join buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14.resH),
                            ),
                            onPressed: () {
                              if (context.canPop()) context.pop();
                            },
                            child: Text(
                              'call_action_ignore'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.resW),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14.resH),
                            ),
                            onPressed: () => context.read<CallCubit>().acceptGroupCall(),
                            child: Text(
                              'call_action_join'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
