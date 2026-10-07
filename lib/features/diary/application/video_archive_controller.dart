import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../records/application/viewing_date_provider.dart';
import '../data/diary_providers.dart';

/// Step3 영상이 완성되면 Firebase Storage에 보관한다. 상태는 보관한 Storage 경로.
///
/// 영상 작업이 끝나는 즉시([VideoJobController]) 기다리지 않고 올린다 — 사용자가
/// Step4 상담을 하는 동안 끝난다. 기록 완료(46번)가 [latest]로 경로를 받아 일기의
/// `videoUrl`에 저장한다. 올리지 못해도 일기 저장은 막지 않는다(영상만 다시 볼 수 없다).
class VideoArchiveController extends Notifier<AsyncValue<String?>> {
  /// 기록 완료가 보관을 기다리는 최대 시간 — 넘으면 영상 없이 저장한다.
  static const latestTimeout = Duration(seconds: 20);

  Future<String?>? _archiving;
  String? _archivedFor;

  @override
  AsyncValue<String?> build() => const AsyncData(null);

  /// 같은 영상([sourceUrl])은 한 번만 올린다 — 폴링이 완료 상태를 여러 번 알려준다.
  void archive(String sourceUrl) {
    if (_archivedFor == sourceUrl) return;
    _archivedFor = sourceUrl;
    final date = ref.read(viewingDateProvider);
    state = const AsyncLoading();
    final uploading = ref
        .read(videoArchiveRepositoryProvider)
        .archive(date: date, sourceUrl: sourceUrl);
    _archiving = uploading.then<String?>((path) => path, onError: (_) => null);
    uploading.then(
      (path) {
        if (ref.mounted) state = AsyncData(path);
      },
      onError: (Object e, StackTrace st) {
        if (ref.mounted) state = AsyncError(e, st);
      },
    );
  }

  /// 보관한(또는 보관 중인) Storage 경로. [timeout] 안에 못 받거나 실패했으면 null.
  Future<String?> latest({Duration timeout = latestTimeout}) async {
    final archiving = _archiving;
    if (archiving == null) return state.value;
    try {
      return await archiving.timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }
}

final videoArchiveControllerProvider =
    NotifierProvider<VideoArchiveController, AsyncValue<String?>>(
      VideoArchiveController.new,
    );
