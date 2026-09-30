import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config_provider.dart';
import '../../../../data/dummy/diary_flow_dummy.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/chat_bubble.dart';
import '../../../../widgets/primary_button.dart';
import '../../application/diary_draft_provider.dart';
import '../../data/models/counsel_session.dart';
import '../../data/models/diary_interview.dart';
import '../widgets/diary_step_header.dart';

/// Screen 40 — Step 2. 대화 내용 보기. Step 1에서 탄카츄와 나눈 대화를 그대로
/// 보여주는 읽기 전용 화면 — 39번 "오늘의 일기"는 이 대화를 정제한 글이다.
///
/// (팀 결정으로 기존 "추가 질문 채팅"을 대신한다. 빠진 내용은 Step 1 대화가
/// 이미 묻는다.) 화면 시연용 더미 모드에서만 샘플 대화로 폴백한다.
class DiaryStep2ChatScreen extends ConsumerWidget {
  const DiaryStep2ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(diaryDraftProvider).interviewMessages;
    final useDummyData = ref.watch(appConfigProvider).useDummyData;
    final bubbles = messages.isNotEmpty
        ? [
            for (final m in messages)
              (fromOddo: m.speaker == InterviewSpeaker.oddo, text: m.text),
          ]
        : useDummyData
        ? [
            for (final m in DiaryFlowDummy.step2Chat)
              (fromOddo: m.speaker == CounselSpeaker.oddo, text: m.text),
          ]
        : const <({bool fromOddo, String text})>[];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const DiaryStepHeader(title: 'Step 2. 대화 내용', currentStep: 1),
              Expanded(
                child: bubbles.isEmpty
                    ? const Center(
                        child: Text(
                          '탄카츄와 나눈 대화가 없어요.',
                          style: AppTypography.bodySecondary,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          AppSpacing.md,
                          AppSpacing.screenH,
                          AppSpacing.md,
                        ),
                        children: [
                          for (final bubble in bubbles)
                            ChatBubble(
                              fromOddo: bubble.fromOddo,
                              text: bubble.text,
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                ),
                child: SafeArea(
                  top: false,
                  child: PrimaryButton(
                    label: '일기로 돌아가기',
                    onPressed: () {
                      if (context.canPop()) context.pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
