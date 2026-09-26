import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../auth/application/auth_controller.dart';

/// Path of the still face photo captured during baseline 측정 (screen 19).
/// Mirrors [baselineRecordingProvider] for the voice file.
class BaselineFaceImage extends Notifier<String?> {
  @override
  String? build() {
    // A different account must capture its own image before uploading.
    final userId = ref.watch(
      authControllerProvider.select((value) => value.user?.id),
    );
    if (userId == null) return null;

    final store = ref.read(localStoreProvider);
    if (store.getString(LocalStore.kBaselinePendingOwner) != userId) {
      return null;
    }
    final path = store.getString(LocalStore.kBaselinePendingFacePath);
    return path != null && File(path).existsSync() ? path : null;
  }

  void set(String path) {
    state = path;
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;
    final store = ref.read(localStoreProvider);
    unawaited(store.setString(LocalStore.kBaselinePendingOwner, userId));
    unawaited(store.setString(LocalStore.kBaselinePendingFacePath, path));
  }

  void clear() {
    state = null;
    unawaited(
      ref.read(localStoreProvider).remove(LocalStore.kBaselinePendingFacePath),
    );
  }
}

final baselineFaceImageProvider = NotifierProvider<BaselineFaceImage, String?>(
  BaselineFaceImage.new,
);
