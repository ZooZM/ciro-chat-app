import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_logo.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/domain/repositories/auth_repository.dart';

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
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();

    // Check login status in the background while the animation plays
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for the splash animation to finish (at least 2.5 seconds total)
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    try {
      final authRepo = getIt<AuthRepository>();
      final isLoggedIn = false;
      // await authRepo.checkAuthStatus();

      if (isLoggedIn) {
        context.go('/home'); // Direct to ChatListScreen
      } else {
        context.go('/auth'); // Direct to PhoneInputScreen
      }
    } catch (e) {
      // On error, default to auth screen
      if (mounted) context.go('/auth');
    }
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
