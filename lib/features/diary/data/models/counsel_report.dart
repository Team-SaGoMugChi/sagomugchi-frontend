/// 상담이 끝난 뒤 받는 리포트. 46번 화면에 그대로 뿌린다.
///
/// 서버 `/counsel/report` 응답과 1:1로 맞춘다. 필드명이 모두 한 단어라
/// snake_case 변환이 필요 없다.
class CounselReport {
  const CounselReport({
    required this.headline,
    required this.summary,
    this.moments = const [],
    this.reframe = '',
    this.suggestion = '',
    this.closing = '',
  });

  /// 오늘을 한 문장으로.
  final String headline;

  /// 무슨 일이 있었고 어떻게 느꼈는지 2~3문장.
  final String summary;

  /// 대화 중 스스로 알아차린 점. 없을 수 있다.
  final List<String> moments;

  /// 달리 볼 수 있는 관점 한 문장. 없을 수 있다.
  final String reframe;

  /// 아주 작은 행동 하나. 없을 수 있다.
  final String suggestion;

  /// 마무리 한 문장.
  final String closing;

  factory CounselReport.fromJson(Map<String, dynamic> json) => CounselReport(
    headline: json['headline'] as String? ?? '오늘의 이야기',
    summary: json['summary'] as String? ?? '',
    moments:
        (json['moments'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    reframe: json['reframe'] as String? ?? '',
    suggestion: json['suggestion'] as String? ?? '',
    closing: json['closing'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'headline': headline,
    'summary': summary,
    'moments': moments,
    'reframe': reframe,
    'suggestion': suggestion,
    'closing': closing,
  };
}