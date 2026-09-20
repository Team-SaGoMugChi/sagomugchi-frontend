import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diary_providers.dart';
import '../data/models/counsel_session.dart';

/// Step4 상담 대화 상태 — 메시지 목록과 전송 중 여부.
class CounselState {
  const CounselState({this.messages = const [], this.sending = false});

  final List<CounselMessage> messages;
  final bool sending;

  CounselState copyWith({List<CounselMessage>? messages, bool? sending}) =>
      CounselState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
      );
}

class CounselController extends Notifier<CounselState> {
  @override
  CounselState build() => const CounselState();

  Future<void> sendTurn(String userText) async {
    if (userText.trim().isEmpty || state.sending) return;

    state = state.copyWith(
      messages: [
        ...state.messages,
        CounselMessage(speaker: CounselSpeaker.user, text: userText),
      ],
      sending: true,
    );

    try {
      final reply = await ref
          .read(counselRepositoryProvider)
          .sendTurn(userText: userText);
      state = state.copyWith(
        messages: [
          ...state.messages,
          CounselMessage(speaker: CounselSpeaker.oddo, text: reply),
        ],
        sending: false,
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
}

final counselControllerProvider =
    NotifierProvider<CounselController, CounselState>(CounselController.new);