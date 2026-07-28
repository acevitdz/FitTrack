import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/home/main_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class FitTrackApp extends StatefulWidget {
  const FitTrackApp({super.key, required this.state});

  final AppState state;

  @override
  State<FitTrackApp> createState() => _FitTrackAppState();
}

class _FitTrackAppState extends State<FitTrackApp> {
  var _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final state = widget.state;
        return MaterialApp(
          title: 'FitTrack',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: state.themeMode,
          home: _showSplash
              ? const SplashScreen()
              : !state.isAuthenticated
              ? LoginScreen(state: state)
              : !state.profile.onboardingCompleted
              ? OnboardingScreen(state: state)
              : MainShell(state: state),
        );
      },
    );
  }
}
