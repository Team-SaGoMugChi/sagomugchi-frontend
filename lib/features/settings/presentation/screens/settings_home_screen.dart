import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/permissions/app_permissions.dart';
import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/persona/data/persona_providers.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/oddo_app_bar.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../notifications/application/diary_reminder_controller.dart';

/// 실제 앱 버전 문자열 (테스트 등 플랫폼 채널이 없으면 '-').
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return '-';
  }
});

/// Auxiliary — 설정 홈. 프로필 요약 + 서비스/계정/정보 섹션 메뉴.
class SettingsHomeScreen extends ConsumerStatefulWidget {
  const SettingsHomeScreen({super.key});

  @override
  ConsumerState<SettingsHomeScreen> createState() => _SettingsHomeScreenState();
}

class _SettingsHomeScreenState extends ConsumerState<SettingsHomeScreen> {
  Future<void> _toggleReminder(bool value) async {
    final success = await ref
        .read(diaryReminderControllerProvider.notifier)
        .update(enabled: value);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림을 설정하지 못했어요. 휴대폰 설정에서 알림 권한을 확인해주세요.'),
          action: SnackBarAction(
            label: '설정 열기',
            onPressed: AppPermissions.openSettings,
          ),
        ),
      );
    }
  }

  Future<void> _chooseReminderTime() async {
    final settings = ref.read(diaryReminderControllerProvider);
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
    );
    if (chosen == null || !mounted) return;
    final success = await ref
        .read(diaryReminderControllerProvider.notifier)
        .update(
          enabled: settings.enabled,
          hour: chosen.hour,
          minute: chosen.minute,
        );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 시간을 저장하지 못했어요. 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('로그아웃할까요?', style: AppTypography.subtitle),
        content: const Text(
          '다시 로그인하면 기록을 이어서 볼 수 있어요.',
          style: AppTypography.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              '로그아웃',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.goNamed(AppRoute.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final persona = ref.watch(personaConfigProvider).value;
    final version = ref.watch(appVersionProvider).value ?? '-';

    return Scaffold(
      appBar: const OddoAppBar(title: '설정'),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              // ── 프로필 요약 (탭 → 마이페이지) ────────────────────────
              OddoCard(
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => context.pushNamed(AppRoute.myPage),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 26,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.nickname ?? '로그인이 필요해요',
                                style: AppTypography.subtitle,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '-',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const _SectionLabel('서비스'),
              OddoCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.smart_toy_outlined,
                      label: '챗봇 설정',
                      subtitle: persona != null
                          ? '${persona.name} · ${persona.tone}'
                          : null,
                      onTap: () => context.pushNamed(AppRoute.chatbotSettings),
                    ),
                    const Divider(color: AppColors.divider, height: 1),
                    // 권한 확인 후 기존 사용자는 튜토리얼을 건너뛰고 재측정한다.
                    _MenuRow(
                      icon: Icons.face_retouching_natural_rounded,
                      label: '베이스라인 다시 측정하기',
                      onTap: () => context.pushNamed(AppRoute.permission),
                    ),
                    const Divider(color: AppColors.divider, height: 1),
                    _MenuRow(
                      icon: Icons.notifications_none_rounded,
                      label: '일기 리마인더 알림',
                      subtitle: '매일 선택한 시간에 알려드려요',
                      trailing: Switch(
                        value: ref
                            .watch(diaryReminderControllerProvider)
                            .enabled,
                        activeThumbColor: AppColors.surface,
                        activeTrackColor: AppColors.primary,
                        onChanged:
                            ref.watch(diaryReminderControllerProvider).busy
                            ? null
                            : _toggleReminder,
                      ),
                    ),
                    _MenuRow(
                      icon: Icons.schedule_rounded,
                      label: '리마인더 시간',
                      subtitle: TimeOfDay(
                        hour: ref.watch(diaryReminderControllerProvider).hour,
                        minute: ref
                            .watch(diaryReminderControllerProvider)
                            .minute,
                      ).format(context),
                      onTap: ref.watch(diaryReminderControllerProvider).busy
                          ? null
                          : _chooseReminderTime,
                    ),
                  ],
                ),
              ),
              const _SectionLabel('계정'),
              OddoCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.person_outline_rounded,
                      label: '마이페이지',
                      onTap: () => context.pushNamed(AppRoute.myPage),
                    ),
                    const Divider(color: AppColors.divider, height: 1),
                    _MenuRow(
                      icon: Icons.logout_rounded,
                      label: '로그아웃',
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
              const _SectionLabel('정보'),
              OddoCard(
                padding: EdgeInsets.zero,
                child: _MenuRow(
                  icon: Icons.info_outline_rounded,
                  label: '앱 버전',
                  trailing: Text(version, style: AppTypography.bodySecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.lg, 4, AppSpacing.xs),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: AppTypography.caption),
                  ],
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
