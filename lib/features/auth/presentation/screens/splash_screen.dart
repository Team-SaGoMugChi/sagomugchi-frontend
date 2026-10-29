import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../features/auth/application/auth_controller.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/oddo_wordmark.dart';

/// Screen 1 — 스플래시. Shows the brand while restoring the saved session,
/// then routes to home (auto-login) or the login screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Restore the session while the brand moment plays (min splash time).
    final results = await Future.wait<Object?>([
      Future<void>.delayed(const Duration(milliseconds: 1500)),
      ref.read(authControllerProvider.notifier).restoreSession(),
    ]);
    if (!mounted) return;
    final loggedIn = results[1] != null;
    context.goNamed(loggedIn ? AppRoute.home : AppRoute.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              const OddoWordmark(fontSize: 56),
              Gap.h20,
              Text(
                '말로 남기는 하루 기록',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(flex: 3),
              const _LoadingDots(),
              Gap.h32,
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == 0 ? AppColors.primary : AppColors.primarySoftBorder,
            ),
          ),
      ],
    );
  }
}
