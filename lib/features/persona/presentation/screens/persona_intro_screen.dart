import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/primary_button.dart';

/// A quiet welcome before choosing tone, voice and personality.
class PersonaIntroScreen extends StatelessWidget {
  const PersonaIntroScreen({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('페르소나 설정', style: AppTypography.subtitle),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: AppSpacing.screenPadding,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '나에게 맞는\n대화 친구를 만들어요',
                              textAlign: TextAlign.center,
                              style: AppTypography.display,
                            ),
                            Gap.h12,
                            const Text(
                              '말투와 목소리, 성격을 골라주세요.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySecondary,
                            ),
                            Gap.h32,
                            Image.asset(
                              AppAssets.personaFriends,
                              fit: BoxFit.contain,
                              semanticLabel: '오또와 나란히 서 있는 다섯 대화 친구들',
                            ),
                            Gap.h24,
                            const Wrap(
                              alignment: WrapAlignment.center,
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                _SettingHint(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  label: '말투',
                                ),
                                _SettingHint(
                                  icon: Icons.graphic_eq_rounded,
                                  label: '목소리',
                                ),
                                _SettingHint(
                                  icon: Icons.favorite_border_rounded,
                                  label: '성격',
                                ),
                              ],
                            ),
                            Gap.h24,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                ),
                child: PrimaryButton(
                  label: '설정 시작하기',
                  onPressed: () => context.pushNamed(AppRoute.personaDetail),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SettingHint extends StatelessWidget {
  const _SettingHint({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSpacing.md, color: AppColors.textSecondary),
        Gap.w8,
        Text(label, style: AppTypography.bodySecondary),
      ],
    ),
  );
}
