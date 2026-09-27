import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../data/dummy/persona_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/oddo_wordmark.dart';
import '../../../../widgets/primary_button.dart';
import '../../application/onboarding_completion_service.dart';

/// Screen 32 — 온보딩 완료. Bright blue gradient celebration → 홈 (07).
/// Marks onboarding complete so the home stops showing the first-measurement
/// popup and the diary CTA goes straight to writing.
class OnboardingDoneScreen extends ConsumerStatefulWidget {
  const OnboardingDoneScreen({super.key});

  @override
  ConsumerState<OnboardingDoneScreen> createState() =>
      _OnboardingDoneScreenState();
}

class _OnboardingDoneScreenState extends ConsumerState<OnboardingDoneScreen> {
  bool _saving = false;

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      await ref.read(onboardingCompletionServiceProvider).complete();
      if (mounted) context.goNamed(AppRoute.home);
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('완료 상태를 저장하지 못했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD7E7FE), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: OddoWordmark(fontSize: 40)),
                        Gap.h16,
                        // TODO: 두 손을 들고 환영하는 포즈로 교체 예정
                        const Center(
                          child: MascotImage(
                            pose: MascotPose.celebrate,
                            size: 180,
                          ),
                        ),
                        Gap.h20,
                        const Text(
                          '준비가 모두 끝났어요!',
                          textAlign: TextAlign.center,
                          style: AppTypography.display,
                        ),
                        Gap.h8,
                        const Text(
                          '이제 Oddo와 함께\n오늘의 감정을 기록해볼까요?',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySecondary,
                        ),
                        Gap.h24,
                        OddoCard(
                          child: Column(
                            children: [
                              for (
                                var i = 0;
                                i < PersonaDummy.onboardingSummary.length;
                                i++
                              ) ...[
                                if (i > 0)
                                  const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 20,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      PersonaDummy.onboardingSummary[i],
                                      style: AppTypography.body,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
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
                  label: '홈으로 가기',
                  loading: _saving,
                  onPressed: _complete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
