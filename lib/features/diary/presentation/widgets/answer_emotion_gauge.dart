import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_typography.dart';
import '../../application/diary_interview_controller.dart';
import '../../data/models/diary_interview.dart';
import 'diary_interview_copy.dart';

/// 37번 좌상단 실시간 감정 표시 — 세로 게이지 하나와 감정 이름 하나.
///
/// 게이지는 이번 감정이 얼마나 뚜렷하게 인식됐는지(모델 근거 점수)이고, 이름은
/// 리포트와 같은 6종 라벨이다. 감정이 제대로 인식되고 있다는 것만 알려주고
/// 일기에 집중하도록 다른 정보는 띄우지 않는다. 답변마다 새 결과가 오면 막대가
/// 움직이고, 분석 중이거나 실패한 답변은 직전 결과를 그대로 둔다.
class AnswerEmotionGauge extends StatelessWidget {
  const AnswerEmotionGauge({super.key, required this.records});

  /// 질문을 받은 답변마다 하나씩, 답한 순서대로.
  final List<AnswerEmotionRecord> records;

  static const double _width = 12;
  static const double _height = 72;

  /// 분석이 끝난 가장 최근 답변. 아직 없으면 null.
  AnswerEmotion? get _latest {
    for (final record in records.reversed) {
      if (record.emotion != null) return record.emotion;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final emotion = latest?.dominantEmotion;
    final level = emotion == null ? 0.0 : latest!.confidence.clamp(0.0, 1.0);
    // 낮 배경에서도 읽히게 다른 통화 칩처럼 어두운 바탕 위에 올린다.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.callSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _width,
            height: _height,
            alignment: Alignment.bottomCenter,
            decoration: BoxDecoration(
              color: AppColors.callBackground,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: AnimatedContainer(
              key: const Key('emotion-gauge-fill'),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              width: _width,
              height: _height * level,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            emotion ?? DiaryInterviewCopy.emotionUnknown,
            style: AppTypography.caption.copyWith(
              color: AppColors.callTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
