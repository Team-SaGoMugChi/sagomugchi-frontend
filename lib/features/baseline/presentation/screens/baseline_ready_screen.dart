import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../widgets/baseline_header.dart';

/// Screen 18 — Baseline 준비 체크. Environment checklist → 측정 중.
class BaselineReadyScreen extends StatefulWidget {
  const BaselineReadyScreen({super.key});

  @override
  State<BaselineReadyScreen> createState() => _BaselineReadyScreenState();
}

class _BaselineReadyScreenState extends State<BaselineReadyScreen> {
  final _checked = <int>{};
  static const _items = [
    (Icons.center_focus_strong_rounded, '얼굴은 화면 가운데', '휴대폰을 눈높이에 두세요.'),
    (Icons.light_mode_rounded, '얼굴 앞은 밝게', '등 뒤의 강한 빛은 피해주세요.'),
    (Icons.volume_off_rounded, '주변은 조용하게', '음악과 TV 소리를 줄여주세요.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: BaselineHeader(
                  title: '나의 기준 만들기',
                  stepLabels: ['안내', '준비', '측정'],
                  activeStep: 1,
                ),
              ),
              Expanded(
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
                      const Text('오또와 준비해볼까요?', style: AppTypography.display),
                      Gap.h8,
                      const Text(
                        '세 가지만 확인하면 시작할 수 있어요.',
                        style: AppTypography.bodySecondary,
                      ),
                      Gap.h20,
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _checked.length == _items.length
                              ? '좋아요. 이제 편하게 시작해요.'
                              : '준비된 항목에 체크해주세요.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySecondary,
                        ),
                      ),
                      Gap.h12,
                      OddoCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < _items.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  color: AppColors.divider,
                                  height: 1,
                                ),
                              CheckboxListTile(
                                key: ValueKey('baseline-ready-$i'),
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                secondary: Icon(
                                  _items[i].$1,
                                  color: AppColors.primary,
                                ),
                                title: Text(
                                  _items[i].$2,
                                  style: AppTypography.subtitle,
                                ),
                                subtitle: Text(
                                  _items[i].$3,
                                  style: AppTypography.bodySecondary,
                                ),
                                value: _checked.contains(i),
                                onChanged: (value) => setState(() {
                                  if (value == true) {
                                    _checked.add(i);
                                  } else {
                                    _checked.remove(i);
                                  }
                                }),
                              ),
                            ],
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
                  label: _checked.length == _items.length
                      ? '측정 시작하기'
                      : '준비 확인 ${_checked.length}/${_items.length}',
                  enabled: _checked.length == _items.length,
                  leadingIcon: Icons.videocam_rounded,
                  onPressed: () =>
                      context.pushNamed(AppRoute.baselineMeasuring),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
