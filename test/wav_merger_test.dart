import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/media/wav_merger.dart';

/// PCM 16-bit 모노 WAV. [extraChunk]면 fmt와 data 사이에 LIST 청크를 끼운다.
Uint8List _wav(List<int> samples, {int sampleRate = 16000, bool extraChunk = false}) {
  final data = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(data);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, samples[i], Endian.little);
  }
  final fmt = ByteData(16)
    ..setUint16(0, 1, Endian.little) // PCM
    ..setUint16(2, 1, Endian.little) // mono
    ..setUint32(4, sampleRate, Endian.little)
    ..setUint32(8, sampleRate * 2, Endian.little)
    ..setUint16(12, 2, Endian.little)
    ..setUint16(14, 16, Endian.little);
  final list = extraChunk ? [..._chunk('LIST', Uint8List(3))] : <int>[];
  final body = [
    ...'WAVE'.codeUnits,
    ..._chunk('fmt ', fmt.buffer.asUint8List()),
    ...list,
    ..._chunk('data', data),
  ];
  return Uint8List.fromList([...'RIFF'.codeUnits, ..._u32(body.length), ...body]);
}

List<int> _chunk(String id, Uint8List body) => [
  ...id.codeUnits,
  ..._u32(body.length),
  ...body,
  if (body.length.isOdd) 0,
];

List<int> _u32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

List<int> _samples(Uint8List wav) {
  final view = ByteData.sublistView(wav);
  expect(String.fromCharCodes(wav, 36, 40), 'data');
  final size = view.getUint32(40, Endian.little);
  return [for (var i = 0; i < size; i += 2) view.getInt16(44 + i, Endian.little)];
}

void main() {
  test('joins PCM samples in order under one header', () {
    final merged = WavMerger.merge([
      _wav([1, 2, 3]),
      _wav([4, 5], extraChunk: true),
    ]);

    final view = ByteData.sublistView(merged);
    expect(String.fromCharCodes(merged, 0, 4), 'RIFF');
    expect(view.getUint32(4, Endian.little), merged.length - 8);
    expect(view.getUint32(24, Endian.little), 16000);
    expect(_samples(merged), [1, 2, 3, 4, 5]);
  });

  test('rejects recordings with different formats', () {
    expect(
      () => WavMerger.merge([_wav([1]), _wav([2], sampleRate: 44100)]),
      throwsFormatException,
    );
  });

  test('rejects bytes that are not a WAV file', () {
    expect(
      () => WavMerger.merge([Uint8List.fromList('not audio'.codeUnits)]),
      throwsFormatException,
    );
  });

  test('reads only the bytes present when the data size overstates them', () {
    final truncated = _wav([7, 8, 9]);
    ByteData.sublistView(truncated).setUint32(40, 0xFFFFFFFF, Endian.little);

    expect(_samples(WavMerger.merge([truncated])), [7, 8, 9]);
  });
}
