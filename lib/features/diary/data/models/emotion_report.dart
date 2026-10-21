/// Post-counseling emotion report + behavior guide for a given date
/// (screens 46 / 49).
///
/// Stored at `users/{uid}/reports/{yyyy-MM-dd}` — see FIRESTORE_SCHEMA.md.
///
/// [headline]·[moments]·[reframe]은 상담 리포트(`/counsel/report`)에서 온다.
/// 이 필드가 생기기 전에 저장된 문서에는 값이 없으므로 빈 값으로 읽는다.
class EmotionReport {
  const EmotionReport({
    required this.date,
    required this.emotionDistribution,
    required this.emotionIntensity,
    required this.recoveryPossibility,
    required this.analysisComment,
    required this.behaviorGuides,
    required this.recommendedActivities,
    this.headline = '',
    this.moments = const [],
    this.reframe = '',
  });

  final DateTime date;

  /// Emotion → share (0–1), e.g. {'속상함': 0.42, '후회': 0.28, ...}.
  final Map<String, double> emotionDistribution;

  final int emotionIntensity; // 0–100
  final int recoveryPossibility; // 0–100
  final String analysisComment;
  final List<String> behaviorGuides;
  final List<String> recommendedActivities;

  /// 오늘을 한 문장으로. 상담을 안 했으면 빈 문자열.
  final String headline;

  /// 상담 중 사용자가 스스로 알아차린 점. 서버가 근거를 확인한 문장만 온다.
  final List<String> moments;

  /// 같은 일을 달리 볼 수 있는 관점 한 문장. 없으면 빈 문자열.
  final String reframe;

  factory EmotionReport.fromJson(Map<String, dynamic> json) => EmotionReport(
        date: DateTime.parse(json['date'] as String),
        emotionDistribution:
            (json['emotionDistribution'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, (v as num).toDouble())),
        emotionIntensity: json['emotionIntensity'] as int? ?? 0,
        recoveryPossibility: json['recoveryPossibility'] as int? ?? 0,
        analysisComment: json['analysisComment'] as String,
        behaviorGuides:
            (json['behaviorGuides'] as List<dynamic>).cast<String>(),
        recommendedActivities:
            (json['recommendedActivities'] as List<dynamic>).cast<String>(),
        headline: json['headline'] as String? ?? '',
        moments: (json['moments'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        reframe: json['reframe'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'emotionDistribution': emotionDistribution,
        'emotionIntensity': emotionIntensity,
        'recoveryPossibility': recoveryPossibility,
        'analysisComment': analysisComment,
        'behaviorGuides': behaviorGuides,
        'recommendedActivities': recommendedActivities,
        'headline': headline,
        'moments': moments,
        'reframe': reframe,
      };
}