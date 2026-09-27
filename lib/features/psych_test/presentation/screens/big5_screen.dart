import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/dummy/psych_test_dummy.dart';
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
    return PsychQuestionScreen(
      key: ValueKey(state.currentIndex),
      testTitle: 'Big 5 성격검사',
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
      onBack: state.canGoBack
          ? controller.previous
          : () {
              if (context.canPop()) context.pop();
            },
      isSaving: state.isSaving,
      nextLabel: state.isLastQuestion ? '결과 저장하기' : '다음',
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
        }
      },
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
