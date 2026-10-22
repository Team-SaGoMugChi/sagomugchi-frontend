import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../network/api_client.dart';

/// Keeps synthesized audio only in the temporary directory for this playback.
class ClovaVoicePlayer {
  ClovaVoicePlayer(this.api);
  final ApiClient api;
  VideoPlayerController? _player;
  File? _file;
  int _generation = 0;

  Future<void> speak(String text, String voice) async {
    await stop();
    final generation = _generation;
    final result = await api.post(
      '/tts',
      body: {'text': text, 'speaker': voice},
    );
    if (generation != _generation) return;
    final directory = await getTemporaryDirectory();
    if (generation != _generation) return;
    final file = File(
      '${directory.path}/oddo_tts_${DateTime.now().microsecondsSinceEpoch}.mp3',
    );
    try {
      await file.writeAsBytes(base64Decode(result['audio_base64'] as String));
      if (generation != _generation) return;
      _file = file;
      final player = VideoPlayerController.file(file);
      _player = player;
      await player.initialize();
      if (generation != _generation) return;
      await player.play();
      while (generation == _generation) {
        if (player.value.hasError) throw StateError('음성 재생 실패');
        if (player.value.isCompleted) break;
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    } finally {
      if (generation == _generation) await stop();
      await _delete(file);
    }
  }

  Future<void> stop() async {
    _generation++;
    final player = _player;
    final file = _file;
    _player = null;
    _file = null;
    try {
      await player?.dispose();
    } finally {
      if (file != null) await _delete(file);
    }
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A platform cleanup failure must not replay the completed utterance.
    }
  }
}
