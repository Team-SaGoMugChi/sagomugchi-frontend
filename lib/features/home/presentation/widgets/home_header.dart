import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/oddo_wordmark.dart';

/// Home top bar: 고른 날짜(누르면 큰 달력) + Oddo wordmark on the left,
/// notification and settings icons on the right. 날짜는 연·월·일까지 보여 준다 —
/// 아래에 따로 있던 "11월 3일" 줄을 합쳤다.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => context.pushNamed(AppRoute.monthlyCalendar),
              child: Row(
                children: [
                  // 작은 화면·큰 글씨에서는 넘치지 않게 줄인다.
                  Flexible(
                    child: Text(
                      '${DateFormatter.yearMonth(date)} ${date.day}일',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySecondary,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            const OddoWordmark(fontSize: 22),
          ],
        ),
      ),
      IconButton(
        tooltip: '알림',
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: AppColors.textStrong,
        ),
        onPressed: () => context.pushNamed(AppRoute.notifications),
      ),
      IconButton(
        tooltip: '설정',
        icon: const Icon(Icons.settings_outlined, color: AppColors.textStrong),
        onPressed: () => context.pushNamed(AppRoute.settings),
      ),
    ],
  );
}
