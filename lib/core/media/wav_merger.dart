import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 차례마다 따로 녹음한 WAV(PCM)를 하나로 잇는다 — 말하기 대화는 차례별로
/// 녹음하지만, 감정 분석(`/diary/step2/analyze`)은 녹음 파일 하나를 받는다.
///
/// 같은 `AudioRecorderService` 설정으로 녹음한 파일이라 형식(fmt)이 같아야 한다.
/// 다르면 [FormatException] — 샘플레이트가 다른 PCM을 이으면 소리가 망가진다.
abstract final class WavMerger {
  /// Actual PCM duration, used to place per-turn photos on the merged audio timeline.
  static Future<int> durationMs(String path) async {
    final wav = _parse(await File(path).readAsBytes());
    final format = ByteData.sublistView(wav.format);
    if (wav.format.length < 16) throw const FormatException('invalid WAV fmt');
    final bytesPerSecond = format.getUint32(8, Endian.little);
    if (bytesPerSecond == 0) throw const FormatException('invalid WAV rate');
    return (wav.data.length * 1000 / bytesPerSecond).round();
  }

  /// [paths]를 순서대로 이어 `<tmp>/<fileName>.wav`로 쓰고 경로를 돌려준다.
  /// 파일이 하나면 복사하지 않고 그 경로를 그대로 돌려준다.
  static Future<String> mergeFiles(
    List<String> paths, {
    required String fileName,
  }) async {
    if (paths.length == 1) return paths.single;
    final merged = merge([
      for (final path in paths) await File(path).readAsBytes(),
    ]);
    final dir = await getTemporaryDirectory();
    final output = File('${dir.path}/$fileName.wav');
    await output.writeAsBytes(merged, flush: true);
    return output.path;
  }

  /// WAV 바이트들을 이어 붙인 WAV 바이트. fmt는 첫 파일 것을 쓴다.
  static Uint8List merge(List<Uint8List> files) {
    if (files.isEmpty) throw ArgumentError.value(files, 'files', 'empty');
    Uint8List? format;
    final pcm = BytesBuilder(copy: false);
    for (final file in files) {
      final wav = _parse(file);
      if (format == null) {
        format = wav.format;
      } else if (!_sameBytes(format, wav.format)) {
        throw const FormatException('WAV formats differ');
      }
      pcm.add(wav.data);
    }
    final data = pcm.takeBytes();
    final pad = data.length.isOdd ? 1 : 0;

    final out = BytesBuilder(copy: false)
      ..add(_ascii('RIFF'))
      ..add(_uint32(4 + 8 + format!.length + 8 + data.length + pad))
      ..add(_ascii('WAVE'))
      ..add(_ascii('fmt '))
      ..add(_uint32(format.length))
      ..add(format)
      ..add(_ascii('data'))
      ..add(_uint32(data.length))
      ..add(data);
    if (pad == 1) out.addByte(0);
    return out.takeBytes();
  }

  static ({Uint8List format, Uint8List data}) _parse(Uint8List bytes) {
    if (bytes.length < 12 ||
        _id(bytes, 0) != 'RIFF' ||
        _id(bytes, 8) != 'WAVE') {
      throw const FormatException('not a WAV file');
    }
    final view = ByteData.sublistView(bytes);
    Uint8List? format;
    Uint8List? data;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _id(bytes, offset);
      final start = offset + 8;
      var size = view.getUint32(offset + 4, Endian.little);
      // 헤더 크기가 실제보다 크면(녹음이 덜 닫힌 파일) 남은 바이트까지만 읽는다.
      if (start + size > bytes.length) size = bytes.length - start;
      final body = Uint8List.sublistView(bytes, start, start + size);
      if (id == 'fmt ') format = body;
      if (id == 'data') data = body;
      offset = start + size + (size.isOdd ? 1 : 0);
    }
    if (format == null || data == null) {
      throw const FormatException('WAV without fmt or data chunk');
    }
    return (format: format, data: data);
  }

  static String _id(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes, offset, offset + 4);

  static Uint8List _ascii(String id) => Uint8List.fromList(id.codeUnits);

  static Uint8List _uint32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
