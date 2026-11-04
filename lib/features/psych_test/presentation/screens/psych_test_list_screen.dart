import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/icon_info_tile.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../widgets/step_title.dart';
import '../../../onboarding/application/onboarding_controller.dart';

/// Screens 22·23 — 심리테스트 안내. "테스트 시작하기"를 누르면 바로 Big 5 문항이 시작된다.
///
/// 예전에는 검사 목록(22)과 시작 안내(23) 두 장을 거쳐야 했고 내용도 겹쳤다. 한 장에 합쳤다
/// (psychTestStart 경로도 이 화면).
class PsychTestListScreen extends ConsumerWidget {
  const PsychTestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 온보딩 중에는 베이스라인 측정으로 돌아가지 않는다(버튼·시스템 뒤로가기 모두).
    final onboarding = !ref.watch(onboardingCompleteProvider);
    return PopScope(
      canPop: !onboarding,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    if (onboarding)
                      const SizedBox(width: kMinInteractiveDimension)
                    else
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
                      child: StepTitle(title: '심리테스트', previous: '베이스라인'),
                    ),
                    const SizedBox(width: kMinInteractiveDimension),
                  ],
                ),
                Expanded(
                  // 작은 화면에서만 스크롤된다.
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.md,
                      AppSpacing.screenH,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Big 5 성격검사를\n시작해볼까요?',
                                    style: AppTypography.display,
                                  ),
                                  Gap.h8,
                                  Text(
                                    '공개 IPIP Big Five 50문항으로 나를 이해하는 참고 자료를 만들어요. '
                                    '진단이 아니에요.',
                                    style: AppTypography.bodySecondary,
                                  ),
                                ],
                              ),
                            ),
                            // TODO: 클립보드를 들고 안내하는 포즈로 교체 예정
                            MascotImage(pose: MascotPose.clipboard, size: 88),
                          ],
                        ),
                        Gap.h20,
                        const OddoCard(child: _GuideList()),
                        Gap.h8,
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                context.pushNamed(AppRoute.psychTestResume),
                            child: const Text('이전에 진행하던 테스트 이어하기'),
                          ),
                        ),
                      ],
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
                    label: '테스트 시작하기',
                    onPressed: () => context.pushNamed(AppRoute.psychTestBig5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideList extends StatelessWidget {
  const _GuideList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        IconInfoTile(
          icon: Icons.schedule_rounded,
          title: '50문항 · 약 10분',
          description: '답을 고르면 다음 문항으로 바로 넘어가요.',
        ),
        Divider(color: AppColors.divider, height: 1),
        IconInfoTile(
          icon: Icons.check_circle_outline_rounded,
          title: '정답은 없어요',
          description: '평소의 나와 가장 가까운 답을 골라주세요.',
        ),
        Divider(color: AppColors.divider, height: 1),
        IconInfoTile(
          icon: Icons.lock_outline_rounded,
          title: '답변은 이 기기에만 임시 저장해요',
          description: '완료하면 답변은 지우고 계산된 점수만 계정에 저장해요.',
        ),
        Divider(color: AppColors.divider, height: 1),
        IconInfoTile(
          icon: Icons.pause_circle_outline_rounded,
          title: '잠시 나가도 괜찮아요',
          description: '다시 들어오면 멈춘 문항부터 이어서 할 수 있어요.',
        ),
      ],
    );
  }
}
