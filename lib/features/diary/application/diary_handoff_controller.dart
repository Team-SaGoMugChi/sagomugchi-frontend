import 'dart:async';

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
/// 다시 확인하면 다시 만들어 덮어쓴다. 영상 단계는 [latest]로 받아
/// `/video/jobs` 요청에 싣는다.
class DiaryHandoffController extends Notifier<AsyncValue<DiaryHandoff?>> {
  /// 영상 단계가 전달 JSON을 기다리는 최대 시간 — 넘으면 JSON 없이 진행한다.
  static const latestTimeout = Duration(seconds: 8);

  /// 가장 최근 [submit]이 만들고 있는(또는 만든) JSON. 실패하면 null로 끝난다.
  Future<DiaryHandoff?>? _built;

  @override
  AsyncValue<DiaryHandoff?> build() => const AsyncData(null);

  Future<void> submit() async {
    final draft = ref.read(diaryDraftProvider);
    final transcript = draft.transcript?.trim() ?? '';
    if (transcript.isEmpty) return;
    final date = ref.read(viewingDateProvider);

    state = const AsyncLoading();
    final repository = ref.read(diaryHandoffRepositoryProvider);
    final building = repository.build(
      date: date,
      transcript: transcript,
      diaryText: draft.diaryText,
      summary: draft.summary,
      slots: draft.interviewSlots,
      conversation: draft.interviewMessages,
      emotion: draft.fusionResult,
    );
    // 영상 단계는 저장까지 기다릴 필요 없이 만들어지는 즉시 받는다.
    _built = building.then<DiaryHandoff?>((h) => h, onError: (_) => null);
    final result = await AsyncValue.guard(() async {
      final handoff = await building;
      await repository.save(date: date, handoff: handoff);
      return handoff;
    });
    if (ref.mounted) state = result;
  }

  /// 방금 만든(또는 만들고 있는) 전달 JSON. [timeout] 안에 못 받거나 만들지
  /// 못했으면 null — 부르는 쪽은 JSON 없이 진행한다.
  Future<DiaryHandoff?> latest({Duration timeout = latestTimeout}) async {
    final built = _built;
    if (built == null) return state.value;
    try {
      return await built.timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }
}

final diaryHandoffControllerProvider =
    NotifierProvider<DiaryHandoffController, AsyncValue<DiaryHandoff?>>(
      DiaryHandoffController.new,
    );
