import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../persona/data/persona_providers.dart';
import '../data/diary_providers.dart';
import '../data/models/counsel_session.dart';
import 'diary_draft_provider.dart';

/// Step4 상담 대화 상태 — 메시지 목록, 전송 중 여부, 위기 감지 여부.
class CounselState {
  const CounselState({
    this.messages = const [],
    this.sending = false,
    this.crisis = false,
    this.startedAt,
  });

  final List<CounselMessage> messages;
  final bool sending;

  /// 서버가 위기 발화를 감지한 상태 — 상담을 멈추고 전문 기관 안내를 띄운다.
  final bool crisis;

  /// 이 상담을 처음 시작한 시각. 이어하기면 저장돼 있던 시작 시각을 쓴다.
  final DateTime? startedAt;

  CounselState copyWith({
    List<CounselMessage>? messages,
    bool? sending,
    bool? crisis,
    DateTime? startedAt,
  }) => CounselState(
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    crisis: crisis ?? this.crisis,
    startedAt: startedAt ?? this.startedAt,
  );
}

class CounselController extends Notifier<CounselState> {
  @override
  CounselState build() => const CounselState();

  /// 저장된 상담이 있으면 불러와 이어서 대화한다(같은 날 추가 상담).
  /// 이미 대화가 있으면 아무것도 하지 않는다 — 화면 재진입 시 중복 방지.
  Future<void> restoreIfEmpty(DateTime date) async {
    if (state.messages.isNotEmpty) return;
    try {
      final saved = await ref.read(diaryRepositoryProvider).fetchCounsel(date);
      if (saved == null || saved.messages.isEmpty) return;
      if (state.messages.isNotEmpty) return;
      state = state.copyWith(
        messages: saved.messages,
        startedAt: saved.startedAt,
      );
    } catch (_) {
      // 기록을 못 불러와도 새 상담은 가능해야 한다.
    }
  }

  Future<void> sendTurn(String userText) async {
    if (userText.trim().isEmpty || state.sending || state.crisis) return;

    // 이번 발화 이전까지의 대화만 history로 보낸다(서버가 user_text를 뒤에 붙인다).
    final history = List<CounselMessage>.unmodifiable(state.messages);

    state = state.copyWith(
      messages: [
        ...state.messages,
        CounselMessage(speaker: CounselSpeaker.user, text: userText),
      ],
      sending: true,
      startedAt: state.startedAt ?? DateTime.now(),
    );

    try {
      final result = await ref
          .read(counselRepositoryProvider)
          .sendTurn(
            userText: userText,
            history: history,
            emotions: ref.read(diaryDraftProvider).fusionResult?.emotionScores,
            persona: await _loadPersona(),
          );
      state = state.copyWith(
        messages: [
          ...state.messages,
          CounselMessage(speaker: CounselSpeaker.oddo, text: result.reply),
        ],
        sending: false,
        crisis: result.crisis,
      );
    } catch (_) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          const CounselMessage(
            speaker: CounselSpeaker.oddo,
            text: '지금은 연결이 어려워요. 잠시 후 다시 이야기해줄래요?',
          ),
        ],
        sending: false,
      );
    }
  }

  /// 페르소나는 없어도 상담이 되어야 하므로 실패는 조용히 무시한다.
  Future<Map<String, dynamic>?> _loadPersona() async {
    try {
      final config = await ref.read(personaConfigProvider.future);
      return config?.toJson();
    } catch (_) {
      return null;
    }
  }
}

final counselControllerProvider =
    NotifierProvider<CounselController, CounselState>(CounselController.new);
