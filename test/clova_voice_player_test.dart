import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/media/clova_voice_player.dart';
import 'package:oddo/core/network/api_client.dart';

class _Api extends Fake implements ApiClient {
  final requested = Completer<void>();
  final response = Completer<Map<String, dynamic>>();
  Object? body;

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) {
    expect(path, '/tts');
    this.body = body;
    requested.complete();
    return response.future;
  }
}

void main() {
  test(
    'stop during synthesis prevents late playback and temporary file creation',
    () async {
      final api = _Api();
      final player = ClovaVoicePlayer(api);
      final speaking = player.speak('안녕하세요', 'njinho');
      await api.requested.future;
      expect(api.body, {'text': '안녕하세요', 'speaker': 'njinho'});
      await player.stop();
      // Deliberately invalid data: a canceled request must never decode or play it.
      api.response.complete({'audio_base64': 'not base64'});
      await expectLater(speaking, completes);
    },
  );
}
