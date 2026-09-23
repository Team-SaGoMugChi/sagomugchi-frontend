import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';

/// Path of the voice file recorded during baseline 측정 (screen 19).
/// Phase 4 uploads it to the AI server to compute the voice baseline.
class BaselineRecording extends Notifier<String?> {
  @override
  String? build() {
    // Captures belong to the account that recorded them, including retries.
    ref.watch(authControllerProvider.select((value) => value.user?.id));
    return null;
  }

  void set(String path) => state = path;

  void clear() => state = null;
}

final baselineRecordingProvider = NotifierProvider<BaselineRecording, String?>(
  BaselineRecording.new,
);
