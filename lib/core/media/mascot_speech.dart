import 'dart:async';

import 'package:flutter/foundation.dart';

import 'korean_lip_sync.dart';
import 'tts_service.dart';

/// 탄카츄 입이 따라갈 문장 — 소리로 읽을 땐 [TtsService.utterance]를 그대로
/// 따르고, 소리를 끈 화면은 [mouthOnly]로 말풍선 문장을 넣어 입만 움직인다.
///
/// 통화 화면마다 하나씩 만들고 화면이 사라질 때 [dispose]한다.
class MascotSpeech extends ValueNotifier<TtsUtterance?> {
  MascotSpeech(this._tts) : super(_tts.utterance.value) {
    _tts.utterance.addListener(_mirror);
  }

  final TtsService _tts;
  int _mutedSerial = 0;
  Timer? _mutedTimer;
  Completer<void>? _mutedDone;

  void _mirror() {
    if (_mutedDone != null) return;
    value = _tts.utterance.value;
  }

  /// 소리 없이 [text]를 읽는 시간만큼 입을 움직인다. 끝나면(또는
  /// [stopMouthOnly]로 끊으면) 완료된다.
  Future<void> mouthOnly(String text) {
    stopMouthOnly();
    final seconds =
        KoreanLipSync(text).totalBeats / KoreanLipSync.syllablesPerSecond;
    final done = _mutedDone = Completer<void>();
    // TTS 발화 번호와 겹치지 않게 음수로 센다.
    value = TtsUtterance(text: text, serial: --_mutedSerial);
    _mutedTimer = Timer(
      Duration(milliseconds: (seconds * 1000).round()),
      stopMouthOnly,
    );
    return done.future;
  }

  void stopMouthOnly() {
    _mutedTimer?.cancel();
    _mutedTimer = null;
    final done = _mutedDone;
    if (done == null) return;
    _mutedDone = null;
    value = null;
    done.complete();
  }

  @override
  void dispose() {
    _tts.utterance.removeListener(_mirror);
    _mutedTimer?.cancel();
    _mutedDone?.complete();
    _mutedDone = null;
    super.dispose();
  }
}
