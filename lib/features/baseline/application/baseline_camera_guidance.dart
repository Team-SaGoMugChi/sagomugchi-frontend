import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CameraHint {
  faceMissing('얼굴이 카메라에 보이도록 맞춰주세요'),
  tooFar('조금만 가까이 와주세요'),
  tooClose('조금만 뒤로 가주세요'),
  tooDark('얼굴 쪽을 조금 더 밝게 해주세요'),
  tooBright('얼굴에 직접 닿는 강한 빛을 줄여주세요');

  const CameraHint(this.caption);
  final String caption;
}

/// 기기 안에서만 처리한다. 원본과 결과를 별도로 저장/전송하지 않는다.
class BaselineCameraGuidance {
  static const channel = MethodChannel('app.oddo.oddo/camera_guidance');

  Future<CameraHint?> inspect(String path) async {
    final result = await channel.invokeMapMethod<String, dynamic>(
      'inspect',
      path,
    );
    if (result == null) throw StateError('Camera inspection unavailable');
    final brightness = (result['brightness'] as num).toDouble();
    final faceWidth = (result['faceWidth'] as num?)?.toDouble();
    if (!brightness.isFinite ||
        brightness < 0 ||
        brightness > 255 ||
        (faceWidth != null && (!faceWidth.isFinite || faceWidth <= 0))) {
      throw StateError('Invalid camera quality reading');
    }
    // 밝기는 얼굴 영역의 평균 휘도(0~255). 거리는 화면 대비 얼굴 폭의 근사치.
    if (brightness < 45) return CameraHint.tooDark;
    if (brightness > 225) return CameraHint.tooBright;
    if (faceWidth == null) return CameraHint.faceMissing;
    if (faceWidth < 0.22) return CameraHint.tooFar;
    if (faceWidth > 0.72) return CameraHint.tooClose;
    return null;
  }
}

final baselineCameraGuidanceProvider = Provider<BaselineCameraGuidance>(
  (ref) => BaselineCameraGuidance(),
);

/// 순간 움직임에는 안내하지 않고, 같은 문제 3회 / 정상 2회로 표시를 갱신.
class CameraHintStabilizer {
  CameraHint? _candidate;
  int _count = 0;
  CameraHint? current;

  CameraHint? update(CameraHint? next) {
    if (next == _candidate) {
      _count++;
    } else {
      _candidate = next;
      _count = 1;
    }
    if (_count >= (next == null ? 2 : 3)) current = next;
    return current;
  }

  void reset() {
    _candidate = current = null;
    _count = 0;
  }
}
