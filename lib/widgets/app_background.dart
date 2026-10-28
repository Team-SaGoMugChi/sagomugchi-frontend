import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Plain warm-ivory canvas shared by the prototype's light screens.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.authBackground, child: child);
  }
}
