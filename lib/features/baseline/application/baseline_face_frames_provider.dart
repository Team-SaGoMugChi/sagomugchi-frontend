import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../auth/application/auth_controller.dart';

/// Face captures collected throughout one baseline recording.
class BaselineFaceFrames extends Notifier<List<String>> {
  @override
  List<String> build() {
    final userId = ref.watch(
      authControllerProvider.select((value) => value.user?.id),
    );
    if (userId == null) return const [];
    final store = ref.read(localStoreProvider);
    if (store.getString(LocalStore.kBaselinePendingOwner) != userId) {
      return const [];
    }
    return store
        .getStringList(LocalStore.kBaselinePendingFacePaths)
        .where((path) => File(path).existsSync())
        .toList();
  }

  void add(String path) {
    if (state.length >= 8) return;
    state = [...state, path];
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;
    final store = ref.read(localStoreProvider);
    unawaited(store.setString(LocalStore.kBaselinePendingOwner, userId));
    unawaited(store.setStringList(LocalStore.kBaselinePendingFacePaths, state));
  }

  void clear() {
    state = const [];
    unawaited(
      ref.read(localStoreProvider).remove(LocalStore.kBaselinePendingFacePaths),
    );
  }
}

final baselineFaceFramesProvider =
    NotifierProvider<BaselineFaceFrames, List<String>>(BaselineFaceFrames.new);
