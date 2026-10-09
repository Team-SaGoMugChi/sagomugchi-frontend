import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/media/korean_lip_sync.dart';
import 'package:oddo/core/media/tts_service.dart';
import 'package:oddo/features/diary/presentation/widgets/call_room_background.dart';
import 'package:oddo/features/diary/presentation/widgets/talking_tankachu.dart';

/// [text] 한 글자를 읽는 동안 [phase](0~1) 시점의 입 모양.
MouthShape shapeOf(String text, {double phase = 0.5}) =>
    KoreanLipSync(text).shapeAt(phase);

void main() {
  group('KoreanLipSync', () {
    test('모음마다 입 모양이 다르다', () {
      final a = shapeOf('아');
      final i = shapeOf('이');
      final o = shapeOf('오');
      final u = shapeOf('우');

      expect(a.open, greaterThan(i.open));
      expect(i.width, greaterThan(a.width));
      expect(o.round, greaterThan(0.5));
      expect(u.round, greaterThan(0.5));
      expect(u.width, lessThan(a.width));
    });

    test('초성·받침 ㅁㅂㅍ에서는 입술이 닫힌다', () {
      expect(shapeOf('바', phase: 0.05), MouthShape.closed);
      expect(shapeOf('바', phase: 0.5).open, greaterThan(0.5));
      expect(shapeOf('암', phase: 0.9), MouthShape.closed);
      expect(shapeOf('앞', phase: 0.9), MouthShape.closed);
      // 다른 받침은 덜 벌어질 뿐 닫히지 않는다.
      expect(shapeOf('안', phase: 0.9).open, greaterThan(0));
    });

    test('이중모음은 앞 모음에서 뒤 모음으로 넘어간다', () {
      final start = shapeOf('와', phase: 0.1);
      final end = shapeOf('와', phase: 0.7);
      expect(start.round, greaterThan(end.round));
      expect(end.open, greaterThan(start.open));
    });

    test('띄어쓰기와 문장부호는 쉬고, 문장 밖은 다문 입이다', () {
      final lip = KoreanLipSync('네. 좋아');
      // '네' 1박, '.' 1.5박, ' ' 0.4박
      expect(lip.beatAtChar(1), 1);
      expect(lip.beatAtChar(2), 2.5);
      expect(lip.beatAtChar(3), closeTo(2.9, 1e-9));
      expect(lip.shapeAt(1.7), MouthShape.rest);
      expect(lip.shapeAt(-1), MouthShape.rest);
      expect(lip.shapeAt(lip.totalBeats + 1), MouthShape.rest);
      expect(KoreanLipSync('').shapeAt(0), MouthShape.rest);
    });
  });

  group('TtsService', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('flutter_tts');
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => 1);
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('읽는 동안만 문장을 알리고, 끝나면 비운다', () async {
      final tts = TtsService();
      final seen = <TtsUtterance?>[];
      tts.utterance.addListener(() => seen.add(tts.utterance.value));

      await tts.speak('안녕');
      await tts.speak('안녕');

      expect(seen.whereType<TtsUtterance>().map((u) => u.text), [
        '안녕',
        '안녕',
      ]);
      // 같은 문장을 다시 읽어도 새 발화로 구분된다.
      final serials = seen.whereType<TtsUtterance>().map((u) => u.serial);
      expect(serials.toSet(), hasLength(2));
      expect(tts.utterance.value, isNull);
      await tts.dispose();
    });
  });

  test('통화 배경은 18시부터 다음날 6시 전까지 밤이다', () {
    bool night(int hour) =>
        CallRoomBackground.isNight(DateTime(2026, 10, 9, hour));
    expect(night(5), isTrue);
    expect(night(6), isFalse);
    expect(night(17), isFalse);
    expect(night(18), isTrue);
    expect(night(23), isTrue);
  });

  group('TalkingTankachu', () {
    Widget host(
      ValueNotifier<TtsUtterance?> speech, {
      TankachuMood mood = TankachuMood.idle,
      TankachuExpression expression = TankachuExpression.neutral,
    }) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: TalkingTankachu(
            speech: speech,
            mood: mood,
            expression: expression,
            width: 300,
          ),
        ),
      ),
    );

    testWidgets('상태와 표정을 바꿔가며 말해도 화면이 깨지지 않는다', (tester) async {
      final speech = ValueNotifier<TtsUtterance?>(null);
      addTearDown(speech.dispose);

      for (final mood in TankachuMood.values) {
        for (final expression in TankachuExpression.values) {
          await tester.pumpWidget(
            host(speech, mood: mood, expression: expression),
          );
          speech.value = const TtsUtterance(text: '오늘 하루는 어땠어?', serial: 1);
          await tester.pump(const Duration(milliseconds: 300));
          speech.value = speech.value!.at(3);
          await tester.pump(const Duration(seconds: 3));
          speech.value = null;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('화면을 떠난 뒤 문장이 바뀌어도 오류가 나지 않는다', (tester) async {
      final speech = ValueNotifier<TtsUtterance?>(null);
      addTearDown(speech.dispose);

      await tester.pumpWidget(host(speech));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());

      speech.value = const TtsUtterance(text: '안녕', serial: 1);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
