import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/dummy/dummy_seed.dart';
import '../../../../features/records/application/recorded_days_provider.dart';
import '../../../../features/records/application/viewing_date_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/card_section_header.dart';
import '../../../../widgets/help_sheet.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../../application/counsel_controller.dart';
import '../../application/counsel_report_controller.dart';
import '../../application/diary_draft_provider.dart';
import '../../data/diary_providers.dart';
import '../../data/models/counsel_report.dart';
import '../../data/models/counsel_session.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/emotion_report.dart';
import '../../data/models/fusion_result.dart';

/// Screen 46 — 상담 후 감정 리포트·행동 가이드. Tabbed (감정 리포트 / 행동
/// 가이드). The re-viewable report for a written date. → 홈 작성일.
class ReportGuideScreen extends ConsumerStatefulWidget {
  const ReportGuideScreen({super.key});

  @override
  ConsumerState<ReportGuideScreen> createState() => _ReportGuideScreenState();
}

class _ReportGuideScreenState extends ConsumerState<ReportGuideScreen> {
  int _tab = 0;
  bool _saving = false;

  /// Saves the completed run (diary + report + counsel log) under the focused
  /// date, then returns to the written-day home.
  ///
  /// Step1 처리에서 받은 서버 분석 결과(`fusionResult`)가 있으면 감정 키워드·
  /// 강도·분포는 그 실데이터로 저장하고, 없으면(분석 실패/더미 모드) 샘플로
  /// 폴백한다 — Step2 확인 화면과 같은 규칙.
  ///
  /// 상담 로그는 Step4에서 주고받은 실제 대화(draft.counselMessages)를 저장하고,
  /// 리포트 코멘트·행동 가이드는 45번에서 만든 상담 리포트에서 가져온다.
  Future<void> _completeRecord() async {
    final writtenDate = ref.read(viewingDateProvider);
    final draft = ref.read(diaryDraftProvider);
    final transcript = draft.transcript ?? DummySeed.diaryJan14.transcript;
    final fusion = draft.fusionResult;
    final sampleEntry = DummySeed.diaryJan14;
    final now = DateTime.now();

    final entry = DiaryEntry(
      id: DateFormatter.dateKey(writtenDate),
      date: writtenDate,
      transcript: transcript,
      summary: sampleEntry.summary,
      emotionKeywords: fusion?.emotionKeywords ?? sampleEntry.emotionKeywords,
      emotionIntensity:
          fusion?.emotionIntensity ?? sampleEntry.emotionIntensity,
      emotionStability: sampleEntry.emotionStability,
      writtenAt: now,
    );
    // 화면에 보여준 것과 같은 값으로 저장한다.
    final report = _composeReport(
      counsel: ref.read(counselReportControllerProvider).report,
      fusion: fusion,
      date: writtenDate,
    );
    final counsel = CounselSession(
      date: writtenDate,
      // Step4에서 실제로 주고받은 대화. 상담을 건너뛰었으면 빈 목록으로
      // 저장된다(샘플로 채우지 않는다).
      startedAt: draft.counselStartedAt ?? now,
      endedAt: now,
      messages: draft.counselMessages,
    );

    setState(() => _saving = true);
    try {
      await ref
          .read(diaryRepositoryProvider)
          .saveRecord(entry: entry, report: report, counsel: counsel);
      ref.read(recordedDaysProvider.notifier).markRecorded(writtenDate);
      ref.read(diaryDraftProvider.notifier).clear();
      // 다음 상담은 빈 대화에서 시작한다(저장된 기록은 이어하기로 불러온다).
      ref.invalidate(counselControllerProvider);
      // 다음 상담이 끝나면 리포트를 새로 만든다.
      ref.invalidate(counselReportControllerProvider);
      // 방금 저장한 날짜의 기록 화면들이 새 데이터를 읽도록 캐시 무효화.
      ref.invalidate(diaryEntryProvider(writtenDate));
      ref.invalidate(emotionReportProvider(writtenDate));
      ref.invalidate(counselSessionProvider(writtenDate));
      if (mounted) context.goNamed(AppRoute.homeWritten);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 화면에 보여주고 저장할 리포트를 만든다.
  ///
  /// 감정 분포·강도는 Step2 분석에서, 글은 상담 리포트에서 온다. 둘 중 없는
  /// 쪽은 샘플로 폴백한다 — Step2 확인 화면과 같은 규칙.
  ///
  /// TODO(고도화): moments·reframe은 아직 화면에만 쓰고 저장하지 않는다.
  /// EmotionReport에 자리를 만들면 같이 저장한다.
  EmotionReport _composeReport({
    required CounselReport? counsel,
    required FusionResult? fusion,
    required DateTime date,
  }) {
    final sample = DummySeed.reportJan14;

    final comment = counsel == null
        ? sample.analysisComment
        : [
            counsel.summary,
            counsel.closing,
          ].where((s) => s.isNotEmpty).join('\n\n');

    final guides = counsel == null || counsel.suggestion.isEmpty
        ? sample.behaviorGuides
        : [counsel.suggestion, ...sample.behaviorGuides];

    return EmotionReport(
      date: date,
      emotionDistribution: fusion != null
          ? _toDistribution(fusion.emotionScores)
          : sample.emotionDistribution,
      emotionIntensity: fusion?.emotionIntensity ?? sample.emotionIntensity,
      recoveryPossibility: sample.recoveryPossibility,
      analysisComment: comment,
      behaviorGuides: guides,
      recommendedActivities: sample.recommendedActivities,
    );
  }

  /// 서버 `emotion_scores`는 0–100, Firestore `emotionDistribution`은 감정 →
  /// 비율(0–1)이라(FIRESTORE_SCHEMA.md §3) 스케일을 맞춰 저장한다.
  static Map<String, double> _toDistribution(Map<String, double> scores) =>
      scores.map((key, value) => MapEntry(key, value / 100));

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(counselReportControllerProvider);
    final counsel = reportState.report;
    final draft = ref.watch(diaryDraftProvider);
    final report = _composeReport(
      counsel: counsel,
      fusion: draft.fusionResult,
      date: ref.watch(viewingDateProvider),
    );

    // 상담을 아예 안 했으면 실패 배너를 띄우지 않는다 — 실패가 아니라 해당 없음.
    final showFailure = reportState.failed && draft.counselMessages.isNotEmpty;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () {
                      if (context.canPop()) context.pop();
                    },
                  ),
                  const Expanded(
                    child: Text('감정 리포트',
                        textAlign: TextAlign.center,
                        style: AppTypography.subtitle),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded, size: 20),
                    onPressed: () => showHelpSheet(
                      context,
                      title: '감정 리포트 도움말',
                      items: const [
                        '상담 내용을 바탕으로 만든 오늘의 감정 분석이에요.',
                        '행동 가이드 탭에서 실천할 수 있는 제안을 볼 수 있어요.',
                        '기록 완료하기를 누르면 이 날짜에 저장돼요.',
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                      AppSpacing.sm, AppSpacing.screenH, AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          // TODO: 작은 차트를 들고 있는 포즈로 교체 예정
                          const MascotImage(pose: MascotPose.heart, size: 84),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  counsel?.headline ??
                                      '오늘 상담을 통해\n나의 감정을 더 잘 이해했어요',
                                  style: AppTypography.subtitle,
                                ),
                                Gap.h8,
                                const Text(
                                  '상담 내용을 바탕으로 감정 상태와 행동 가이드를 정리했어요.',
                                  style: AppTypography.bodySecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (reportState.generating) ...[
                        Gap.h16,
                        const _ReportStatusCard.loading(),
                      ] else if (showFailure) ...[
                        Gap.h16,
                        _ReportStatusCard.failed(
                          onRetry: () => ref
                              .read(counselReportControllerProvider.notifier)
                              .retry(),
                        ),
                      ],
                      Gap.h16,
                      _TabToggle(
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i)),
                      Gap.h16,
                      if (_tab == 0)
                        _ReportTab(report: report, counsel: counsel)
                      else
                        _GuideTab(report: report),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                    AppSpacing.xs, AppSpacing.screenH, AppSpacing.xs),
                child: PrimaryButton(
                  label: '기록 완료하기',
                  loading: _saving,
                  onPressed: _completeRecord,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 리포트 생성 상태 안내. 생성 중이거나 실패했을 때만 뜬다.
///
/// 실패해도 아래 카드들은 샘플로 채워져 있어 화면이 비지는 않는다 — 그래서
/// 에러 화면으로 덮지 않고 배너로만 알린다.
class _ReportStatusCard extends StatelessWidget {
  const _ReportStatusCard.loading() : onRetry = null;
  const _ReportStatusCard.failed({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final loading = onRetry == null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          else
            const Icon(Icons.error_outline_rounded,
                size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loading
                  ? '상담 내용을 정리하고 있어요.'
                  : '상담 리포트를 만들지 못했어요. 아래 내용은 예시예요.',
              style: AppTypography.caption,
            ),
          ),
          if (!loading)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('다시 시도',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = ['감정 리포트', '행동 가이드'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: index == i ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _labels[i],
                    style: AppTypography.bodySecondary.copyWith(
                      color: index == i
                          ? AppColors.textOnPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportTab extends StatelessWidget {
  const _ReportTab({required this.report, this.counsel});
  final EmotionReport report;

  /// 상담 리포트. 없으면(상담 건너뜀·생성 실패) 관련 카드를 숨긴다.
  final CounselReport? counsel;

  @override
  Widget build(BuildContext context) {
    final moments = counsel?.moments ?? const <String>[];
    final reframe = counsel?.reframe ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OddoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardSectionHeader(
                  icon: Icons.pie_chart_outline_rounded, title: '오늘의 감정 요약'),
              Gap.h12,
              for (final e in report.emotionDistribution.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EmotionRow(name: e.key, value: e.value),
                ),
              const Divider(color: AppColors.divider, height: 20),
              Row(
                children: [
                  Expanded(
                      child: _StatTile(
                          label: '감정 강도', value: report.emotionIntensity)),
                  Gap.w12,
                  Expanded(
                      child: _StatTile(
                          label: '회복 가능성', value: report.recoveryPossibility)),
                ],
              ),
            ],
          ),
        ),
        Gap.h12,
        const OddoCard(child: _ChangeChart()),
        Gap.h12,
        OddoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardSectionHeader(
                  icon: Icons.auto_awesome_rounded, title: 'AI 분석 코멘트'),
              Gap.h8,
              Text(report.analysisComment, style: AppTypography.body),
            ],
          ),
        ),
        if (moments.isNotEmpty) ...[
          Gap.h12,
          OddoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardSectionHeader(
                    icon: Icons.lightbulb_outline_rounded, title: '오늘 알아차린 것'),
                Gap.h8,
                for (final m in moments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(Icons.circle,
                              size: 5, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m, style: AppTypography.body)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (reframe.isNotEmpty) ...[
          Gap.h12,
          OddoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardSectionHeader(
                    icon: Icons.swap_horiz_rounded, title: '다르게 보기'),
                Gap.h8,
                Text(reframe, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GuideTab extends StatelessWidget {
  const _GuideTab({required this.report});
  final EmotionReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OddoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardSectionHeader(
                  icon: Icons.flag_outlined, title: '오늘의 행동 가이드'),
              Gap.h12,
              for (var i = 0; i < report.behaviorGuides.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NumberedItem(
                      number: i + 1, text: report.behaviorGuides[i]),
                ),
            ],
          ),
        ),
        Gap.h12,
        OddoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardSectionHeader(
                  icon: Icons.spa_outlined, title: '추천 활동'),
              Gap.h12,
              for (final activity in report.recommendedActivities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(activity, style: AppTypography.body),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmotionRow extends StatelessWidget {
  const _EmotionRow({required this.name, required this.value});
  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 52, child: Text(name, style: AppTypography.bodySecondary)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: AppColors.primarySoftBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text('${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: AppTypography.caption
                  .copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: 2),
          Text('$value',
              style: AppTypography.subtitle.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

/// Simple 상담 전 → 중 → 후 mini bar chart (속상함 낮아짐).
class _ChangeChart extends StatelessWidget {
  const _ChangeChart();

  static const List<(String, double)> _points = [
    ('상담 전', 0.85),
    ('상담 중', 0.65),
    ('상담 후', 0.42),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CardSectionHeader(
            icon: Icons.show_chart_rounded, title: '감정 변화'),
        Gap.h16,
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final p in _points)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 28,
                        height: 70 * p.$2,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(p.$1, style: AppTypography.caption),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Gap.h8,
        const Text('상담을 지나며 속상함이 조금씩 가라앉았어요.',
            style: AppTypography.caption),
      ],
    );
  }
}

class _NumberedItem extends StatelessWidget {
  const _NumberedItem({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$number',
              style: AppTypography.caption.copyWith(
                  color: AppColors.textOnPrimary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTypography.body)),
      ],
    );
  }
}
