import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/icon_info_tile.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../widgets/counsel_mode_sheet.dart';
import '../widgets/diary_step_header.dart';

/// Screen 43 — Step 4. 상담 시작 안내. → 영상통화 또는 채팅 상담.
class DiaryStep4CounselIntroScreen extends StatelessWidget {
  const DiaryStep4CounselIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const DiaryStepHeader(currentStep: 3),
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          // TODO: 상담사처럼 앉아 손 흔드는 포즈로 교체 예정
                          MascotImage(pose: MascotPose.counselor, size: 110),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('영상 잘 보셨나요?', style: AppTypography.title),
                                Gap.h8,
                                Text(
                                  '이제 탄카츄와 함께\n이야기를 나눌 시간이에요.',
                                  style: AppTypography.bodySecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Gap.h20,
                      OddoCard(
                        child: Column(
                          children: [
                            IconInfoTile(
                              icon: Icons.videocam_rounded,
                              title: '영상통화나 채팅 중에 고를 수 있어요',
                              description: '지금 편한 쪽으로 이야기하면 돼요.',
                            ),
                            Divider(color: AppColors.divider, height: 1),
                            IconInfoTile(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: '편하게 이야기해도 좋아요',
                              description: '어떤 감정이든, 궁금한 점이든 부담 없이 털어놓아도 돼요.',
                            ),
                            Divider(color: AppColors.divider, height: 1),
                            IconInfoTile(
                              icon: Icons.favorite_outline_rounded,
                              title: '안전하고 따뜻한 공간이에요',
                              description: '네 이야기는 소중하게 지켜질 거예요.',
                            ),
                          ],
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
                  label: '상담 시작하기',
                  leadingIcon: Icons.chat_rounded,
                  onPressed: () => showCounselModeSheet(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
