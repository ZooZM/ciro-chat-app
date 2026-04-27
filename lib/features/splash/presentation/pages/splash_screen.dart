import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_logo.dart';
import '../../../../features/chat/presentation/bloc/chat_cubit.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authFuture = context.read<AuthCubit>().verifyAuthStatus();
      
      // Fire off both futures
      final isAuth = await authFuture;
      
      if (isAuth) {
        await context.read<ChatCubit>().hydrateRooms();
        if (mounted) context.go('/home');
      } else {
        if (mounted) context.go('/auth');
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            // AppLogoWidget renders image asset + "CIRO" + "CONNECT"
            child: const AppLogoWidget(size: 180, showText: true),
          ),
        ),
      ),
    );
  }
}
