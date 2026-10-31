import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/baseline/application/baseline_face_frames_provider.dart';
import '../../../../features/baseline/application/baseline_face_image_provider.dart';
import '../../../../features/baseline/application/baseline_recording_provider.dart';
import '../../../../features/diary/data/diary_providers.dart';
import '../../../../features/onboarding/application/onboarding_controller.dart';
import '../../../../features/records/application/recorded_days_provider.dart';
import '../../../../features/records/application/viewing_date_provider.dart';
import '../../../../features/records/presentation/screens/shortform_player_screen.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/diary_bottom_nav.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/oddo_chip.dart';
import '../../../../widgets/primary_button.dart';
import '../widgets/baseline_needed_dialog.dart';
import '../widgets/diary_start_modal.dart';
import '../widgets/home_header.dart';
import '../widgets/weekly_calendar.dart';

/// Screens 7 & 47 — 홈. One interactive component: the weekly bar re-centers on
/// the selected date (held in [viewingDateProvider]) and the main card switches
/// by whether that date has a diary record. Written day → video card +
/// [일기][리포트][상담] tab bar; not-written → the "write a diary" CTA card.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Before onboarding, auto-open the first-measurement popup once on entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(onboardingCompleteProvider)) {
        _showBaselineDialog();
      }
    });
  }

  void _onWritePressed(bool onboarded, DateTime date) {
    if (onboarded) {
      showDiaryStartModal(context, ref, date: date);
    } else {
      _showBaselineDialog();
    }
  }

  void _showBaselineDialog() {
    final hasPendingMeasurement =
        ref.read(baselineRecordingProvider) != null &&
        (ref.read(baselineFaceImageProvider) != null ||
            ref.read(baselineFaceFramesProvider).isNotEmpty);
    showBaselineNeededDialog(
      context,
      hasPendingMeasurement: hasPendingMeasurement,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(viewingDateProvider);
    final onboarded = ref.watch(onboardingCompleteProvider);
    final recorded = ref.watch(recordedDaysProvider);
    final written = recorded.contains(
      DateTime(selected.year, selected.month, selected.day),
    );
    final start = DateTime(
      selected.year,
      selected.month,
      selected.day,
    ).subtract(Duration(days: selected.weekday % 7));
    final weekDays = List.generate(7, (i) => start.add(Duration(days: i)));
    final recent =
        recorded
            .where(
              (d) => d.isBefore(
                DateTime(selected.year, selected.month, selected.day),
              ),
            )
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final weekCount = recorded
        .where(
          (d) =>
              !d.isBefore(start) &&
              d.isBefore(start.add(const Duration(days: 7))),
        )
        .length;
    return Scaffold(
      bottomNavigationBar: DiaryBottomNav(
        currentIndex: 0,
        onSelect: (i) {
          if (i == 1) context.goNamed(AppRoute.monthlyCalendar);
          if (i == 2) context.goNamed(AppRoute.recordsCounsel);
          if (i == 3) context.goNamed(AppRoute.myPage);
        },
      ),
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              HomeHeader(month: selected),
              Gap.h12,
              Text(
                DateFormatter.monthDay(selected),
                style: AppTypography.caption,
              ),
              Gap.h8,
              Text(
                written ? '오늘 남긴 이야기' : '오늘 일기는 아직이에요',
                style: AppTypography.title,
              ),
              Gap.h24,
              WeeklyCalendar(
                days: weekDays,
                today: DateTime.now(),
                selected: selected,
                recordedDays: recorded,
                onSelect: (d) => ref.read(viewingDateProvider.notifier).set(d),
              ),
              Gap.h24,
              if (written) ...[
                _HomeCardShell(
                  child: _WrittenContent(
                    date: selected,
                    onReadDiary: () => context.goNamed(AppRoute.recordsDiary),
                  ),
                ),
                Gap.h16,
                OddoCard(
                  color: AppColors.backgroundAlt,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '조금 더 이야기하고 싶다면',
                          style: AppTypography.body,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.goNamed(AppRoute.recordsCounsel),
                        child: const Text('상담'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                OddoCard(
                  child: Row(
                    children: [
                      const MascotImage(pose: MascotPose.writing, size: 72),
                      Gap.w16,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weekCount == 0
                                  ? '오늘의 이야기를 들려주세요'
                                  : '이번 주 $weekCount일 썼어요',
                              style: AppTypography.subtitle,
                            ),
                            Gap.h4,
                            const Text(
                              '말로 남기면 한 편의 일기가 돼요.',
                              style: AppTypography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.h16,
                PrimaryButton(
                  label: '오늘 일기 말하기',
                  leadingIcon: Icons.mic_none_rounded,
                  onPressed: () => _onWritePressed(onboarded, selected),
                ),
              ],
              Gap.h24,
              const Text('최근 기록', style: AppTypography.caption),
              Gap.h8,
              if (recent.isEmpty)
                const OddoCard(
                  child: Text(
                    '아직 기록이 없어요. 첫 이야기를 남겨 보세요.',
                    style: AppTypography.bodySecondary,
                  ),
                )
              else
                OddoCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < recent.take(3).length; i++) ...[
                        if (i > 0) const Divider(),
                        _RecentEntry(date: recent[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentEntry extends ConsumerWidget {
  const _RecentEntry({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(diaryEntryProvider(date)).value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(DateFormatter.monthDay(date), style: AppTypography.body),
      subtitle: entry == null || entry.emotionKeywords.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Wrap(
                spacing: AppSpacing.xxs,
                children: entry.emotionKeywords
                    .take(2)
                    .map((e) => OddoChip(label: e))
                    .toList(),
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
      ),
      onTap: () {
        ref.read(viewingDateProvider.notifier).set(date);
        context.goNamed(AppRoute.recordsDiary);
      },
    );
  }
}

/// 홈 영상 카드의 그림 — 대표 장면 썸네일, 없으면 마스코트.
class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.url});

  final String? url;

  static const _mascot = Center(
    child: MascotImage(pose: MascotPose.writing, size: 96, onDark: true),
  );

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) return _mascot;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _mascot,
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null ? child : _mascot,
    );
  }
}

/// Written state — recorded-day card content with the generated video +
/// read button.
class _WrittenContent extends ConsumerWidget {
  const _WrittenContent({required this.date, required this.onReadDiary});

  final DateTime date;
  final VoidCallback onReadDiary;

  /// 그날 보관된 영상(Firebase Storage)을 재생한다. 없으면 플레이어가 안내한다.
  Future<void> _openVideo(BuildContext context, WidgetRef ref) async {
    final url = await ref.read(savedVideoUrlProvider(date).future);
    final subtitles = url == null
        ? null
        : await ref.read(savedVideoSubtitlesUrlProvider(date).future);
    if (!context.mounted) return;
    unawaited(
      context.pushNamed(
        AppRoute.shortformPlayer,
        extra: ShortformVideo(videoUrl: url, subtitlesUrl: subtitles),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(diaryEntryProvider(date)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormatter.monthDay(date),
          style: AppTypography.title.copyWith(color: AppColors.primary),
        ),
        Gap.h4,
        const Text(
          '기록한 일기와 영상을 다시 볼 수 있어요.',
          style: AppTypography.bodySecondary,
        ),
        if (entry != null) ...[
          Gap.h16,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: entry.emotionKeywords
                .map((e) => OddoChip(label: e))
                .toList(),
          ),
          Gap.h12,
          Text(entry.summary, style: AppTypography.body),
          TextButton(
            onPressed: () => context.goNamed(AppRoute.recordsReport),
            child: const Text('리포트 보기'),
          ),
        ],
        Gap.h16,
        GestureDetector(
          onTap: () => _openVideo(context, ref),
          child: ClipRRect(
            borderRadius: AppRadius.card,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.callBackground),
                  // 그날 영상의 대표 장면 썸네일(가로 16:9). 없거나 못 불러오면 마스코트.
                  _VideoThumbnail(
                    url: ref.watch(savedVideoThumbnailUrlProvider(date)).value,
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Gap.h16,
        GestureDetector(
          onTap: onReadDiary,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: AppRadius.button,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '작성한 일기 읽기',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared white rounded card shell for both home states.
class _HomeCardShell extends StatelessWidget {
  const _HomeCardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
