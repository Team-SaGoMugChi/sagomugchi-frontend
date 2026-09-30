import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diary_providers.dart';
import '../data/models/diary_interview.dart';

/// 37번 말하기 대화 상태 — 주고받은 말, 차례별 녹음, 채워진 육하원칙 칸,
/// 질문 대기·마무리·위기 여부.
class DiaryInterviewState {
  const DiaryInterviewState({
    this.messages = const [],
    this.recordingPaths = const [],
    this.slots = const {},
    this.waiting = false,
    this.done = false,
    this.crisis = false,
  });

  final List<InterviewMessage> messages;

  /// 사용자 답변 녹음(차례별 WAV) — 통화가 끝나면 순서대로 이어 붙여 감정
  /// 분석에 넘긴다. 탄카츄가 말하는 동안은 녹음하지 않으므로 사용자 목소리만 있다.
  final List<String> recordingPaths;

  /// 서버가 마지막으로 알려준 육하원칙 칸(빈 칸은 null). 칸을 알 수 없던
  /// 차례의 응답으로는 덮어쓰지 않는다.
  final Map<String, String?> slots;

  /// 탄카츄의 다음 질문을 기다리는 중.
  final bool waiting;

  /// 칸이 다 찼거나 질문 상한에 닿아 더 묻지 않는다 — 화면은 마무리 인사 뒤
  /// 원문 확인으로 넘어간다.
  final bool done;

  /// 위기 발화 — 대화를 멈추고 전문 기관을 안내한다.
  final bool crisis;

  /// 감정 분석 원문 — 사용자가 한 말만, 차례마다 줄을 바꿔 잇는다.
  String get transcript => messages
      .where((m) => m.speaker == InterviewSpeaker.user)
      .map((m) => m.text)
      .join('\n');

  DiaryInterviewState copyWith({
    List<InterviewMessage>? messages,
    List<String>? recordingPaths,
    Map<String, String?>? slots,
    bool? waiting,
    bool? done,
    bool? crisis,
  }) => DiaryInterviewState(
    messages: messages ?? this.messages,
    recordingPaths: recordingPaths ?? this.recordingPaths,
    slots: slots ?? this.slots,
    waiting: waiting ?? this.waiting,
    done: done ?? this.done,
    crisis: crisis ?? this.crisis,
  );
}

class DiaryInterviewController extends Notifier<DiaryInterviewState> {
  @override
  DiaryInterviewState build() => const DiaryInterviewState();

  /// 탄카츄의 첫 인사로 대화를 연다. 이미 시작했으면 아무것도 하지 않는다.
  void start(String greeting) {
    if (state.messages.isNotEmpty) return;
    state = DiaryInterviewState(
      messages: [InterviewMessage(speaker: InterviewSpeaker.oddo, text: greeting)],
    );
  }

  /// 한 차례 답변(STT 결과와 그 녹음)을 싣고 다음 질문을 받는다.
  ///
  /// [askNext]가 false면(통화를 끝내면서 마지막 답을 싣는 경우) 묻지 않는다.
  /// 마무리([DiaryInterviewState.done])나 위기 안내 뒤에도 묻지 않는다 — 답은
  /// 기록에 계속 쌓인다. 질문을 받지 못하면 [keepGoing]으로 이어간다.
  Future<void> addAnswer({
    required String recordingPath,
    required String text,
    required String keepGoing,
    bool askNext = true,
  }) async {
    final history = List<InterviewMessage>.unmodifiable(state.messages);
    final ask = askNext && !state.done && !state.crisis;
    state = state.copyWith(
      messages: [
        ...history,
        InterviewMessage(speaker: InterviewSpeaker.user, text: text),
      ],
      recordingPaths: [...state.recordingPaths, recordingPath],
      waiting: ask,
    );
    if (!ask) return;

    InterviewMessage reply;
    var done = false;
    var crisis = false;
    Map<String, String?>? slots;
    try {
      final result = await ref
          .read(diaryInterviewRepositoryProvider)
          .sendTurn(userText: text, history: history);
      reply = InterviewMessage(speaker: InterviewSpeaker.oddo, text: result.reply);
      done = result.done;
      crisis = result.crisis;
      if (result.slots.isNotEmpty) slots = result.slots;
    } catch (_) {
      reply = InterviewMessage(speaker: InterviewSpeaker.oddo, text: keepGoing);
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      messages: [...state.messages, reply],
      slots: slots,
      waiting: false,
      done: done,
      crisis: crisis,
    );
  }
}

/// 말하기 화면이 살아 있는 동안만 유지한다 — 다음 일기는 빈 대화에서 시작한다.
final diaryInterviewControllerProvider =
    NotifierProvider.autoDispose<DiaryInterviewController, DiaryInterviewState>(
      DiaryInterviewController.new,
    );
