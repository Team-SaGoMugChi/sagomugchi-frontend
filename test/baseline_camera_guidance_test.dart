import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/baseline/application/baseline_camera_guidance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native quality readings select silent guidance and keep normal clear',
    () async {
      Map<String, dynamic>? reading;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BaselineCameraGuidance.channel, (
            call,
          ) async {
            expect(call.method, 'inspect');
            expect(call.arguments, 'test-only.jpg');
            return reading;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(BaselineCameraGuidance.channel, null);
      });
      final guidance = BaselineCameraGuidance();
      for (final sample in [
        (20, 0.4, CameraHint.tooDark),
        (240, 0.4, CameraHint.tooBright),
        (130, null, CameraHint.faceMissing),
        (130, 0.15, CameraHint.tooFar),
        (130, 0.8, CameraHint.tooClose),
        (130, 0.4, null),
      ]) {
        reading = {'brightness': sample.$1, 'faceWidth': sample.$2};
        expect(await guidance.inspect('test-only.jpg'), sample.$3);
      }
      reading = null;
      await expectLater(guidance.inspect('test-only.jpg'), throwsStateError);
      reading = {'brightness': double.nan, 'faceWidth': 0.4};
      await expectLater(guidance.inspect('test-only.jpg'), throwsStateError);
    },
  );

  test(
    'brief movements do not flicker and recovery clears after two samples',
    () {
      final hints = CameraHintStabilizer();
      expect(hints.update(CameraHint.tooFar), isNull);
      expect(hints.update(CameraHint.tooClose), isNull);
      expect(hints.update(CameraHint.tooFar), isNull);
      expect(hints.update(CameraHint.tooFar), isNull);
      expect(hints.update(CameraHint.tooFar), CameraHint.tooFar);
      expect(hints.update(null), CameraHint.tooFar);
      expect(hints.update(null), isNull);
      hints.update(CameraHint.tooDark);
      hints.update(CameraHint.tooDark);
      expect(hints.update(CameraHint.tooDark), CameraHint.tooDark);
      hints.reset();
      expect(hints.current, isNull);
      expect(hints.update(CameraHint.tooDark), isNull);
    },
  );
}
