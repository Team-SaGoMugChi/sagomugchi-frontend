import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// 위기 안내에 띄우는 연락처 하나.
class CrisisContact {
  const CrisisContact(this.label, this.number);

  final String label;
  final String number;
}

/// 위험 축별 안내 문구와 연락처. 기준은 서버 docs/CRISIS_POLICY.md.
class CounselCrisisInfo {
  const CounselCrisisInfo({required this.message, required this.contacts});

  final String message;
  final List<CrisisContact> contacts;

  static const _suicide = CounselCrisisInfo(
    message: '지금은 전문가와 이야기하는 게 좋겠어요.\n'
        '자살예방 상담전화 109 · 24시간 연결돼요.',
    contacts: [CrisisContact('자살예방 109', '109')],
  );

  static CounselCrisisInfo forAxis(String? axis) {
    switch (axis) {
      case 'danger':
        return const CounselCrisisInfo(
          message: '지금 안전하지 않다면 몸을 먼저 지켜 주세요.\n'
              '말하기 어려우면 112에 문자로도 신고할 수 있어요.',
          contacts: [
            CrisisContact('112 긴급 신고', '112'),
            CrisisContact('여성긴급전화 1366', '1366'),
          ],
        );
      case 'harm_others':
        return const CounselCrisisInfo(
          message: '마음이 행동으로 이어질 것 같다면 잠시 그 자리에서 벗어나 주세요.\n'
              '정신건강위기상담전화가 24시간 이야기를 들어줘요.',
          contacts: [
            CrisisContact('정신건강위기상담 1577-0199', '15770199'),
            CrisisContact('112', '112'),
          ],
        );
      case 'psychosis':
        return const CounselCrisisInfo(
          message: '그 말을 따르지 않아도 괜찮아요.\n'
              '믿을 수 있는 사람 곁에 있어 주세요.',
          contacts: [
            CrisisContact('정신건강위기상담 1577-0199', '15770199'),
            CrisisContact('119', '119'),
          ],
        );
      default:
        // suicide, 또는 서버가 축을 보내지 않은 예전 응답.
        return _suicide;
    }
  }
}

/// 위기 발화 감지 시 안내 — 채팅·영상통화 상담이 함께 쓴다.
class CounselCrisisBanner extends StatelessWidget {
  const CounselCrisisBanner({
    super.key,
    this.riskAxis,
    this.margin = EdgeInsets.zero,
  });

  final String? riskAxis;
  final EdgeInsetsGeometry margin;

  Future<void> _call(String number) async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {
      // 전화 앱을 열 수 없어도 번호는 화면에 보인다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = CounselCrisisInfo.forAxis(riskAxis);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_rounded,
                  size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info.message,
                  style: AppTypography.bodySecondary.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final contact in info.contacts)
                OutlinedButton.icon(
                  onPressed: () => _call(contact.number),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: Text(contact.label),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.chip,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}