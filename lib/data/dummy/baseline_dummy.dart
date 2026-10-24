import 'package:flutter/material.dart';

import '../../features/baseline/data/models/baseline_profile.dart';
import '../../theme/app_colors.dart';

/// One OS permission explained on the permission-rationale screen (09).
class PermissionInfo {
  const PermissionInfo(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

/// One environment checklist row on the baseline ready screen (18).
class CheckItem {
  const CheckItem(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

/// One measurement item on the baseline intro screen (17).
class MeasureItem {
  const MeasureItem(this.icon, this.title, this.description, this.duration);
  final IconData icon;
  final String title;
  final String description;
  final String duration;
}

/// Live progress row on the measuring screen (19).
class MeasureProgress {
  const MeasureProgress(this.label, this.value);
  final String label;
  final double value; // 0..1
}

/// A summary metric tile on the completion screen (21).
class BaselineMetric {
  const BaselineMetric(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

/// Static dummy content for the permission + baseline flow. Mirrors the
/// mockups and `_docs/02`. Replace with real data/state later.
abstract final class BaselineDummy {
  BaselineDummy._();

  // 09 — permission rationale.
  static const List<PermissionInfo> permissions = [
    PermissionInfo(
      Icons.camera_alt_outlined,
      '카메라',
      '얼굴 표정 측정과 영상 통화를 위해 필요해요.',
    ),
    PermissionInfo(
      Icons.mic_none_rounded,
      '마이크',
      '목소리를 기록하고 감정을 분석하기 위해 필요해요.',
    ),
    PermissionInfo(
      Icons.graphic_eq_rounded,
      '음성 인식',
      '말한 내용을 텍스트로 변환하기 위해 필요해요.',
    ),
    PermissionInfo(
      Icons.notifications_none_rounded,
      '알림',
      '기록 리마인드와 소식을 전달하기 위해 필요해요.',
    ),
    PermissionInfo(
      Icons.photo_library_outlined,
      '사진 저장',
      '완성된 숏폼 영상을 저장하기 위해 필요해요.',
    ),
  ];

  // 17 — measurement items.
  static const List<MeasureItem> measureItems = [
    MeasureItem(
      Icons.sentiment_satisfied_alt_rounded,
      '얼굴 표정 측정',
      '문장을 읽는 동안 평소 표정을 기록해요.',
      '읽는 동안 함께',
    ),
    MeasureItem(
      Icons.mic_none_rounded,
      '음성 측정',
      '화면에 나오는 문장 6개를 그대로 읽어요.',
      '약 1~2분',
    ),
  ];

  static const List<String> introTips = [
    '편안한 장소에서 진행하면 좋아요.',
    '문장 6개를 천천히 읽고, 다 읽었어요 버튼을 눌러주세요.',
    '측정 중 너무 움직이지 않도록 해주세요.',
  ];

  // 18 — environment checklist (all good for the prototype).
  static const List<CheckItem> checklist = [
    CheckItem(Icons.center_focus_strong_rounded, '얼굴 위치', '얼굴이 화면 중앙에 있어요'),
    CheckItem(Icons.light_mode_rounded, '조명 상태', '주변이 너무 어둡지 않아요'),
    CheckItem(Icons.mic_none_rounded, '마이크 상태', '마이크가 정상적으로 연결됐어요'),
    CheckItem(Icons.volume_off_rounded, '주변 소음', '주변 소음이 크지 않아요'),
    CheckItem(Icons.verified_user_outlined, '카메라·마이크 권한', '권한이 모두 켜져 있어요'),
  ];

  // 19 — live measuring progress.
  static const List<MeasureProgress> measuringProgress = [
    MeasureProgress('얼굴 표정 측정', 0.60),
    MeasureProgress('음성 측정', 0.45),
  ];

  static const List<String> measuringTips = ['화면을 응시하며 자연스럽게 행동해주세요.'];

  // 19 — 탄카츄가 측정 중 음성으로 읽어주는 안내 대사. 감정 기복이 적은 평소
  // 상태를 자연스럽게 끌어내려고 일부러 담백한 주제로 구성했다(baseline은
  // "오늘 하루"가 아니라 평소 기준치를 잡는 용도). 튜토리얼 통화 연습(짧은
  // 데모)에서만 쓰는 짧은 버전. 현재 실제 측정은 readingSentences를 쓴다.
  static const List<String> guideScript = [
    '안녕하세요, 오늘 평소 표정과 목소리를 기준으로 남겨둘게요.',
    '편하게 화면을 보면서, 요즘 하루를 어떻게 보내고 있는지 얘기해주세요.',
    '좋아하는 음식이나 최근에 본 것도 좋아요. 자연스럽게 말씀해주시면 돼요.',
  ];

  /// Fixed neutral text. Never spoken by the app during recording.
  static const readingSentences = [
    '아침에 창문을 열어 보니 맑은 하늘 아래 나무들이 천천히 흔들리고 있었습니다.',
    '책상 위에 놓인 책과 연필을 정리하고 컵에 물을 한 잔 따라 마셨습니다.',
    '집 앞 길을 따라 걸으며 주변의 건물과 지나가는 사람들을 바라보았습니다.',
    '가게에서 필요한 물건을 고른 뒤 장바구니에 담아 집으로 돌아왔습니다.',
    '오후에는 의자에 앉아 책을 몇 장 읽고 잠시 창밖의 풍경을 살펴보았습니다.',
    '저녁에는 내일 사용할 물건을 준비하고 조명을 낮춘 뒤 편안하게 쉬었습니다.',
  ];

  // 20 — analysis-in-progress items.
  static const List<String> analysisItems = [
    '얼굴 표정 기준',
    '음성 에너지 기준',
    '말하기 속도 기준',
  ];

  // 21 — completion summary lines (doc 21).
  static const List<String> completionSummary = [
    '얼굴 기준 데이터 저장 완료',
    '음성 기준 데이터 저장 완료',
    '감정 분석 준비 완료',
  ];

  // 21 — emotion-baseline summary metrics (mockup).
  static const List<BaselineMetric> metrics = [
    BaselineMetric(
      Icons.sentiment_satisfied_alt_rounded,
      '평균 감정',
      '6.2 / 10',
      AppColors.primary,
    ),
    BaselineMetric(
      Icons.graphic_eq_rounded,
      '음성 안정도',
      '72%',
      AppColors.success,
    ),
    BaselineMetric(
      Icons.insights_rounded,
      '표정 변화 다양성',
      '64%',
      AppColors.primary,
    ),
    BaselineMetric(
      Icons.schedule_rounded,
      '평균 측정 시간',
      '1분 48초',
      AppColors.warning,
    ),
  ];
}

/// Synthetic preview values only; never represent a user's measurement.
BaselineProfile sampleBaseline(DateTime measuredAt) => BaselineProfile(
  voice: {
    for (final key in BaselineProfile.requiredAnalysisVoiceKeys) key: 1,
    'pitchMean': 180,
    'energyMean': 0.3,
    'speechRate': 3.5,
    'voicedRatio': 0.8,
    'durationSec': 60,
    'windowCount': 20,
    'windowUsedCount': 16,
  },
  face: {
    for (final key in BaselineProfile.requiredAnalysisFaceKeys) key: 0.1,
    'eyeAspectRatio': 0.28,
    'mouthAspectRatio': 0.1,
    'auFrameCount': 50,
    'auTotalFrames': 60,
  },
  measuredAt: measuredAt,
  featureVersion: BaselineProfile.currentFeatureVersion,
);
