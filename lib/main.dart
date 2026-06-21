import 'package:ciro_chat_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/di/injection.dart';
import 'core/network/socket_service.dart';
import 'core/routing/app_router.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/network/dio_client.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/chat/presentation/bloc/chat_cubit.dart';
import 'features/chat/presentation/widgets/call_overlay.dart';
import 'features/status/presentation/bloc/status_cubit.dart';
import 'features/video_call/presentation/bloc/call_cubit.dart';
import 'features/call_recording/presentation/bloc/call_recording_cubit.dart';
import 'features/map/presentation/bloc/map_cubit.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:easy_localization/easy_localization.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No UI work here — Firebase handles the notification display.
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Bloc.observer = const AppBlocObserver();

  await configureDependencies();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Network revocation fallback: run the full V-A logout teardown (resets
  // cubits, disconnects socket, unregisters push, wipes local data, clears
  // tokens). The AuthCubit emits Unauthenticated, which the router's refresh
  // stream picks up and routes to the auth screen — no manual navigation
  // needed. Guarded against re-entrancy because logOut() is idempotent on
  // already-cleared state.
  globalOnUnauthorizedRedirect = () {
    final authCubit = getIt<AuthCubit>();
    if (authCubit.state is Unauthenticated) return;
    authCubit.logOut();
  };

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      getIt<ChatCubit>().suspendDeliberateOpen();
    }

    // T031: Do NOT stop screen share on paused/inactive — iOS Broadcast Extension
    // and Android foreground service keep running while the app is backgrounded.
    // Only the OS-level stop path (LocalTrackUnpublishedEvent) handles teardown.
    final socket = getIt<SocketService>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      socket.disconnect();
      // 018-snap-map-realtime (FR-031): stop the geolocator stream while
      // backgrounded — independent of the socket, since GPS keeps running
      // otherwise and drains battery for no visible benefit.
      getIt<MapCubit>().pauseSharingForBackground();
    } else if (state == AppLifecycleState.resumed && !socket.isConnected) {
      getIt<AuthLocalDataSource>().getAccessToken().then((token) {
        if (token != null && token.isNotEmpty) socket.connect(token);
        getIt<MapCubit>().resumeSharingForForeground();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (screenUtilContext, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider<ChatCubit>(create: (_) => getIt<ChatCubit>()),
            BlocProvider<CallCubit>(create: (_) => getIt<CallCubit>()),
            BlocProvider<CallRecordingCubit>(
              create: (_) => getIt<CallRecordingCubit>(),
            ),
            BlocProvider<StatusCubit>(
              create: (_) => getIt<StatusCubit>()..loadRecentStatuses(),
            ),
            BlocProvider<MapCubit>(
              create: (_) => getIt<MapCubit>(),
            ),
          ],
          // CallOverlay centralizes all call navigation via GoRouter so the
          // chat back-stack is preserved across incoming and outgoing calls.
          child: CallOverlay(
            child: MaterialApp.router(
              title: 'Ciro Chat App',
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: ThemeData.dark(useMaterial3: true),
              routerConfig: appRouter,
              debugShowCheckedModeBanner: false,
            ),
          ),
        );
      },
    );
  }
}
