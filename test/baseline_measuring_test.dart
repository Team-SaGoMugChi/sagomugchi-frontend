import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/media/audio_recorder_service.dart';
import 'package:oddo/core/media/tts_service.dart';
import 'package:oddo/features/baseline/presentation/screens/baseline_measuring_screen.dart';

class _Recorder implements AudioRecorderService {
  final started = Completer<bool>();
  final stopped = Completer<String?>();
  int stops = 0;

  @override
  Future<bool> start({required String fileName}) => started.future;

  @override
  Future<String?> stop() {
    stops++;
    return stopped.future;
  }

  @override
  Stream<double> amplitudeStream({
    Duration interval = const Duration(milliseconds: 300),
  }) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tts implements TtsService {
  final speaking = Completer<void>();

  @override
  Future<void> speak(String line) => speaking.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('capture status follows recorder and prevents repeated finish', (
    tester,
  ) async {
    final recorder = _Recorder();
    final tts = _Tts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioRecorderProvider.overrideWithValue(recorder),
          ttsServiceProvider.overrideWithValue(tts),
        ],
        child: const MaterialApp(home: BaselineMeasuringScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('60%'), findsNothing);
    expect(find.text('45%'), findsNothing);
    expect(find.text('녹음 중'), findsNothing);
    await tester.tap(find.text('측정을 준비하고 있어요'));
    expect(recorder.stops, 0);

    recorder.started.complete(true);
    await tester.pump();
    expect(find.text('녹음 중'), findsOneWidget);
    await tester.tap(find.text('측정 마치고 분석하기'));
    await tester.pump();
    expect(find.text('녹음 중'), findsNothing);
    expect(find.text('측정을 마무리하고 있어요'), findsOneWidget);
    await tester.tap(find.text('측정을 마무리하고 있어요'));
    expect(recorder.stops, 1);

    await tester.pumpWidget(const SizedBox());
    recorder.stopped.complete(null);
    tts.speaking.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
