import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../widgets/baseline_companion.dart';
import '../widgets/baseline_header.dart';

/// Screen 18 — Baseline 준비 체크. Environment checklist → 측정 중.
class BaselineReadyScreen extends StatefulWidget {
  const BaselineReadyScreen({super.key});

  @override
  State<BaselineReadyScreen> createState() => _BaselineReadyScreenState();
}

class _BaselineReadyScreenState extends State<BaselineReadyScreen> {
  final _checked = <int>{};
  int? _expanded;
  static const _details = [
    '화면을 정면으로 보고 눈·코·입이 모두 보이게 해주세요. 휴대폰을 세워두면 더 편하게 읽을 수 있어요.',
    '창문이나 조명이 얼굴 앞쪽에 오게 앉아주세요. 얼굴 뒤가 너무 밝으면 표정을 기록하기 어려워요.',
    '음악과 TV를 잠시 줄이고, 휴대폰을 입 가까이 가져가지 않아도 들릴 정도로 편하게 읽어주세요.',
  ];
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
                      SizedBox(
                        height: 120,
                        child: BaselineCompanion(
                          ready: _checked.length == _items.length,
                        ),
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _checked.length == _items.length
                              ? '좋아요. 이제 편하게 시작해요.'
                              : '준비하면서 궁금한 항목은 펼쳐보세요.',
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

                                value: _checked.contains(i),
                                onChanged: (value) => setState(() {
                                  if (value == true) {
                                    _checked.add(i);
                                  } else {
                                    _checked.remove(i);
                                  }
                                }),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.xxxl,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    key: ValueKey('baseline-help-$i'),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _expanded = _expanded == i ? null : i,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _items[i].$3,
                                            style: AppTypography.bodySecondary,
                                          ),
                                        ),
                                        Icon(
                                          _expanded == i
                                              ? Icons.expand_less_rounded
                                              : Icons.expand_more_rounded,
                                          size: AppSpacing.lg,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_expanded == i)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.sm,
                                    0,
                                    AppSpacing.sm,
                                    AppSpacing.md,
                                  ),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _details[i],
                                      style: AppTypography.bodyLarge,
                                    ),
                                  ),
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
