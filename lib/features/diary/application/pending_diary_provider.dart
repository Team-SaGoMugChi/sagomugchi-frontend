import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import 'diary_draft_provider.dart';

/// 영상이 만들어지는 동안 홈에서 기다리는 일기 한 편.
///
/// 일기는 맨 끝 "기록 완료하기"에서야 저장되므로, 영상(15~20분)을 기다리며 홈으로
/// 나가면 작성 내용이 사라졌다. 영상 작업을 등록하는 순간 날짜·작업 번호·작성
/// 내용을 휴대폰에 남겨 두고, 홈 카드에서 "보고 이어서 하기"로 돌아온다.
/// 앱을 껐다 켜도 이어진다. 기록을 완료하면 지운다.
class PendingDiary {
  const PendingDiary({
    required this.date,
    required this.jobId,
    required this.draft,
  });

  final DateTime date;
  final String jobId;
  final DiaryDraftState draft;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'job_id': jobId,
    'draft': draft.toJson(),
  };

  factory PendingDiary.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date'] as String);
    return PendingDiary(
      date: DateTime(date.year, date.month, date.day),
      jobId: json['job_id'] as String,
      draft: DiaryDraftState.fromJson(
        Map<String, dynamic>.from(json['draft'] as Map),
      ),
    );
  }

  bool isFor(DateTime day) =>
      date.year == day.year && date.month == day.month && date.day == day.day;
}

class PendingDiaryController extends Notifier<PendingDiary?> {
  @override
  PendingDiary? build() {
    final raw = ref
        .read(localStoreProvider)
        .getString(LocalStore.kPendingDiary);
    if (raw == null) return null;
    try {
      return PendingDiary.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      // 형식이 바뀐 옛 값은 버린다 — 이어 쓸 수 없으면 홈에 남겨 둘 이유가 없다.
      return null;
    }
  }

  Future<void> save(PendingDiary pending) async {
    state = pending;
    await ref
        .read(localStoreProvider)
        .setString(LocalStore.kPendingDiary, jsonEncode(pending.toJson()));
  }

  Future<void> clear() async {
    state = null;
    await ref.read(localStoreProvider).remove(LocalStore.kPendingDiary);
  }
}

final pendingDiaryProvider =
    NotifierProvider<PendingDiaryController, PendingDiary?>(
      PendingDiaryController.new,
    );
