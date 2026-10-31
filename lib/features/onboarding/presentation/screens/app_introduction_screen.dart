import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/mascot_image.dart';
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
  int _page = 0;
  bool _replied = false;
  static const _samples = [
    '오늘은 산책하며 잠깐 쉬었어요. 바람이 시원해서 마음이 한결 가벼워졌어요.',
    '오늘의 감정: 편안함 · 뿌듯함\n하루 중 산책 시간이 작은 쉼표가 되었네요.\n내일도 잠깐 나를 위한 시간을 가져볼까요?',
    '잠깐 쉬어가는 시간이 도움이 되었군요. 그때 어떤 점이 가장 편안했나요?',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.pushNamed(AppRoute.personaIntro),
                child: const Text('건너뛰기'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: MediaQuery.sizeOf(context).height * .04),
                    if (_page == 0)
                      const Center(
                        child: MascotImage(pose: MascotPose.mic, size: 220),
                      ),
                    if (_page == 1)
                      const OddoCard(
                        child: Column(
                          children: [
                            _IntroSignal(
                              label: '목소리',
                              value: '평소와 비교해요',
                              progress: .65,
                            ),
                            Gap.h20,
                            _IntroSignal(
                              label: '표정',
                              value: '작은 변화를 살펴요',
                              progress: .45,
                            ),
                            Gap.h20,
                            _IntroSignal(
                              label: '말한 내용',
                              value: '마음을 함께 읽어요',
                              progress: .7,
                            ),
                          ],
                        ),
                      ),
                    if (_page == 2)
                      ClipRRect(
                        borderRadius: AppRadius.card,
                        child: Image.asset(
                          'assets/images/call_room_day.jpg',
                          height: 240,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Gap.h32,
                    Text(
                      [
                        '오늘 있었던 일을\n3분만 말해 주세요',
                        '목소리와 표정까지\n함께 읽어요',
                        '하루의 이야기가\n짧은 영상이 돼요',
                      ][_page],
                      style: AppTypography.display,
                    ),
                    Gap.h16,
                    Text(
                      [
                        '탄카츄가 질문을 던지면 편하게 대답해 주세요. 받아 적고 일기로 정리하는 건 오또가 할게요.',
                        '처음에 잰 평소 모습과 비교해 그날의 변화를 살펴봐요. 감정을 돌아보는 참고로 활용해 주세요.',
                        '그날 한 말로 장면을 만들어요. 다시 보고 싶은 날의 영상은 기록에서 볼 수 있어요.',
                      ][_page],
                      style: AppTypography.bodySecondary,
                    ),
                    if (_page == 1) ...[
                      Gap.h12,
                      const Text(
                        '이해를 돕기 위한 예시이며 실제 측정 결과가 아니에요.',
                        style: AppTypography.caption,
                      ),
                    ],
                    if (_page == 2) ...[
                      Gap.h24,
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text(
                          '샘플로 둘러보기',
                          style: AppTypography.bodySecondary,
                        ),
                        children: [
                          const Text(
                            '샘플 체험 · 녹음하거나 기록을 저장하지 않아요.',
                            style: AppTypography.caption,
                          ),
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              for (final (index, label) in [
                                '일기',
                                '리포트',
                                '상담',
                              ].indexed)
                                ChoiceChip(
                                  label: Text(label),
                                  selected: _tab == index,
                                  onSelected: (_) =>
                                      setState(() => _tab = index),
                                ),
                            ],
                          ),
                          OddoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(_samples[_tab], style: AppTypography.body),
                                if (_tab == 2) ...[
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _replied = true),
                                    child: const Text(
                                      '“천천히 걸을 수 있어서 좋았어요” 보내보기',
                                    ),
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
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [
                if (_page < 2)
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xxs),
                          child: Container(
                            width: i == _page ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? AppColors.primary
                                  : AppColors.primarySoftBorder,
                              borderRadius: AppRadius.chip,
                            ),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _page++),
                        child: const Text('다음'),
                      ),
                    ],
                  )
                else ...[
                  PrimaryButton(
                    label: '시작하기',
                    onPressed: () => context.pushNamed(AppRoute.personaIntro),
                  ),
                  SecondaryButton(
                    label: '이미 계정이 있어요',
                    onPressed: () => context.goNamed(AppRoute.login),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _IntroSignal extends StatelessWidget {
  const _IntroSignal({
    required this.label,
    required this.value,
    required this.progress,
  });
  final String label, value;
  final double progress;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(label, style: AppTypography.bodySecondary),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.body,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
      Gap.h12,
      LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        color: AppColors.primary,
        backgroundColor: AppColors.primarySoftBorder,
        borderRadius: AppRadius.chip,
      ),
    ],
  );
}
