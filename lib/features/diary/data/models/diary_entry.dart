import 'video_rating.dart';

/// One day's diary entry, produced by the Step 1–3 write flow.
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.date,
    required this.transcript,
    required this.summary,
    required this.emotionKeywords,
    this.diaryText,
    this.videoUrl,
    this.videoRating,
    this.emotionIntensity = 0,
    this.emotionStability = 0,
    this.writtenAt,
  });

  final String id;
  final DateTime date;

  /// 기록 완료 버튼을 누른 실제 시각 (구버전 문서엔 없을 수 있음).
  final DateTime? writtenAt;

  /// Step 1에서 사용자가 한 말(원 답변). 감정 분석·영상·상담의 입력.
  final String transcript;

  /// 탄카츄와의 대화를 일기 한 편으로 정제하고 Step 2에서 사용자가 고친 글 —
  /// 일기 상세에 보여주는 본문. 대화형 말하기 이전 문서엔 없다(null).
  final String? diaryText;

  /// AI-generated summary written in diary style.
  final String summary;

  final List<String> emotionKeywords;

  /// URL/path of the generated short-form video (null until Step 3 finishes).
  final String? videoUrl;

  /// Step 3 완료 화면에서 고른 영상 평가. 고르지 않았으면 null.
  final VideoRating? videoRating;

  /// 0–100 scores shown on the Step 2 confirm screen.
  final int emotionIntensity;
  final int emotionStability;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        transcript: json['transcript'] as String,
        diaryText: json['diaryText'] as String?,
        summary: json['summary'] as String,
        emotionKeywords: (json['emotionKeywords'] as List<dynamic>)
            .cast<String>(),
        videoUrl: json['videoUrl'] as String?,
        videoRating: VideoRating.fromKey(json['videoRating']),
        emotionIntensity: json['emotionIntensity'] as int? ?? 0,
        emotionStability: json['emotionStability'] as int? ?? 0,
        writtenAt: json['writtenAt'] != null
            ? DateTime.parse(json['writtenAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'transcript': transcript,
        if (diaryText != null) 'diaryText': diaryText,
        'summary': summary,
        'emotionKeywords': emotionKeywords,
        'videoUrl': videoUrl,
        if (videoRating != null) 'videoRating': videoRating!.key,
        'emotionIntensity': emotionIntensity,
        'emotionStability': emotionStability,
        if (writtenAt != null) 'writtenAt': writtenAt!.toIso8601String(),
      };
}
