/// The user's chatbot-persona settings (name / 말투 / 성격), chosen during
/// onboarding and editable later in 챗봇 설정.
///
/// Stored at `users/{uid}/meta/persona` — see FIRESTORE_SCHEMA.md. The Phase-5
/// counseling bot reads this to build its system prompt.
class PersonaConfig {
  const PersonaConfig({
    required this.name,
    required this.tone,
    required this.traits,
    required this.updatedAt,
  });

  /// Chatbot display name (max 10 chars, default '오디').
  final String name;

  /// 말투 — a title from PersonaDummy.tones (e.g. '친근하고 따뜻한').
  final String tone;

  /// 성격 multi-select (e.g. ['공감 잘해주는', '따뜻한']).
  final List<String> traits;

  final DateTime updatedAt;

  /// Rejects malformed Firestore values before they reach a screen or the
  /// counseling prompt. UI choices currently stay well inside these limits.
  bool get isValid {
    final cleanName = name.trim();
    final cleanTone = tone.trim();
    return cleanName.isNotEmpty &&
        cleanName.runes.length <= 10 &&
        !cleanName.contains(RegExp(r'[\r\n]')) &&
        cleanTone.isNotEmpty &&
        cleanTone.runes.length <= 30 &&
        !cleanTone.contains(RegExp(r'[\r\n]')) &&
        traits.length <= 6 &&
        traits.toSet().length == traits.length &&
        traits.every(
          (trait) =>
              trait.trim().isNotEmpty &&
              trait.runes.length <= 20 &&
              !trait.contains(RegExp(r'[\r\n]')),
        );
  }

  Map<String, dynamic> toCounselJson() => {
    'name': name.trim(),
    'tone': tone.trim(),
    'traits': traits.map((trait) => trait.trim()).toList(),
  };

  PersonaConfig copyWith({
    String? name,
    String? tone,
    List<String>? traits,
    DateTime? updatedAt,
  }) {
    return PersonaConfig(
      name: name ?? this.name,
      tone: tone ?? this.tone,
      traits: traits ?? this.traits,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PersonaConfig.fromJson(Map<String, dynamic> json) => PersonaConfig(
    name: json['name'] as String,
    tone: json['tone'] as String,
    traits: (json['traits'] as List<dynamic>).cast<String>(),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'tone': tone,
    'traits': traits,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
