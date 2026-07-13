import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/updates_screen.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_cubit.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/mobile_number_screen.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/verify_code_screen.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/profile_verification_welcome_screen.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/profile_verification_flow_screen.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/profile_verification_success_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/chat_list_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/chat_room_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/create_group_page.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/group_chat_screen.dart';
import 'package:ciro_chat_app/features/contacts/presentation/pages/contacts_screen.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/splash/presentation/pages/splash_screen.dart';
import 'package:ciro_chat_app/features/map/presentation/pages/invite_to_share_location_page.dart';
import 'package:flutter/material.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/story_viewer_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/video_call/presentation/pages/video_call_screen.dart';
import '../../features/video_call/presentation/pages/voice_call_screen.dart';
import '../../features/video_call/presentation/pages/incoming_call_screen.dart';
import '../../features/video_call/presentation/pages/outgoing_call_screen.dart';
import '../../features/video_call/presentation/pages/group_call_screen.dart';

import '../../features/video_call/presentation/pages/incoming_group_call_screen.dart';
import '../../features/video_call/presentation/pages/avatar_incoming_call_screen.dart';
import '../../features/video_call/presentation/pages/avatar_active_call_screen.dart';
import '../../features/video_call/presentation/bloc/call_cubit.dart';
import '../../features/call_recording/presentation/pages/recordings_list_page.dart';
import '../../features/call_history/presentation/pages/call_information_screen.dart';
import '../../features/call_history/presentation/pages/select_contact_screen.dart';
import '../../features/call_history/presentation/pages/dialpad_screen.dart';
import '../../features/call_history/presentation/pages/new_contact_screen.dart';
import '../../features/call_history/domain/entities/call_history_record.dart';
import '../../features/reels/presentation/pages/creator_profile_screen.dart';
import '../../features/reels/presentation/pages/reel_capture_screen.dart';
import '../../features/reels/presentation/pages/reels_feed_screen.dart';
import '../../features/reels/presentation/pages/search_screen.dart';
import '../../features/reels/presentation/pages/upload_reel_screen.dart';
import '../../features/profile/presentation/pages/profile_main_screen.dart';
import '../../features/profile/presentation/pages/qr_code_screen.dart';
import '../../features/profile/presentation/pages/profile_info_screen.dart';
import '../../features/profile/presentation/pages/appearance_screen.dart';
import '../../features/profile/presentation/pages/chat_theme_preview_screen.dart';
import '../../features/profile/presentation/pages/language_screen.dart';
import '../../features/profile/presentation/pages/logout_screen.dart';
import '../../features/profile/presentation/pages/invite_friend_screen.dart';
import '../../features/profile/presentation/pages/invite_via_screen.dart';
import '../../features/profile/presentation/pages/invite_link_screen.dart';
import '../../features/profile/presentation/pages/notification_screen.dart';
import '../../features/profile/presentation/pages/privacy_screen.dart';
import '../../features/profile/presentation/pages/change_phone_number_screen.dart';
import '../../features/profile/presentation/pages/verify_new_phone_number_screen.dart';
import '../../features/profile/presentation/pages/billing_info_screen.dart';
import '../../features/profile/presentation/pages/bank_account_screen.dart';
import '../../features/profile/presentation/pages/payments_history_screen.dart';
import '../../features/profile/presentation/pages/identity_verification_screen.dart';
import '../../features/profile/presentation/pages/identity_verification_stepper_screen.dart';
import '../../features/profile/presentation/pages/identity_verification_success_screen.dart';
import '../../features/profile/presentation/pages/payments_method_screen.dart';
import '../../features/profile/presentation/pages/add_new_card_screen.dart';
import '../../features/profile/presentation/pages/add_apple_pay_screen.dart';
import '../../features/profile/presentation/pages/add_google_pay_screen.dart';
import '../../features/profile/presentation/pages/google_pay_success_screen.dart';
import '../../features/profile/presentation/pages/help_feedback_screen.dart';
import '../../features/profile/presentation/pages/contact_us_screen.dart';
import '../../features/profile/presentation/pages/report_problem_screen.dart';
import '../../features/profile/presentation/pages/faq_screen.dart';
import '../../features/profile/presentation/pages/privacy_policy_screen.dart';
import '../../features/profile/presentation/pages/terms_service_screen.dart';
import '../../features/profile/presentation/pages/send_feedback_screen.dart';
import '../di/injection.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'go_router_refresh_stream.dart';

/// `chatRoom`'s `extra` payload when the caller also wants to hand the
/// screen a draft message (e.g. the map's "invite to share location" flow) —
/// existing call sites keep passing a bare [ChatSession] unchanged.
class ChatRoomLaunchArgs {
  const ChatRoomLaunchArgs(this.chat, {this.initialDraftText});

  final ChatSession chat;
  final String? initialDraftText;
}

class AppRouterName {
  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String verify = 'verify';
  static const String profileVerificationWelcome = '/profile/verification';
  static const String profileVerificationFlow = '/profile/verification/flow';
  static const String profileVerificationSuccess = '/profile/verification/success';
  static const String home = '/home';
  static const String createGroup = '/home/create_group';
  static const String chatRoom = '/chat_room';
  static const String inviteToShareLocation = '/invite_to_share_location';
  static const String groupChat = '/group_chat';
  static const String contacts = '/contacts';
  static const String incomingCall = '/incoming_call';
  static const String videoCall = '/video_call';
  static const String outgoingCall = '/outgoing_call';
  static const String voiceCall = '/voice_call';
  static const String updates = '/updates';
  static const String map = '/map';
  static const String calls = '/calls';
  static const String profile = '/profile';
  static const String groupCall = '/group_call/:roomId';

  static const String incomingGroupCall = '/incoming_group_call';
  static const String avatarIncomingCall = '/avatar_incoming_call';
  static const String avatarActiveCall = '/avatar_active_call';
  static const String recordings = '/recordings';
  static const String callInfo = '/call_info';
  static const String selectContact = '/select_contact';
  static const String dialpad = '/dialpad';
  static const String newContact = '/new_contact';
  static const String reelDeepLink = '/reels/:id';
  static const String reelCreatorFeed = '/reels/creator/:id';
  static const String creatorProfile = '/reels/profile/:id';
  static const String reelHashtagFeed = '/reels/hashtag/:tag';
  static const String reelLikedFeed = '/reels/liked';
  static const String reelSavedFeed = '/reels/saved';
  // v6: public Reposts scoped feed — `?userId=` selects whose reposts.
  static const String reelRepostedFeed = '/reels/reposted';
  static const String reelSearch = '/reels/search';
  // v5 (FR-079): the "+" entry's camera-first destination — declared before
  // `/reels/:id` for the same reason as the other static 2-segment reels
  // paths above. The post-details step is not a route (the trimmer pushes it
  // directly), so there is no `/reels/upload`.
  static const String reelCapture = '/reels/capture';
  // v3 (FR-060): declared before `/reels/:id` for the same reason as the
  // other static 2-segment reels paths above.
  static const String reelUpload = '/reels/upload';

  static const String qrCode = '/profile/qr_code';
  static const String profileInfo = '/profile/info';
  static const String appearance = '/profile/appearance';
  static const String chatThemePreview = '/profile/appearance/theme_preview';
  static const String language = '/profile/language';
  static const String logout = '/profile/logout';
  static const String inviteFriend = '/profile/invite_friend';
  static const String inviteVia = '/profile/invite_friend/via';
  static const String inviteLink = '/profile/invite_friend/link';
  static const String notifications = '/profile/notifications';
  static const String privacy = '/profile/privacy';
  static const String changePhone = '/profile/change_phone';
  static const String verifyNewPhone = 'verify_new_phone';
  static const String billingInfo = '/profile/billing_info';
  static const String bankAccount = '/profile/bank_account';
  static const String identityVerification = '/profile/identity_verification';
  static const String identityVerificationStepper =
      '/profile/identity_verification/stepper';
  static const String identityVerificationSuccess =
      '/profile/identity_verification/success';
  static const String paymentsMethod = '/profile/payments_method';
  static const String addNewCard = '/profile/payments_method/add_card';
  static const String addApplePay = '/profile/payments_method/add_apple_pay';
  static const String addGooglePay = '/profile/payments_method/add_google_pay';
  static const String googlePaySuccess =
      '/profile/payments_method/google_pay_success';
  static const String paymentsHistory = '/profile/payments_history';
  static const String helpFeedback = '/profile/help_feedback';
  static const String contactUs = '/profile/help_feedback/contact_us';
  static const String faq = '/profile/help_feedback/faq';
  static const String reportProblem = '/profile/help_feedback/report_problem';
  static const String sendFeedback = '/profile/help_feedback/send_feedback';
  static const String privacyPolicy = '/profile/help_feedback/privacy_policy';
  static const String termsService = '/profile/help_feedback/terms_service';
}

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

/// Lets a still-mounted screen detect "a route pushed on top of me was just
/// popped, I'm visible again" (`RouteAware.didPopNext`) — unlike `initState`,
/// which only runs once per widget instance and therefore misses this signal
/// for a screen that was never rebuilt (e.g. the Reels tab body sitting under
/// a pushed Creator Profile / scoped-feed route). Used by `ReelsFeedScreen`
/// to re-sync its scope against the shared `ReelsFeedBloc` singleton, which a
/// pushed scoped feed (creator/hashtag/liked/saved) may have mutated.
final RouteObserver<PageRoute<dynamic>> reelsRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Checks if the app was launched by tapping a push notification (terminated state).
/// If so, navigates directly to the referenced chat room or status.
Future<void> handleInitialNotification() async {
  final message = await FirebaseMessaging.instance.getInitialMessage();
  if (message == null) return;

  final type = message.data['type'] as String?;
  if (type == 'statusReaction') {
    final statusId = message.data['statusId'] as String?;
    if (statusId != null) await navigateToStatusReaction(statusId);
    return;
  }
  if (type == 'newFollower' || type == 'reelLike' || type == 'reelMention') {
    final payload = type == 'newFollower'
        ? 'reelProfile:${message.data['actorId']}'
        : 'reel:${message.data['reelId']}';
    await navigateToReelsNotification(payload);
    return;
  }
  // v3 (FR-064): rejection is system-originated (no actorId) — resolved to
  // the current user's own profile at navigation time (see below).
  if (type == 'reelRejected') {
    await navigateToReelsNotification('reelOwnProfile:');
    return;
  }

  final roomId = message.data['roomId'] as String?;
  if (roomId == null) return;
  final room = await getIt<ChatCubit>().getRoomById(roomId);
  if (room != null) {
    appRouter.push(AppRouterName.chatRoom, extra: room);
  }
}

/// Opens the story viewer for [statusId] (one of the current user's own
/// statuses) with the viewers/reactions sheet shown automatically — used when
/// the user taps a "X loved your status" push notification.
Future<void> navigateToStatusReaction(String statusId) async {
  final statusCubit = getIt<StatusCubit>();
  if (statusCubit.state is! StatusLoaded) {
    await statusCubit.loadRecentStatuses();
  }
  final state = statusCubit.state;
  if (state is StatusLoaded) {
    final index = state.myStatuses.indexWhere((s) => s.id == statusId);
    if (index != -1) {
      globalNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
            statuses: state.myStatuses,
            initialIndex: index,
            openViewersOnStart: true,
          ),
        ),
      );
      return;
    }
  }
  appRouter.go(AppRouterName.updates);
}

/// FR-054/FR-064: routes a tapped Reels notification — `reel:<id>` opens
/// that reel (deep-link entry, FR-040); `reelProfile:<id>` opens that
/// user's profile; `reelOwnProfile:` (no id — the rejection push carries no
/// actorId, FR-064) opens the *current* user's own profile, resolved here
/// at navigation time. Used by both the FCM cold/background tap handler and
/// the locally-shown foreground banner tap (mirrors the `status:`-prefixed
/// payload convention).
Future<void> navigateToReelsNotification(String payload) async {
  if (payload.startsWith('reelOwnProfile:')) {
    final userId = await getIt<AuthLocalDataSource>().getUserId();
    if (userId != null && userId.isNotEmpty) {
      appRouter.push('/reels/profile/$userId');
    }
  } else if (payload.startsWith('reelProfile:')) {
    appRouter.push(
      '/reels/profile/${payload.substring('reelProfile:'.length)}',
    );
  } else if (payload.startsWith('reel:')) {
    appRouter.push('/reels/${payload.substring('reel:'.length)}');
  }
}

final GoRouter appRouter = GoRouter(
  navigatorKey: globalNavigatorKey,
  observers: [reelsRouteObserver],
  initialLocation: AppRouterName.splash,
  // GoRouterRefreshStream bridges AuthCubit state changes to GoRouter.
  // Every time AuthCubit emits a new state, the redirect guard below is re-run.
  refreshListenable: GoRouterRefreshStream(getIt<AuthCubit>().stream),
  // Pure state-driven redirect: reads AuthCubit synchronously — no async,
  // no stale boolean flags, no race conditions.
  redirect: (context, state) async {
    // Remove the native splash on the very first routing evaluation.
    FlutterNativeSplash.remove();

    final authState = getIt<AuthCubit>().state;
    final location = state.uri.toString();

    final isAuthRoute =
        location == AppRouterName.auth ||
        location.startsWith('${AppRouterName.auth}/');
    final isSplash = location == AppRouterName.splash;

    // ── RULE 1: Transient states — do NOT redirect ────────────────────────────
    // AuthLoading fires during OTP send, token refresh, and initial boot.
    // AuthInitial is the cold-start state before verifyAuthStatus() runs.
    // Returning null keeps the user exactly where they are so loading spinners work.
    if (authState is AuthInitial || authState is AuthLoading) {
      return null;
    }

    // ── RULE 2: Authenticated ─────────────────────────────────────────────────
    // Eject from splash/auth screens into the app; don't disturb any other screen.
    if (authState is Authenticated) {
      await context.read<ChatCubit>().hydrateRooms();
      if (isAuthRoute) {
        // FR-043: a reel deep link opened while logged out completes the
        // normal login flow first, then continues to the linked reel —
        // restricted to /reels/ targets so this can't become an open redirect.
        final target = state.uri.queryParameters['redirect'];
        if (target != null && target.startsWith('/reels/')) return target;
        return AppRouterName.profileInfo;
      }
      return null;
    }

    // ── RULE 3: Unauthenticated or AuthError ──────────────────────────────────
    // Redirect to /auth only if not already there.
    if (!isAuthRoute && !isSplash) {
      if (location.startsWith('/reels/')) {
        return '${AppRouterName.auth}?redirect=${Uri.encodeComponent(location)}';
      }
      return AppRouterName.auth;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppRouterName.splash,
      builder: (context, state) => BlocProvider.value(
        value: getIt<AuthCubit>(),
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: AppRouterName.auth,
      builder: (context, state) => BlocProvider.value(
        value: getIt<AuthCubit>(),
        child: const MobileNumberScreen(),
      ),
      routes: [
        GoRoute(
          path: AppRouterName.verify,
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return BlocProvider.value(
              value: getIt<AuthCubit>(),
              child: VerifyCodeScreen(phoneNumber: phone),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: AppRouterName.profileVerificationWelcome,
      builder: (context, state) => const ProfileVerificationWelcomeScreen(),
    ),
    GoRoute(
      path: AppRouterName.profileVerificationFlow,
      builder: (context, state) => const ProfileVerificationFlowScreen(),
    ),
    GoRoute(
      path: AppRouterName.profileVerificationSuccess,
      builder: (context, state) => const ProfileVerificationSuccessScreen(),
    ),
    GoRoute(
      path: AppRouterName.home,
      builder: (context, state) => const ChatListScreen(),
      routes: [
        GoRoute(
          path: 'create_group',
          builder: (context, state) => const CreateGroupPage(),
        ),
      ],
    ),
    GoRoute(
      path: AppRouterName.inviteToShareLocation,
      builder: (context, state) => const InviteToShareLocationPage(),
    ),
    GoRoute(
      path: AppRouterName.chatRoom,
      builder: (context, state) {
        // state.extra is null when GoRouter rebuilds this route without the
        // original extra (deep link, router restore, rotation, or any push
        // missing extra). Cast as nullable and redirect to home instead of
        // throwing a TypeError.
        final extra = state.extra;
        final chat = extra is ChatRoomLaunchArgs
            ? extra.chat
            : extra as ChatSession?;
        final initialDraftText = extra is ChatRoomLaunchArgs
            ? extra.initialDraftText
            : null;
        if (chat == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(AppRouterName.home);
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        // ChatRoomScreen.initState calls cubit.openRoom — do NOT call it here too.
        return ChatRoomScreen(
          chatData: chat,
          initialDraftText: initialDraftText,
        );
      },
    ),
    GoRoute(
      path: AppRouterName.groupChat,
      builder: (context, state) {
        final chat = state.extra as ChatSession?;
        if (chat != null) return ChatRoomScreen(chatData: chat);
        return const GroupChatScreen();
      },
    ),
    GoRoute(
      path: AppRouterName.contacts,
      builder: (context, state) => const ContactsScreen(),
    ),
    GoRoute(
      path: AppRouterName.incomingCall,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return IncomingCallScreen(
          callerName: data['callerName'] as String? ?? 'Unknown',
          callerId: data['callerId'] as String? ?? '',
          callerAvatarUrl: data['callerAvatarUrl'] as String? ?? '',
          isVideo: data['isVideo'] == true,
        );
      },
    ),
    GoRoute(
      path: AppRouterName.videoCall,
      pageBuilder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return CustomTransitionPage(
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          child: Hero(
            tag: 'call_screen_transition',
            child: VideoCallScreen(
              contactName: data['contactName'] as String? ?? 'Calling...',
              livekitUrl: data['livekitUrl'] as String? ?? '',
              livekitToken: data['livekitToken'] as String? ?? '',
            ),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRouterName.outgoingCall,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return OutgoingCallScreen(
          contactName: data['contactName'] as String? ?? 'Calling...',
          avatarUrl: data['avatarUrl'] as String? ?? '',
          isVideoCall: data['isVideoCall'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: AppRouterName.voiceCall,
      pageBuilder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return CustomTransitionPage(
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          child: Hero(
            tag: 'call_screen_transition',
            child: VoiceCallScreen(
              contactName: data['contactName'] as String? ?? 'Calling...',
              avatarInitials: data['avatarInitials'] as String? ?? '',
              livekitUrl: data['livekitUrl'] as String? ?? '',
              livekitToken: data['livekitToken'] as String? ?? '',
              initialMicMuted: data['initialMicMuted'] as bool? ?? false,
              initialSpeakerOn: data['initialSpeakerOn'] as bool? ?? false,
            ),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRouterName.updates,
      builder: (context, state) => const UpdatesScreen(),
    ),
    GoRoute(
      path: '/group_call/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? '';
        return GroupCallScreen(roomId: roomId);
      },
    ),

    GoRoute(
      path: AppRouterName.incomingGroupCall,
      pageBuilder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return CustomTransitionPage(
          opaque: false,
          barrierColor: Colors.black54,
          child: IncomingGroupCallScreen(
            chatRoomId: data['chatRoomId'] as String? ?? '',
            callerName: data['callerName'] as String? ?? 'Unknown',
            groupName: data['groupName'] as String? ?? '',
            isVideo: data['isVideo'] == true,
            callerAvatarUrl: data['callerAvatarUrl'] as String? ?? '',
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRouterName.recordings,
      builder: (context, state) => const RecordingsListPage(),
    ),
    // Declared before the single-segment `/reels/:id` route below so the
    // literal `creator` segment is matched first (FR-026).
    GoRoute(
      path: AppRouterName.reelCreatorFeed,
      builder: (context, state) {
        final creatorId = state.pathParameters['id'] ?? '';
        final startReelId = state.uri.queryParameters['start'];
        return ReelsFeedScreen(
          creatorId: creatorId,
          initialReelId: startReelId,
        );
      },
    ),
    // Declared before `/reels/:id` for the same reason as the route above.
    GoRoute(
      path: AppRouterName.creatorProfile,
      builder: (context, state) {
        final userId = state.pathParameters['id'] ?? '';
        return CreatorProfileScreen(userId: userId);
      },
    ),
    // Declared before `/reels/:id` for the same reason as the routes above.
    GoRoute(
      path: AppRouterName.reelHashtagFeed,
      builder: (context, state) {
        final tag = state.pathParameters['tag'] ?? '';
        return ReelsFeedScreen(hashtag: tag);
      },
    ),
    // `/reels/liked` and `/reels/saved` are also 2-segment paths, colliding
    // with `/reels/:id` — declared before it for the same reason.
    GoRoute(
      path: AppRouterName.reelLikedFeed,
      builder: (context, state) => ReelsFeedScreen(
        listSource: 'liked',
        initialReelId: state.uri.queryParameters['start'],
      ),
    ),
    GoRoute(
      path: AppRouterName.reelSavedFeed,
      builder: (context, state) => ReelsFeedScreen(
        listSource: 'saved',
        initialReelId: state.uri.queryParameters['start'],
      ),
    ),
    // v6: public Reposts scoped feed — `userId` selects whose reposts.
    GoRoute(
      path: AppRouterName.reelRepostedFeed,
      builder: (context, state) => ReelsFeedScreen(
        listSource: 'reposted',
        listSourceUserId: state.uri.queryParameters['userId'],
        initialReelId: state.uri.queryParameters['start'],
      ),
    ),
    GoRoute(
      path: AppRouterName.reelSearch,
      builder: (context, state) => const ReelsSearchScreen(),
    ),
    // v5 (FR-079): the "+" upload entry now opens the camera-first capture
    // screen; declared before `/reels/:id` like the other static reels paths.
    // The post-details step (`UploadReelScreen`) is no longer a route — the
    // trimmer pushes it directly (B3) so the camera never flashes between
    // "Next" and the post screen.
    GoRoute(
      path: AppRouterName.reelCapture,
      builder: (context, state) => const ReelCaptureScreen(),
    ),
    // Deep-link entry point (FR-038/FR-040): `https://ciro.chat/reels/:id`.
    GoRoute(
      path: AppRouterName.reelDeepLink,
      builder: (context, state) {
        final reelId = state.pathParameters['id'] ?? '';
        return ReelsFeedScreen(initialReelId: reelId);
      },
    ),
    GoRoute(
      path: AppRouterName.avatarIncomingCall,
      pageBuilder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return CustomTransitionPage(
          opaque: false,
          barrierColor: Colors.black54,
          child: AvatarIncomingCallScreen(
            callerName: data['callerName'] as String? ?? 'Unknown',
            callerAvatarUrl: data['callerAvatarUrl'] as String? ?? '',
            onJoin: () => getIt<CallCubit>().acceptCall(),
            onDecline: () => getIt<CallCubit>().rejectCall(),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRouterName.avatarActiveCall,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return StatefulBuilder(
          builder: (context, setState) {
            bool isMuted = data['isMuted'] == true;
            bool isCameraOff = data['isCameraOff'] == true;
            return AvatarActiveCallScreen(
              remoteName: data['remoteName'] as String? ?? 'Unknown',
              remoteAvatarUrl: data['remoteAvatarUrl'] as String? ?? '',
              localAvatarUrl: data['localAvatarUrl'] as String? ?? '',
              localName: data['localName'] as String? ?? 'You',
              isMuted: isMuted,
              isCameraOff: isCameraOff,
              callDuration: data['callDuration'] as String? ?? '00:00',
              onToggleMute: () {
                setState(() => data['isMuted'] = !isMuted);
              },
              onToggleCamera: () {
                setState(() => data['isCameraOff'] = !isCameraOff);
              },
              onEndCall: () => getIt<CallCubit>().endCall(),
              onMinimize: () {
                if (context.canPop()) context.pop();
              },
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRouterName.callInfo,
      builder: (context, state) {
        final record = state.extra as CallHistoryRecord;
        return CallInformationScreen(record: record);
      },
    ),
    GoRoute(
      path: AppRouterName.selectContact,
      builder: (context, state) => const SelectContactScreen(),
    ),
    GoRoute(
      path: AppRouterName.dialpad,
      builder: (context, state) => const DialpadScreen(),
    ),
    GoRoute(
      path: AppRouterName.newContact,
      builder: (context, state) => const NewContactScreen(),
    ),
    GoRoute(
      path: AppRouterName.profile,
      builder: (context, state) => const ProfileMainScreen(),
    ),
    GoRoute(
      path: AppRouterName.qrCode,
      builder: (context, state) => const QrCodeScreen(),
    ),
    GoRoute(
      path: AppRouterName.profileInfo,
      builder: (context, state) => const ProfileInfoScreen(),
    ),
    GoRoute(
      path: AppRouterName.appearance,
      builder: (context, state) => const AppearanceScreen(),
    ),
    GoRoute(
      path: AppRouterName.chatThemePreview,
      builder: (context, state) => const ChatThemePreviewScreen(),
    ),
    GoRoute(
      path: AppRouterName.language,
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: AppRouterName.logout,
      builder: (context, state) => const LogoutScreen(),
    ),
    GoRoute(
      path: AppRouterName.inviteFriend,
      builder: (context, state) => const InviteFriendScreen(),
    ),
    GoRoute(
      path: AppRouterName.inviteVia,
      builder: (context, state) => const InviteViaScreen(),
    ),
    GoRoute(
      path: AppRouterName.inviteLink,
      builder: (context, state) => const InviteLinkScreen(),
    ),
    GoRoute(
      path: AppRouterName.notifications,
      builder: (context, state) => const NotificationScreen(),
    ),
    GoRoute(
      path: AppRouterName.privacy,
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: AppRouterName.changePhone,
      builder: (context, state) => const ChangePhoneNumberScreen(),
      routes: [
        GoRoute(
          path: AppRouterName.verifyNewPhone,
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return VerifyNewPhoneNumberScreen(phoneNumber: phone);
          },
        ),
      ],
    ),
    GoRoute(
      path: AppRouterName.billingInfo,
      builder: (context, state) => const BillingInfoScreen(),
    ),
    GoRoute(
      path: AppRouterName.bankAccount,
      builder: (context, state) => const BankAccountScreen(),
    ),
    GoRoute(
      path: AppRouterName.identityVerification,
      builder: (context, state) => const IdentityVerificationScreen(),
      routes: [
        GoRoute(
          path: 'stepper',
          builder: (context, state) =>
              const IdentityVerificationStepperScreen(),
        ),
        GoRoute(
          path: 'success',
          builder: (context, state) =>
              const IdentityVerificationSuccessScreen(),
        ),
      ],
    ),
    GoRoute(
      path: AppRouterName.paymentsMethod,
      builder: (context, state) => const PaymentsMethodScreen(),
    ),
    GoRoute(
      path: AppRouterName.addNewCard,
      builder: (context, state) => const AddNewCardScreen(),
    ),
    GoRoute(
      path: AppRouterName.addApplePay,
      builder: (context, state) => const AddApplePayScreen(),
    ),
    GoRoute(
      path: AppRouterName.addGooglePay,
      builder: (context, state) => const AddGooglePayScreen(),
    ),
    GoRoute(
      path: AppRouterName.googlePaySuccess,
      builder: (context, state) => const GooglePaySuccessScreen(),
    ),
    GoRoute(
      path: AppRouterName.paymentsHistory,
      builder: (context, state) => const PaymentsHistoryScreen(),
    ),
    GoRoute(
      path: AppRouterName.helpFeedback,
      builder: (context, state) => const HelpFeedbackScreen(),
    ),
    GoRoute(
      path: AppRouterName.contactUs,
      builder: (context, state) => const ContactUsScreen(),
    ),
    GoRoute(
      path: AppRouterName.faq,
      builder: (context, state) => const FaqScreen(),
    ),
    GoRoute(
      path: AppRouterName.reportProblem,
      builder: (context, state) => const ReportProblemScreen(),
    ),
    GoRoute(
      path: AppRouterName.sendFeedback,
      builder: (context, state) => const SendFeedbackScreen(),
    ),
    GoRoute(
      path: AppRouterName.privacyPolicy,
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: AppRouterName.termsService,
      builder: (context, state) => const TermsServiceScreen(),
    ),
  ],
);
