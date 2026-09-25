import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diary_providers.dart';
import '../data/models/counsel_report.dart';
import 'diary_draft_provider.dart';

/// 45번 화면에서 만드는 상담 리포트의 상태.
///
/// 실패해도 46번 화면은 샘플로 폴백하므로, 에러 화면으로 덮지 않고 배너로만
/// 알린다. 다시 시도는 [CounselReportController.retry]가 맡는다.
class CounselReportState {
  const CounselReportState({
    this.report,
    this.generating = false,
    this.failed = false,
  });

  final CounselReport? report;
  final bool generating;

  /// 생성에 실패했거나 상담을 건너뛴 상태.
  final bool failed;
}

class CounselReportController extends Notifier<CounselReportState> {
  @override
  CounselReportState build() => const CounselReportState();

  /// 서버가 응답하지 않아도 45번 화면이 갇히지 않도록 여기서 끊는다.
  /// 리포트 생성은 LLM 호출이라 보통 5~15초 걸린다.
  static const Duration _timeout = Duration(seconds: 30);

  /// 상담 대화를 서버에 보내 리포트를 만든다.
  /// 이미 만들었거나 만드는 중이면 아무것도 하지 않는다 — 화면 재진입 시 중복 방지.
  Future<void> generate() async {
    if (state.generating || state.report != null) return;

    final draft = ref.read(diaryDraftProvider);
    if (draft.counselMessages.isEmpty) {
      // 상담을 건너뛴 경우 — 서버를 부르지 않는다.
      state = const CounselReportState(failed: true);
      return;
    }

    state = const CounselReportState(generating: true);
    try {
      final report = await ref
          .read(counselRepositoryProvider)
          .fetchReport(
            messages: draft.counselMessages,
            emotions: draft.fusionResult?.emotionScores,
            // TODO(고도화): Step2 요약이 나오면 원문 대신 요약을 보낸다.
            diarySummary: draft.transcript,
          )
          .timeout(_timeout);
      state = CounselReportState(report: report);
    } catch (_) {
      // 타임아웃·네트워크 오류 — 리포트를 못 만들어도 기록 저장은 되어야 한다.
      state = const CounselReportState(failed: true);
    }
  }

  /// 46번 화면의 "다시 시도" — 실패 상태를 지우고 한 번 더 부른다.
  Future<void> retry() async {
    state = const CounselReportState();
    await generate();
  }
}

final counselReportControllerProvider =
    NotifierProvider<CounselReportController, CounselReportState>(
      CounselReportController.new,
    );
