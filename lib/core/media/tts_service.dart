import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 지금 소리로 읽고 있는 문장 — 탄카츄 입 모양이 이걸 따라 움직인다.
///
/// [charIndex]는 TTS 엔진이 알려준 "지금 읽는 단어"의 시작 위치다. 엔진이
/// 위치를 알려주지 않으면(일부 기기) null로 남고, 화면은 경과 시간으로 추정한다.
@immutable
class TtsUtterance {
  const TtsUtterance({required this.text, this.charIndex, this.serial = 0});

  final String text;
  final int? charIndex;

  /// 같은 문장을 다시 읽어도 새 발화로 구분하기 위한 번호.
  final int serial;

  TtsUtterance at(int index) =>
      TtsUtterance(text: text, charIndex: index, serial: serial);
}

/// Speaks Korean guide prompts aloud for the video-call style screens
/// (튜토리얼 통화 연습, baseline 측정) — 탄카츄가 실제로 안내해주는 느낌을 준다.
///
/// Degrades silently: TTS 엔진이 없는 기기/테스트 환경에서도 화면이 죽지 않도록
/// 모든 실패를 조용히 삼킨다.
class TtsService {
  TtsService() {
    try {
      _tts
        // 실제로 소리가 나기 시작한 순간 — 입 모양을 문장 처음으로 다시 맞춘다.
        ..setStartHandler(() {
          final current = _disposed ? null : utterance.value;
          if (current != null) _set(current.at(0));
        })
        ..setProgressHandler((_, start, _, _) {
          final current = _disposed ? null : utterance.value;
          if (current != null) _set(current.at(start));
        })
        ..setCompletionHandler(_clear)
        ..setCancelHandler(_clear)
        ..setErrorHandler((_) => _clear());
    } catch (_) {
      // 플랫폼 채널이 없는 환경(테스트) — 위치 없이 시간 추정으로 움직인다.
    }
  }

  final FlutterTts _tts = FlutterTts()
    ..setLanguage('ko-KR')
    ..setSpeechRate(0.45)
    ..setPitch(1.05)
    ..awaitSpeakCompletion(true);

  /// 읽는 중인 문장. 읽지 않을 땐 null.
  final ValueNotifier<TtsUtterance?> utterance = ValueNotifier(null);

  int _serial = 0;
  bool _disposed = false;

  void _set(TtsUtterance? value) {
    if (!_disposed) utterance.value = value;
  }

  void _clear() => _set(null);

  /// [line] 하나를 읽고, 다 읽을 때까지 기다린다.
  Future<void> speak(String line) async {
    _set(TtsUtterance(text: line, serial: ++_serial));
    try {
      await _tts.speak(line);
    } catch (_) {
      // TTS unavailable — the on-screen caption still carries the guide.
    } finally {
      _clear();
    }
  }

  /// [lines]를 순서대로 읽는다. 각 줄이 끝날 때마다 [onLine]으로 알려줘서
  /// 화면이 현재 읽고 있는 문장을 자막처럼 보여줄 수 있게 한다.
  Future<void> speakSequence(
    List<String> lines, {
    void Function(String line)? onLine,
  }) async {
    for (final line in lines) {
      onLine?.call(line);
      await speak(line);
    }
  }

  Future<void> stop() async {
    _clear();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    utterance.dispose();
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// One instance per consumer screen — screens start a sequence in initState
/// and stop it in dispose, same lifecycle shape as [AudioRecorderService].
final ttsServiceProvider = Provider.autoDispose<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});
