import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../auth/application/auth_controller.dart';

/// Path of the voice file recorded during baseline 측정 (screen 19).
/// Phase 4 uploads it to the AI server to compute the voice baseline.
class BaselineRecording extends Notifier<String?> {
  @override
  String? build() {
    // Captures belong to the account that recorded them, including retries.
    final userId = ref.watch(
      authControllerProvider.select((value) => value.user?.id),
    );
    if (userId == null) return null;

    final store = ref.read(localStoreProvider);
    if (store.getString(LocalStore.kBaselinePendingOwner) != userId) {
      return null;
    }
    final path = store.getString(LocalStore.kBaselinePendingVoicePath);
    return path != null && File(path).existsSync() ? path : null;
  }

  void set(String path) {
    state = path;
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;
    final store = ref.read(localStoreProvider);
    unawaited(store.setString(LocalStore.kBaselinePendingOwner, userId));
    unawaited(store.setString(LocalStore.kBaselinePendingVoicePath, path));
  }

  void clear() {
    state = null;
    unawaited(
      ref.read(localStoreProvider).remove(LocalStore.kBaselinePendingVoicePath),
    );
  }
}

final baselineRecordingProvider = NotifierProvider<BaselineRecording, String?>(
  BaselineRecording.new,
);
