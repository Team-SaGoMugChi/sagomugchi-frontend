import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/media/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  const codec = StandardMethodCodec();

  test(
    'device speech motion waits for audio start and stops on completion',
    () async {
      final speaking = Completer<int>();
      final requested = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'speak') {
          requested.complete();
          return speaking.future;
        }
        return 1;
      });
      final service = TtsService();
      final done = service.speak('안녕하세요');
      await requested.future;
      expect(service.utterance.value, isNull);
      await messenger.handlePlatformMessage(
        'flutter_tts',
        codec.encodeMethodCall(const MethodCall('speak.onStart')),
        (_) {},
      );
      expect(service.utterance.value?.text, '안녕하세요');
      speaking.complete(1);
      await done;
      expect(service.utterance.value, isNull);
      await service.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    },
  );
}
