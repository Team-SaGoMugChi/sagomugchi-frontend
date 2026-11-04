import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/dummy/psych_test_dummy.dart';
import '../../../onboarding/application/onboarding_controller.dart';
import '../../application/big5_controller.dart';
import '../../domain/ipip_big5.dart';
import '../widgets/psych_question_screen.dart';

/// Screen 24 — Big 5 질문 진행 (5-point Likert). → MBTI.
class Big5Screen extends ConsumerWidget {
  const Big5Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(big5ControllerProvider);
    final controller = ref.read(big5ControllerProvider.notifier);
    final item = ipipBig5Items[state.currentIndex];
    final onboarding = !ref.watch(onboardingCompleteProvider);
    // 시스템 뒤로가기는 이전 문항으로 간다. 첫 문항에서는 온보딩 중이면 막는다(안내 화면으로 돌아가지 않는다).
    return PopScope(
      canPop: !state.canGoBack && !onboarding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.canGoBack) controller.previous();
      },
      child: PsychQuestionScreen(
        key: ValueKey(state.currentIndex),
        testTitle: 'Big 5 성격검사',
        previousStep: '베이스라인',
        journeyIndex: 1,
        questionNumber: state.currentIndex + 1,
        totalQuestions: ipipBig5Items.length,
        question: PsychQuestion(item.text, _responseOptions),
        layout: PsychOptionLayout.likert,
        hint: '평소의 나를 기준으로 답해주세요. 이 검사는 자기이해를 돕는 도구이며 진단이 아니에요.',
        // TODO: 손 흔들며 응원하는 포즈로 교체 예정
        mascotPose: MascotPose.waving,
        initialSelected: state.selectedAnswer == null
            ? null
            : state.selectedAnswer! - 1,
        onSelected: (index) => controller.selectAnswer(index + 1),
        // 답을 고르면 다음 문항으로 바로 넘어간다. 마지막 문항에서만 결과 저장하기 버튼이 나온다.
        autoAdvance: true,
        onPrevious: state.canGoBack ? controller.previous : null,
        isSaving: state.isSaving,
        nextLabel: '결과 저장하기',
        onNext: () async {
          final completed = await controller.next();
          if (!context.mounted) return;
          final error = ref.read(big5ControllerProvider).errorMessage;
          if (error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error)));
          } else if (completed) {
            context.pushReplacementNamed(AppRoute.psychTestDone);
          } else if (state.isLastQuestion && controller.goToFirstUnanswered()) {
            // 앞에 답하지 않은 문항이 있으면 저장되지 않는다 — 그 문항으로 데려간다.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('답하지 않은 문항이 있어요. 그 문항부터 이어서 답해주세요.'),
              ),
            );
          }
        },
      ),
    );
  }
}

const _responseOptions = [
  PsychOption('전혀 그렇지 않다'),
  PsychOption('그렇지 않다'),
  PsychOption('보통이다'),
  PsychOption('그렇다'),
  PsychOption('매우 그렇다'),
];
