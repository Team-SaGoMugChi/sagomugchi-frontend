import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/oddo_wordmark.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.month});
  final DateTime month;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const OddoWordmark(fontSize: 22),
      const Spacer(),
      IconButton(
        tooltip: '알림',
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: AppColors.textStrong,
        ),
        onPressed: () => context.pushNamed(AppRoute.notifications),
      ),
    ],
  );
}
