import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import '../bloc/call_cubit.dart';

class IncomingGroupCallScreen extends StatelessWidget {
  final String chatRoomId;
  final String callerName;
  final String groupName;
  final bool isVideo;
  final String callerAvatarUrl;

  const IncomingGroupCallScreen({
    super.key,
    required this.chatRoomId,
    required this.callerName,
    required this.groupName,
    required this.isVideo,
    this.callerAvatarUrl = '',
  });

  String get _initials {
    final name = groupName.isNotEmpty ? groupName : callerName;
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  String get _displayName => groupName.isNotEmpty ? groupName : callerName;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is CallActive && state.isGroupCall) {
          context.pushReplacement('/group_call/${state.chatRoomId}');
        } else if (state is CallEnded || state is CallIdle) {
          if (context.canPop()) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Hero(
            tag: 'call_screen_transition',
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE57373),
                    Color(0xFFD32F2F),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.resW, vertical: 24.resH),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Top Info Bar ──────────────────────────────────────
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 12.resH),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24.resR),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    // Group icon
                                    Container(
                                      width: 40.resR,
                                      height: 40.resR,
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.group, color: Colors.white, size: 22.resR),
                                    ),
                                    SizedBox(width: 12.resW),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  _displayName,
                                                  style: AppTypography.subtitle1.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(Icons.chevron_right, color: Colors.white70, size: 20.resR),
                                            ],
                                          ),
                                          Text(
                                            'call_group_call'.tr(),
                                            style: AppTypography.caption.copyWith(color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(8.resR),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                child: Icon(Icons.volume_up, color: Colors.white, size: 20.resR),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 32.resH),

                        // ── Large Group Avatar ────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.1),
                          ),
                          padding: EdgeInsets.all(16.resR),
                          child: CircleAvatar(
                            radius: 90.resR,
                            backgroundColor: AppColors.primary,
                            backgroundImage: callerAvatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(callerAvatarUrl)
                                : null,
                            child: callerAvatarUrl.isEmpty
                                ? Text(
                                    _initials,
                                    style: AppTypography.headline1.copyWith(
                                      color: Colors.white,
                                      fontSize: 56.resSp,
                                    ),
                                  )
                                : null,
                          ),
                        ),

                        SizedBox(height: 8.resH),

                        // Caller name subtitle
                        Text(
                          'call_is_calling_you'.tr(namedArgs: {'name': callerName}),
                          style: AppTypography.body2.copyWith(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 24.resH),

                        // ── Bottom Area (PIP + Actions) ───────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // PIP Avatar (lime green box)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 90.resW,
                                height: 140.resH,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB4E051),
                                  borderRadius: BorderRadius.circular(24.resR),
                                ),
                                child: Center(
                                  child: CircleAvatar(
                                    radius: 24.resR,
                                    backgroundColor: Colors.black26,
                                    child: const Icon(Icons.person, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 16.resH),

                            // Action Buttons Row: Join | Not Now | Arrow
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 16.resH),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(24.resR),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: () => context.read<CallCubit>().acceptGroupCall(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(vertical: 16.resH),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24.resR),
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'call_action_join'.tr(),
                                          style: AppTypography.subtitle1.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.resW),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (context.canPop()) context.pop();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(vertical: 16.resH),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24.resR),
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'call_action_not_now'.tr(),
                                          style: AppTypography.subtitle2.copyWith(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.resW),
                                  Container(
                                    padding: EdgeInsets.all(12.resR),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                    child: Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 24.resR),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
