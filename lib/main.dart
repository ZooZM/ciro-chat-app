import 'package:ciro_chat_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'core/network/socket_service.dart';
import 'core/routing/app_router.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/network/dio_client.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/chat/presentation/bloc/chat_cubit.dart';
import 'features/chat/presentation/widgets/call_overlay.dart';
import 'features/status/presentation/bloc/status_cubit.dart';
import 'features/video_call/presentation/bloc/call_cubit.dart';
import 'features/call_recording/presentation/bloc/call_recording_cubit.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No UI work here — Firebase handles the notification display.
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Bloc.observer = const AppBlocObserver();

  await configureDependencies();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Link Network failure fallback strictly after router & DI initialization
  globalOnUnauthorizedRedirect = () => appRouter.go(AppRouterName.auth);

  runApp(const MainApp());
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

    final socket = getIt<SocketService>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      socket.disconnect();
    } else if (state == AppLifecycleState.resumed && !socket.isConnected) {
      getIt<AuthLocalDataSource>().getAccessToken().then((token) {
        if (token != null && token.isNotEmpty) socket.connect(token);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
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
          ],
          // CallOverlay centralizes all call navigation via GoRouter so the
          // chat back-stack is preserved across incoming and outgoing calls.
          child: CallOverlay(
            child: MaterialApp.router(
              title: 'Ciro Chat App',
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
