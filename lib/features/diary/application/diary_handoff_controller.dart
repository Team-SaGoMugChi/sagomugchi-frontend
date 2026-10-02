import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../records/application/viewing_date_provider.dart';
import '../data/diary_providers.dart';
import '../data/models/diary_handoff.dart';
import 'diary_draft_provider.dart';

/// 일기 기록(Step2 확인)이 끝나면 영상(성진)·상담(다경) 파트에 넘길 JSON을 만들어
/// Firestore `users/{uid}/handoffs/{yyyy-MM-dd}`에 저장한다.
///
/// Step2 "저장하고 다음 단계"에서 기다리지 않고 부른다 — 전달 파일이 늦거나
/// 실패해도 영상·상담 흐름은 막지 않는다(결과는 이 상태에만 남는다). 같은 날
/// 다시 확인하면 다시 만들어 덮어쓴다.
class DiaryHandoffController extends Notifier<AsyncValue<DiaryHandoff?>> {
  @override
  AsyncValue<DiaryHandoff?> build() => const AsyncData(null);

  Future<void> submit() async {
    final draft = ref.read(diaryDraftProvider);
    final transcript = draft.transcript?.trim() ?? '';
    if (transcript.isEmpty) return;
    final date = ref.read(viewingDateProvider);

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final repository = ref.read(diaryHandoffRepositoryProvider);
      final handoff = await repository.build(
        date: date,
        transcript: transcript,
        diaryText: draft.diaryText,
        summary: draft.summary,
        slots: draft.interviewSlots,
        conversation: draft.interviewMessages,
        emotion: draft.fusionResult,
      );
      await repository.save(date: date, handoff: handoff);
      return handoff;
    });
    if (ref.mounted) state = result;
  }
}

final diaryHandoffControllerProvider =
    NotifierProvider<DiaryHandoffController, AsyncValue<DiaryHandoff?>>(
      DiaryHandoffController.new,
    );
