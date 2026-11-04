import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 상단 제목 + 앞뒤 단계 이름. 지금 단계는 가운데에 진하게, 지난 단계는 왼쪽·다음 단계는 오른쪽에
/// 작고 흐리게 보여 줘서 단계를 넘어가는 느낌을 준다(예: 베이스라인 측정 → Big 5 성격검사).
/// 단계 표시줄(점·막대) 대신 쓴다.
class StepTitle extends StatelessWidget {
  const StepTitle({
    super.key,
    required this.title,
    this.previous,
    this.next,
    this.style,
  });

  final String title;

  /// 지난 단계 이름(왼쪽). null이면 비운다.
  final String? previous;

  /// 다음 단계 이름(오른쪽). null이면 비운다.
  final String? next;

  /// 가운데 제목 글꼴. 기본은 [AppTypography.subtitle].
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final side = AppTypography.caption.copyWith(color: AppColors.inactive);
    return Row(
      children: [
        Expanded(
          child: Text(
            previous ?? '',
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: side,
          ),
        ),
        Text(title, style: style ?? AppTypography.subtitle),
        Expanded(
          child: Text(
            next ?? '',
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: side,
          ),
        ),
      ],
    );
  }
}
