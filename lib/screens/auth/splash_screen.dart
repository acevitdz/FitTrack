import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 64),
          child: Column(
            children: [
              Spacer(flex: 4),
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.navySurface,
                child: Icon(
                  Icons.monitor_heart_outlined,
                  color: AppColors.paleBlue,
                  size: 58,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'FitTrack',
                style: TextStyle(
                  color: AppColors.paleBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Nâng tầm vóc dáng Việt',
                style: TextStyle(color: Color(0xFFB6C6F2), fontSize: 16),
              ),
              Spacer(flex: 5),
              SizedBox(
                width: 192,
                child: LinearProgressIndicator(
                  minHeight: 8,
                  color: AppColors.paleBlue,
                  backgroundColor: AppColors.navySurface,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
