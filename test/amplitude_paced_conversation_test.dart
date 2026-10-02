import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/media/amplitude_paced_conversation_controller.dart';
import 'package:oddo/core/media/tts_service.dart';

class _Tts implements TtsService {
  int speaks = 0;

  @override
  Future<void> speak(String line) async {
    speaks++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'custom prompt playback can replace TTS while keeping question visible',
    () async {
      final tts = _Tts();
      final turns = <ConversationTurn>[];
      final spoken = <String>[];
      final controller = AmplitudePacedConversationController(
        tts,
        const Stream<double>.empty(),
        speakPrompt: (prompt) async => spoken.add(prompt),
      );

      await controller.run(
        const ['오늘 하루는 어땠나요?'],
        budget: const Duration(minutes: 1),
        onTurn: turns.add,
      );

      expect(tts.speaks, 0);
      expect(spoken, ['오늘 하루는 어땠나요?']);
      expect(turns.map((turn) => turn.speaking), [true, false]);
      expect(turns.last.caption, '오늘 하루는 어땠나요?');
    },
  );
}
