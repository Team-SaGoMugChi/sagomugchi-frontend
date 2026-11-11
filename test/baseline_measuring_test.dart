import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/media/audio_recorder_service.dart';
import 'package:oddo/core/media/tts_service.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/baseline/application/baseline_reading_script.dart';
import 'package:oddo/features/baseline/presentation/screens/baseline_measuring_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Recorder implements AudioRecorderService {
  final started = Completer<bool>();
  final stopped = Completer<String?>();
  final amplitude = StreamController<double>.broadcast();
  int stops = 0;
  int pauses = 0;
  int resumes = 0;
  int starts = 0;

  @override
  Future<bool> start({required String fileName}) {
    starts++;
    return started.future;
  }

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
  final opening = Completer<void>();
  final lines = <String>[];

  @override
  final utterance = ValueNotifier<TtsUtterance?>(null);

  @override
  Future<void> speak(String line, {TtsPace pace = TtsPace.normal}) {
    lines.add(line);
    return lines.length == 1 ? opening.future : speaking.future;
  }

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
    expect(find.text('오또가 안내하고 있어요'), findsOneWidget);
    expect(tts.lines.single, contains('문장 여섯 개'));
    expect(
      recorder.starts,
      0,
      reason: 'guide audio must never enter the baseline',
    );
    await tester.tap(find.byTooltip('다 읽었어요'));
    expect(recorder.stops, 0);

    tts.opening.complete();
    await tester.pump();
    await tester.pump();
    expect(recorder.starts, 1);
    expect(find.text('통화를 준비하고 있어요'), findsOneWidget);

    recorder.started.complete(true);
    await tester
        .pump(); // Flush recorder completion before building its caption.
    await tester.pump();
    expect(
      find.textContaining(baselineReadingScript('').first),
      findsOneWidget,
    );
    expect(recorder.pauses, 0);
    expect(find.text('듣고 있어요 · 녹음 중'), findsOneWidget);
    // Silence never skips text or submits a partial measurement.
    await tester.pump(const Duration(seconds: 10));
    expect(
      find.textContaining(baselineReadingScript('').first),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('다 읽었어요'));
    await tester.pump();
    expect(
      find.textContaining(baselineReadingScript('').first),
      findsOneWidget,
    );
    expect(find.textContaining('목소리를 충분히'), findsOneWidget);
    for (final sentence in baselineReadingScript('')) {
      expect(find.textContaining(sentence), findsOneWidget);
    }
    for (var sample = 0; sample < 4; sample++) {
      recorder.amplitude.add(-20);
    }
    await tester.pump();
    await tester.tap(find.byTooltip('다 읽었어요'));
    await tester.pump();
    expect(recorder.pauses, 0);
    for (var sample = 0; sample < 20; sample++) {
      recorder.amplitude.add(-20);
    }
    await tester.pump();
    await tester.tap(find.byTooltip('다 읽었어요'));
    await tester.pump();
    expect(recorder.pauses, 1);
    expect(
      tts.lines,
      hasLength(2),
      reason: 'reading sentences are not spoken by the app',
    );
    tts.speaking.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('측정을 마무리하고 있어요'), findsOneWidget);
    await tester.tap(find.byTooltip('다 읽었어요'));
    expect(recorder.stops, 1);

    await tester.pumpWidget(const SizedBox());
    recorder.stopped.complete(null);
    await recorder.amplitude.close();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
