import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../data/diary_providers.dart';
import '../data/models/video_job_status.dart';
import 'diary_draft_provider.dart';
import 'diary_handoff_controller.dart';
import 'video_archive_controller.dart';

/// Step3 영상 제작 상태 — 서버 작업 상태와, 작업을 못 만들었거나 폴링이
/// 끊겼을 때의 오류 문구.
class VideoJobUiState {
  const VideoJobUiState({this.job, this.error});

  /// 서버가 알려준 최신 작업 상태. 등록 전이면 null.
  final VideoJobStatus? job;

  /// 사용자에게 보여줄 실패 문구. 서버가 failed로 끝낸 경우도 여기에 담는다.
  final String? error;

  bool get isDone => job?.isDone ?? false;
  bool get isFailed => error != null;

  /// 재생할 영상 URL. 더미 모드나 완료 전이면 null.
  String? get videoUrl => isDone ? job?.videoUrl : null;
}

/// 일기 원문 + Step2 분석 결과로 영상 생성 작업을 등록하고, 끝날 때까지
/// [pollInterval]마다 상태를 확인한다.
///
/// 41번 로딩 화면이 진입 시 [start]를 부른다. 같은 원문으로 이미 진행 중이거나
/// 끝난 작업이 있으면 새로 만들지 않는다 — 화면 재진입으로 영상(과금)이
/// 중복 생성되지 않도록.
class VideoJobController extends Notifier<VideoJobUiState> {
  static const pollInterval = Duration(seconds: 3);

  /// 폴링 중 네트워크 오류는 이 횟수까지 연속으로 참는다. 작업은 서버에서
  /// 계속 돌고 있으므로 잠깐 끊겼다고 바로 실패로 보여주지 않는다.
  static const maxPollFailures = 3;

  Timer? _timer;
  String? _startedFor;
  int _pollFailures = 0;

  @override
  VideoJobUiState build() {
    ref.onDispose(_stopPolling);
    return const VideoJobUiState();
  }

  Future<void> start() async {
    final draft = ref.read(diaryDraftProvider);
    final text = draft.transcript?.trim() ?? '';
    if (text.isEmpty) {
      state = const VideoJobUiState(error: '일기 내용을 찾지 못해 영상을 만들 수 없어요.');
      return;
    }
    if (_startedFor == text && state.job != null && !state.isFailed) return;

    _stopPolling();
    _startedFor = text;
    _pollFailures = 0;
    state = const VideoJobUiState();

    final fusion = draft.fusionResult;
    // Step2에서 만들기 시작한 영상 전달 JSON(장면·전환점·정제 일기 등)을 잠깐
    // 기다렸다가 싣는다. 늦거나 실패하면 JSON 없이 지금처럼 만든다.
    final handoff = await ref
        .read(diaryHandoffControllerProvider.notifier)
        .latest();
    try {
      final job = await ref
          .read(videoRepositoryProvider)
          .createJob(
            text: text,
            emotionKeywords: fusion?.emotionKeywords,
            emotionScores: fusion?.emotionScores,
            emotionIntensity: fusion?.emotionIntensity,
            diaryHandoff: handoff?.video,
          );
      _apply(job);
    } on AppException catch (e) {
      state = VideoJobUiState(error: _messageFor(e));
    }
  }

  /// 실패 후 사용자가 "다시 시도"를 누르면 새 작업을 만든다.
  Future<void> retry() {
    _startedFor = null;
    return start();
  }

  void _apply(VideoJobStatus job) {
    if (job.isFailed) {
      _stopPolling();
      state = VideoJobUiState(
        job: job,
        error: job.error ?? '영상을 만들지 못했어요. 잠시 후 다시 시도해주세요.',
      );
      return;
    }
    state = VideoJobUiState(job: job);
    if (job.isDone) {
      _stopPolling();
      // 지난 날짜에도 다시 볼 수 있게 Firebase Storage에 보관한다(기다리지 않는다).
      final url = job.videoUrl;
      if (url != null) {
        ref.read(videoArchiveControllerProvider.notifier).archive(url);
      }
    } else {
      _timer ??= Timer.periodic(pollInterval, (_) => _poll());
    }
  }

  Future<void> _poll() async {
    final jobId = state.job?.jobId;
    if (jobId == null) return;
    try {
      final job = await ref.read(videoRepositoryProvider).fetchJob(jobId);
      _pollFailures = 0;
      _apply(job);
    } on AppException catch (e) {
      _pollFailures++;
      if (_pollFailures >= maxPollFailures) {
        _stopPolling();
        state = VideoJobUiState(job: state.job, error: _messageFor(e));
      }
    }
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  String _messageFor(AppException e) => e is NetworkException
      ? '서버에 연결하지 못했어요. 네트워크를 확인하고 다시 시도해주세요.'
      : '영상을 만들지 못했어요. 잠시 후 다시 시도해주세요.';
}

final videoJobControllerProvider =
    NotifierProvider<VideoJobController, VideoJobUiState>(
      VideoJobController.new,
    );
