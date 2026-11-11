import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/dummy/baseline_dummy.dart';
import '../../auth/application/auth_controller.dart';

/// One script is shared by explanation, preview and the actual recording.
List<String> baselineReadingScript(String nickname) => [
  '안녕하세요. 저는 ${nickname.trim().isEmpty ? '오또 사용자' : nickname.trim()}입니다.',
  ...BaselineDummy.readingSentences.skip(1),
];

final baselineReadingScriptProvider = Provider<List<String>>(
  (ref) => baselineReadingScript(
    ref.watch(authControllerProvider).user?.nickname ?? '',
  ),
);
