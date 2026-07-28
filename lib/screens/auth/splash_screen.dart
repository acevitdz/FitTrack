import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();

    _finishTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            children: [
              const Spacer(flex: 4),
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: const _BrandContent(),
                ),
              ),
              const Spacer(flex: 5),
              const Text(
                'Đang chuẩn bị dữ liệu của bạn...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB6C6F2), fontSize: 13),
              ),
              const SizedBox(height: 14),
              const SizedBox(
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

class _BrandContent extends StatelessWidget {
  const _BrandContent();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FitTrack - Nâng tầm vóc dáng Việt',
      child: Column(
        children: [
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
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB6C6F2), fontSize: 16),
          ),
        ],
      ),
    );
  }
}
