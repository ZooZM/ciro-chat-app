import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'core/routing/app_router.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'features/chat/presentation/bloc/chat_cubit.dart';
import 'features/video_call/presentation/bloc/call_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const AppBlocObserver();
  await configureDependencies();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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
            // CallCubit is global so IncomingCall can be triggered from anywhere
            BlocProvider<CallCubit>(create: (_) => getIt<CallCubit>()),
          ],
          child: BlocListener<CallCubit, CallState>(
            // Automatically navigate to IncomingCallScreen when socket fires
            listenWhen: (_, curr) => curr is CallIncoming,
            listener: (context, state) {
              if (state is CallIncoming) {
                appRouter.push('/incoming_call', extra: {
                  'callerName': state.callerName,
                  'callerAvatarUrl': state.callerAvatarUrl,
                });
              }
            },
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
