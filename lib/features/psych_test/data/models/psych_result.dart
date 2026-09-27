/// Results of the onboarding psych tests (Big5 / MBTI / 성향).
///
/// Stored at `users/{uid}/meta/psych` — see FIRESTORE_SCHEMA.md.
///
/// Each section is null until that test is finished, which is also how the
/// resume screen (27) decides an in-progress state: some — but not all —
/// sections present.
class PsychResult {
  const PsychResult({
    this.big5,
    this.big5Instrument,
    this.big5CompletedAt,
    this.mbti,
    this.tendencyTraits,
    required this.updatedAt,
  });

  /// O/C/E/A/N trait → 0–100 score.
  final Map<String, int>? big5;

  /// Instrument/version used to produce [big5].
  final String? big5Instrument;

  /// Completion time for the Big Five section.
  final DateTime? big5CompletedAt;

  /// e.g. 'INFP'.
  final String? mbti;

  /// Tags produced by the 성향 test.
  final List<String>? tendencyTraits;

  final DateTime updatedAt;

  /// The validated onboarding assessment is finished and traceable to an
  /// instrument version. Corrupt or legacy partial documents are not treated
  /// as completed results.
  ///
  /// [mbti] and [tendencyTraits] remain optional for old documents and future
  /// separately validated instruments; placeholder screens do not set them.
  bool get isComplete {
    final scores = big5;
    if (scores == null ||
        scores.length != 5 ||
        !const {'O', 'C', 'E', 'A', 'N'}.every(scores.containsKey) ||
        scores.values.any((score) => score < 0 || score > 100)) {
      return false;
    }
    return big5Instrument?.trim().isNotEmpty == true && big5CompletedAt != null;
  }

  PsychResult copyWith({
    Map<String, int>? big5,
    String? big5Instrument,
    DateTime? big5CompletedAt,
    String? mbti,
    List<String>? tendencyTraits,
    DateTime? updatedAt,
  }) {
    return PsychResult(
      big5: big5 ?? this.big5,
      big5Instrument: big5Instrument ?? this.big5Instrument,
      big5CompletedAt: big5CompletedAt ?? this.big5CompletedAt,
      mbti: mbti ?? this.mbti,
      tendencyTraits: tendencyTraits ?? this.tendencyTraits,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PsychResult.fromJson(Map<String, dynamic> json) => PsychResult(
    big5: (json['big5'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, (v as num).round()),
    ),
    big5Instrument: json['big5Instrument'] as String?,
    big5CompletedAt: json['big5CompletedAt'] == null
        ? null
        : DateTime.parse(json['big5CompletedAt'] as String),
    mbti: json['mbti'] as String?,
    tendencyTraits: (json['tendencyTraits'] as List<dynamic>?)?.cast<String>(),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    if (big5 != null) 'big5': big5,
    if (big5Instrument != null) 'big5Instrument': big5Instrument,
    if (big5CompletedAt != null)
      'big5CompletedAt': big5CompletedAt!.toIso8601String(),
    if (mbti != null) 'mbti': mbti,
    if (tendencyTraits != null) 'tendencyTraits': tendencyTraits,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
