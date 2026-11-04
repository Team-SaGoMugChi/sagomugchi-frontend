import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/storage/local_store.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/baseline/application/baseline_face_frames_provider.dart';
import '../../../../features/baseline/application/baseline_face_image_provider.dart';
import '../../../../features/baseline/application/baseline_recording_provider.dart';
import '../../../../features/diary/application/diary_draft_provider.dart';
import '../../../../features/diary/application/pending_diary_provider.dart';
import '../../../../features/diary/application/video_job_controller.dart';
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
      // 영상을 기다리던 일기가 있으면(앱을 다시 켠 경우 포함) 진행 상태를 다시 확인한다.
      if (mounted) {
        unawaited(ref.read(videoJobControllerProvider.notifier).resume());
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
      introFilmSeen: ref
          .read(localStoreProvider)
          .getBool(LocalStore.kIntroFilmSeen),
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
    // 7-day strip centered on the selected date (selected in the middle).
    final weekDays = List.generate(
      7,
      (i) => DateTime(selected.year, selected.month, selected.day + i - 3),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = DateUtils.isSameDay(selected, today);
    final isFuture = selected.isAfter(today);
    final pending = ref.watch(pendingDiaryProvider);
    final waiting = !written && pending != null && pending.isFor(selected);
    return Scaffold(
      // 작성일에만 [일기][리포트][상담] 탭바가 보인다.
      bottomNavigationBar: written
          ? DiaryBottomNav(
              currentIndex: 0,
              onSelect: (i) {
                if (i == 1) context.goNamed(AppRoute.recordsReport);
                if (i == 2) context.goNamed(AppRoute.recordsCounsel);
              },
            )
          : null,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              HomeHeader(date: selected),
              Gap.h16,
              WeeklyCalendar(
                days: weekDays,
                today: DateTime.now(),
                selected: selected,
                recordedDays: recorded,
                onSelect: (d) => ref.read(viewingDateProvider.notifier).set(d),
              ),
              Gap.h24,
              // 다른 날짜를 보고 있어도 마무리하지 않은 일기가 있다는 걸 알린다
              // (앱을 다시 켜면 홈은 오늘로 열린다).
              if (pending != null && !pending.isFor(selected)) ...[
                OddoCard(
                  color: AppColors.backgroundAlt,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${DateFormatter.monthDay(pending.date)} 일기가 남아 있어요',
                          style: AppTypography.body,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(viewingDateProvider.notifier)
                            .set(pending.date),
                        child: const Text('보러 가기'),
                      ),
                    ],
                  ),
                ),
                Gap.h16,
              ],
              // 탄카츄(빼꼼 포즈)가 카드 윗변을 두 손으로 잡고 있는 홈 메인 카드.
              _PeekingCard(
                child: written
                    ? _WrittenContent(
                        date: selected,
                        onReadDiary: () =>
                            context.goNamed(AppRoute.recordsDiary),
                      )
                    : waiting
                    ? _PendingContent(pending: pending)
                    : isFuture
                    ? const _CardMessage(
                        title: '그날이 오면 만나요',
                        body: '이날이 되면 이야기를 남길 수 있어요.',
                      )
                    // 큰 제목을 없애고 그 문구를 카드 제목으로 옮겼다(화면 위 공간을 줄이려고).
                    : _EmptyDayContent(
                        isToday: isToday,
                        onWrite: () => _onWritePressed(onboarded, selected),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 영상을 기다리는 일기의 홈 카드. 진행률을 보여주고, 완성되면 영상을 본 뒤
/// 상담으로 이어 가게 한다(영상을 먼저 봐야 상담이 의미 있다).
class _PendingContent extends ConsumerWidget {
  const _PendingContent({required this.pending});

  final PendingDiary pending;

  void _continue(BuildContext context, WidgetRef ref, bool done) {
    // 앱을 다시 켰으면 작성 내용이 메모리에 없다 — 휴대폰에 남긴 값으로 되돌린다.
    if (ref.read(diaryDraftProvider).transcript != pending.draft.transcript) {
      ref.read(diaryDraftProvider.notifier).restore(pending.draft);
    }
    ref.read(viewingDateProvider.notifier).set(pending.date);
    context.pushNamed(
      done ? AppRoute.diaryStep3VideoDone : AppRoute.diaryStep3VideoLoading,
    );
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('이 일기를 지울까요?', style: AppTypography.subtitle),
        content: const Text(
          '정리한 일기와 만들던 영상이 기록에 남지 않아요.',
          style: AppTypography.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // 기다리던 일기를 지우면 이 카드가 사라진다(ref도 함께) — 영상 상태부터 비운다.
    ref.read(diaryDraftProvider.notifier).clear();
    ref.invalidate(videoJobControllerProvider);
    await ref.read(pendingDiaryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final video = ref.watch(videoJobControllerProvider);
    final job = video.job;
    final mine = job?.jobId == pending.jobId;
    final done = mine && video.isDone;
    final failed = mine && video.isFailed;
    final percent = mine ? (job!.progress * 100).floor() : 0;
    final title = done
        ? '영상이 완성됐어요'
        : failed
        ? '영상을 완성하지 못했어요'
        : '영상을 만들고 있어요 · $percent%';
    final body = done
        ? '영상을 먼저 보고, 탄카츄와 상담을 이어서 해요.'
        : failed
        ? '다시 만들어야 영상을 보고 상담을 이어서 할 수 있어요.'
        : '다 만들어지면 여기에서 이어서 할 수 있어요.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: AppTypography.subtitle),
        Gap.h4,
        Text(body, style: AppTypography.bodySecondary),
        if (!done && !failed) ...[
          Gap.h12,
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: mine ? job!.progress : null,
              minHeight: 6,
              backgroundColor: AppColors.primarySoftBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
        Gap.h16,
        PrimaryButton(
          label: done
              ? '영상 보고 이어서 하기'
              : failed
              ? '다시 만들러 가기'
              : '진행 화면 보기',
          onPressed: () => _continue(context, ref, done),
        ),
        TextButton(
          onPressed: () => _discard(context, ref),
          child: const Text('이 일기 지우기'),
        ),
      ],
    );
  }
}

/// 아직 쓰지 않은 날 카드 — 제목, 일기가 만들어지는 순서(말하기 → 확인하기 → 영상 → 상담), 시작 버튼.
/// 문구와 버튼만 있을 때는 카드가 허전했다(2026-11 시안 9개 중 8안).
class _EmptyDayContent extends StatelessWidget {
  const _EmptyDayContent({required this.isToday, required this.onWrite});

  final bool isToday;
  final VoidCallback onWrite;

  static const _steps = [
    (Icons.mic_none_rounded, '말하기'),
    (Icons.edit_note_rounded, '확인하기'),
    (Icons.movie_creation_outlined, '영상'),
    (Icons.chat_bubble_outline_rounded, '상담'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isToday ? '오늘 하루는 어땠나요?' : '이날은 아직 기록이 없어요',
          textAlign: TextAlign.center,
          style: AppTypography.title,
        ),
        Gap.h4,
        const Text(
          '이렇게 한 편의 일기가 만들어져요',
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
        const Spacer(),
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0)
                const Expanded(
                  child: Divider(
                    color: AppColors.primarySoftBorder,
                    thickness: 2,
                  ),
                ),
              Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      // 첫 단계(지금 할 일)만 채워서 강조한다.
                      color: i == 0
                          ? AppColors.primary
                          : AppColors.backgroundAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _steps[i].$1,
                      size: 22,
                      color: i == 0
                          ? AppColors.textOnPrimary
                          : AppColors.primary,
                    ),
                  ),
                  Gap.h4,
                  Text(_steps[i].$2, style: AppTypography.caption),
                ],
              ),
            ],
          ],
        ),
        Gap.h12,
        const Text(
          '약 10분이면 영상과 상담까지 끝나요',
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
        const Spacer(),
        PrimaryButton(
          label: isToday ? '오늘 일기 말하기' : '이날 이야기 말하기',
          leadingIcon: Icons.mic_none_rounded,
          onPressed: onWrite,
        ),
      ],
    );
  }
}

/// 미래 날짜 카드 내용 — 제목, 설명.
class _CardMessage extends StatelessWidget {
  const _CardMessage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, textAlign: TextAlign.center, style: AppTypography.title),
        Gap.h8,
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
      ],
    );
  }
}

/// 빼꼼 포즈 탄카츄가 카드 윗변을 잡는 연출. 그림 아래쪽 끝이 손끝이라
/// 카드 내용을 가리지 않는다.
class _PeekingCard extends StatelessWidget {
  const _PeekingCard({required this.child});

  /// 마스코트 그림 높이와, 손이 카드 윗변에 걸치는 만큼 겹치는 높이.
  static const _mascotSize = 140.0;
  static const _overlap = 12.0;

  /// 쓴 날·안 쓴 날 카드를 같은 크기로 맞춘다(쓴 날 카드가 길어 스크롤해야 했다).
  static const cardHeight = 390.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _mascotSize - _overlap),
          child: SizedBox(
            height: cardHeight,
            child: _HomeCardShell(child: child),
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: MascotImage(
              pose: MascotPose.peeking,
              size: _mascotSize,
              alignment: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
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
    final thumbnail = ref.watch(savedVideoThumbnailUrlProvider(date)).value;
    final chips = Wrap(
      spacing: AppSpacing.xxs,
      runSpacing: AppSpacing.xxs,
      children: [
        for (final e in entry?.emotionKeywords ?? const <String>[])
          OddoChip(label: e),
      ],
    );
    final readDiary = _ActionTile(
      icon: Icons.menu_book_rounded,
      label: '일기 읽기',
      onTap: onReadDiary,
    );
    final title = Text(
      DateFormatter.monthDay(date),
      style: AppTypography.title.copyWith(color: AppColors.primary),
    );
    // 날짜·감정 한 줄, 요약 2줄, 영상(가로로 남는 높이만큼), 일기 읽기. 스크롤 없이 한 화면에 들어간다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            title,
            Gap.w12,
            Expanded(child: chips),
          ],
        ),
        Gap.h8,
        Text(
          entry?.summary ?? '',
          style: AppTypography.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Gap.h12,
        Expanded(
          child: _VideoTile(
            thumbnail: thumbnail,
            onTap: () => _openVideo(context, ref),
          ),
        ),
        Gap.h12,
        readDiary,
      ],
    );
  }
}

/// 영상 썸네일 + 재생 아이콘. 받은 칸을 가득 채운다. 누르면 그날 영상을 연다.
class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.thumbnail, required this.onTap});

  final String? thumbnail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.callBackground),
              // 그날 영상의 대표 장면 썸네일. 없거나 못 불러오면 마스코트.
              _VideoThumbnail(url: thumbnail),
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드 아래 버튼(일기 읽기).
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: const BoxDecoration(
          color: AppColors.backgroundAlt,
          borderRadius: AppRadius.button,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            Gap.w8,
            Text(
              label,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

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
