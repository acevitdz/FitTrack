import 'package:flutter/material.dart';

// TODO(team-lead): temporary — points at TV2's preview hub so the exercise
// screens can be clicked through before MainShell/AppState compile again.
// Revert to the real MainShell entry once app-wide state is wired back up.
import 'screens/exercises/tv2_preview_hub.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const FitTrackApp());
}

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FitTrack',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const Scaffold(body: Tv2PreviewHub()),
    );
  }
}
