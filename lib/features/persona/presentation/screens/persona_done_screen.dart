import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../../data/models/persona_config.dart';
import '../../data/persona_providers.dart';

/// Screen 31 — 페르소나 설정 완료. → 온보딩 완료.
class PersonaDoneScreen extends ConsumerWidget {
  const PersonaDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personaAsync = ref.watch(personaConfigProvider);
    final persona = personaAsync.value;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () {
                      if (context.canPop()) context.pop();
                    },
                  ),
                  const Expanded(
                    child: Text(
                      '설정 완료',
                      textAlign: TextAlign.center,
                      style: AppTypography.subtitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // TODO: 하트를 들고 있는 포즈로 교체 예정
                        const Center(
                          child: MascotImage(pose: MascotPose.heart, size: 140),
                        ),
                        Gap.h16,
                        personaAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                          error: (_, _) => _LoadFailure(
                            onRetry: () =>
                                ref.invalidate(personaConfigProvider),
                          ),
                          data: (config) => config == null
                              ? _LoadFailure(
                                  onRetry: () =>
                                      ref.invalidate(personaConfigProvider),
                                )
                              : _PersonaSummary(config: config),
                        ),
                      ],
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
                  label: '다음으로',
                  enabled: persona != null,
                  onPressed: () => context.pushNamed(AppRoute.onboardingDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonaSummary extends StatelessWidget {
  const _PersonaSummary({required this.config});

  final PersonaConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${config.name}가 준비됐어요!',
          textAlign: TextAlign.center,
          style: AppTypography.display,
        ),
        Gap.h8,
        const Text(
          '앞으로 당신의 하루를 따뜻하게 들어줄게요.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
        Gap.h24,
        OddoCard(
          child: Column(
            children: [
              _SummaryRow(label: '이름', value: config.name),
              const Divider(color: AppColors.divider, height: 20),
              _SummaryRow(label: '말투', value: config.tone),
              const Divider(color: AppColors.divider, height: 20),
              _SummaryRow(label: '성격', value: config.traits.join(', ')),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OddoCard(
      child: Column(
        children: [
          const Text(
            '저장한 페르소나를 불러오지 못했어요.',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
          Gap.h12,
          TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: AppTypography.bodySecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
