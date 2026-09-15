import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/baseline_providers.dart';
import '../data/models/baseline_measurement_exception.dart';
import '../data/models/baseline_profile.dart';
import 'baseline_face_image_provider.dart';
import 'baseline_recording_provider.dart';

/// 측정 화면에서 모아둔 음성/얼굴 파일을 AI 서버에 업로드하는 상태.
///
/// idle은 `AsyncData(null)`로 표현한다 — 분석 화면 진입 시 자동으로 [submit]을
/// 호출하고, 실패하면 사용자가 재시도 버튼으로 다시 [submit]을 부를 수 있다.
class BaselineUploadController extends Notifier<AsyncValue<BaselineProfile?>> {
  int _submission = 0;

  @override
  AsyncValue<BaselineProfile?> build() {
    ref.watch(authControllerProvider.select((value) => value.user?.id));
    _submission++;
    return const AsyncData(null);
  }

  void startMeasurement() {
    _submission++;
    ref.read(baselineRecordingProvider.notifier).clear();
    ref.read(baselineFaceImageProvider.notifier).clear();
    state = const AsyncData(null);
  }

  Future<void> submit() async {
    if (state.isLoading) return;
    final submission = ++_submission;
    final voicePath = ref.read(baselineRecordingProvider);
    final facePath = ref.read(baselineFaceImageProvider);

    if (voicePath == null ||
        voicePath.isEmpty ||
        facePath == null ||
        facePath.isEmpty) {
      state = AsyncError(
        const BaselineMeasurementException(
          '음성 또는 얼굴 데이터를 찾을 수 없어요. 측정을 다시 진행해주세요.',
          code: 'missing_media',
        ),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref
          .read(baselineRepositoryProvider)
          .submitMeasurement(voiceFilePath: voicePath, faceImagePath: facePath);
    });
    if (ref.mounted && submission == _submission) state = result;
  }
}

final baselineUploadControllerProvider =
    NotifierProvider<BaselineUploadController, AsyncValue<BaselineProfile?>>(
      BaselineUploadController.new,
    );
