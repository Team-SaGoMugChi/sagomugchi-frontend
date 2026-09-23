import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';

/// Path of the still face photo captured during baseline 측정 (screen 19).
/// Mirrors [baselineRecordingProvider] for the voice file.
class BaselineFaceImage extends Notifier<String?> {
  @override
  String? build() {
    // A different account must capture its own image before uploading.
    ref.watch(authControllerProvider.select((value) => value.user?.id));
    return null;
  }

  void set(String path) => state = path;

  void clear() => state = null;
}

final baselineFaceImageProvider = NotifierProvider<BaselineFaceImage, String?>(
  BaselineFaceImage.new,
);
