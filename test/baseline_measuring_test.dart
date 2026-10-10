import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/media/audio_recorder_service.dart';
import 'package:oddo/core/media/tts_service.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/baseline/presentation/screens/baseline_measuring_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Recorder implements AudioRecorderService {
  final started = Completer<bool>();
  final stopped = Completer<String?>();
  final amplitude = StreamController<double>.broadcast();
  int stops = 0;
  int pauses = 0;
  int resumes = 0;

  @override
  Future<bool> start({required String fileName}) => started.future;

  @override
  Future<String?> stop() {
    stops++;
    return stopped.future;
  }

  @override
  Future<bool> pause() async {
    pauses++;
    return true;
  }

  @override
  Future<bool> resume() async {
    resumes++;
    return true;
  }

  @override
  Stream<double> amplitudeStream({
    Duration interval = const Duration(milliseconds: 300),
  }) => amplitude.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tts implements TtsService {
  final speaking = Completer<void>();

  @override
  final utterance = ValueNotifier<TtsUtterance?>(null);

  @override
  Future<void> speak(String line) => speaking.future;

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('capture status follows recorder and prevents repeated finish', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final recorder = _Recorder();
    final tts = _Tts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioRecorderProvider.overrideWithValue(recorder),
          ttsServiceProvider.overrideWithValue(tts),
          localStoreProvider.overrideWithValue(LocalStore(prefs)),
        ],
        child: const MaterialApp(home: BaselineMeasuringScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('60%'), findsNothing);
    expect(find.text('45%'), findsNothing);
    expect(find.text('듣고 있어요 · 녹음 중'), findsNothing);
    expect(find.text('통화를 준비하고 있어요'), findsOneWidget);
    await tester.tap(find.byTooltip('측정 마치기'));
    expect(recorder.stops, 0);

    recorder.started.complete(true);
    await tester.pump();
    expect(find.text('탄카츄가 안내하고 있어요'), findsOneWidget);
    expect(recorder.pauses, 1);
    tts.speaking.complete();
    await tester.pump();
    recorder.amplitude.add(-10);
    await tester.pump();
    expect(recorder.resumes, 1);
    expect(find.text('듣고 있어요 · 녹음 중'), findsOneWidget);
    await tester.tap(find.byTooltip('측정 마치기'));
    await tester.pump();
    recorder.amplitude.add(-10);
    await tester.pump();
    expect(find.text('듣고 있어요 · 녹음 중'), findsNothing);
    expect(find.text('측정을 마무리하고 있어요'), findsOneWidget);
    await tester.tap(find.byTooltip('측정 마치기'));
    expect(recorder.stops, 1);

    await tester.pumpWidget(const SizedBox());
    recorder.stopped.complete(null);
    await recorder.amplitude.close();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
