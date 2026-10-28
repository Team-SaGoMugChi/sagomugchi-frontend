import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../widgets/diary_bottom_nav.dart';

/// Hosts the written-day context: the [일기][리포트][상담] tab bar wrapping the
/// three record screens (48–50). Each screen renders its own header (the
/// designs differ), so the shell only provides the bottom tab bar.
///
/// Built on go_router's [StatefulNavigationShell] so each tab keeps its own
/// navigation stack and scroll state.
class RecordsShell extends StatelessWidget {
  const RecordsShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DiaryBottomNav(
        currentIndex: navigationShell.currentIndex == 2 ? 2 : 1,
        onSelect: (i) {
          if (i == 0) context.goNamed(AppRoute.homeWritten);
          if (i == 1) context.goNamed(AppRoute.monthlyCalendar);
          if (i == 2) navigationShell.goBranch(2);
          if (i == 3) context.goNamed(AppRoute.myPage);
        },
      ),
    );
  }
}
