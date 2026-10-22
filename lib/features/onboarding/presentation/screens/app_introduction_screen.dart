import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';

/// Local samples only: exploring never creates a diary or starts recording.
class AppIntroductionScreen extends StatefulWidget {
  const AppIntroductionScreen({super.key});

  @override
  State<AppIntroductionScreen> createState() => _AppIntroductionScreenState();
}

class _AppIntroductionScreenState extends State<AppIntroductionScreen> {
  int _tab = 0;
  bool _replied = false;
  static const _samples = [
    '오늘은 산책하며 잠깐 쉬었어요. 바람이 시원해서 마음이 한결 가벼워졌어요.',
    '오늘의 감정: 편안함 · 뿌듯함\n하루 중 산책 시간이 작은 쉼표가 되었네요.\n내일도 잠깐 나를 위한 시간을 가져볼까요?',
    '잠깐 쉬어가는 시간이 도움이 되었군요. 그때 어떤 점이 가장 편안했나요?',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Oddo 만나보기')),
    body: AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            const Text('하루를 이야기하고,\n내 마음을 돌아봐요.', style: AppTypography.display),
            Gap.h12,
            const Text(
              'Oddo는 이야기를 일기로 정리하고, 감정 리포트와 상담으로 하루를 돌아보는 앱이에요.',
              style: AppTypography.bodySecondary,
            ),
            Gap.h24,
            const Text('화면을 눌러 가볍게 둘러보세요', style: AppTypography.subtitle),
            Gap.h8,
            const Text(
              '샘플 체험 · 녹음하거나 기록을 저장하지 않아요.',
              style: AppTypography.caption,
            ),
            Gap.h12,
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final (index, label) in ['일기', '리포트', '상담'].indexed)
                  ChoiceChip(
                    label: Text(label),
                    selected: _tab == index,
                    onSelected: (_) => setState(() => _tab = index),
                  ),
              ],
            ),
            Gap.h12,
            OddoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_samples[_tab], style: AppTypography.body),
                  if (_tab == 2) ...[
                    Gap.h12,
                    TextButton(
                      onPressed: () => setState(() => _replied = true),
                      child: const Text('“천천히 걸을 수 있어서 좋았어요” 보내보기'),
                    ),
                    if (_replied)
                      const Text(
                        '내 속도로 움직이는 시간이 소중했군요. 그런 시간을 조금씩 이어가도 좋아요.',
                        style: AppTypography.bodySecondary,
                      ),
                  ],
                ],
              ),
            ),
            Gap.h24,
            const Text(
              '다음에는 나와 대화할 친구를 고르고, 평소 목소리와 표정을 알아보기 위해 짧은 문장을 읽을 거예요.',
              style: AppTypography.bodySecondary,
            ),
            Gap.h20,
            PrimaryButton(
              label: '대화할 친구 설정하기',
              onPressed: () => context.pushNamed(AppRoute.personaIntro),
            ),
          ],
        ),
      ),
    ),
  );
}
