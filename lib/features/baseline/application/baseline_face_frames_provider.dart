import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../auth/application/auth_controller.dart';

/// Face captures collected throughout one baseline recording.
class BaselineFaceFrames extends Notifier<List<String>> {
  static const maxFrameCount = 400;
  List<int> _timestampsMs = const [];
  List<bool> _promptFlags = const [];

  @override
  List<String> build() {
    _timestampsMs = const [];
    _promptFlags = const [];
    final userId = ref.watch(
      authControllerProvider.select((value) => value.user?.id),
    );
    if (userId == null) return const [];
    final store = ref.read(localStoreProvider);
    if (store.getString(LocalStore.kBaselinePendingOwner) != userId) {
      return const [];
    }
    final paths = store.getStringList(LocalStore.kBaselinePendingFacePaths);
    final times = store.getStringList(LocalStore.kBaselinePendingFaceTimes);
    final flags = store.getStringList(
      LocalStore.kBaselinePendingFacePromptFlags,
    );
    final validMetadata =
        paths.length == times.length && paths.length == flags.length;
    final existing = <String>[];
    final existingTimes = <int>[];
    final existingFlags = <bool>[];
    for (var i = 0; i < paths.length; i++) {
      if (!File(paths[i]).existsSync()) continue;
      existing.add(paths[i]);
      if (validMetadata) {
        final time = int.tryParse(times[i]);
        if (time != null && time >= 0 && (flags[i] == '0' || flags[i] == '1')) {
          existingTimes.add(time);
          existingFlags.add(flags[i] == '1');
        }
      }
    }
    if (existingTimes.length == existing.length) {
      _timestampsMs = existingTimes;
      _promptFlags = existingFlags;
    }
    return existing;
  }

  List<int> get timestampsMs =>
      _timestampsMs.length == state.length ? _timestampsMs : const [];

  List<bool> get promptFlags =>
      _promptFlags.length == state.length ? _promptFlags : const [];

  void add(String path, {int? timestampMs, bool promptSpeaking = false}) {
    if (state.length >= maxFrameCount) return;
    final priorTimes = _timestampsMs;
    final priorFlags = _promptFlags;
    if (timestampMs != null &&
        priorTimes.length == state.length &&
        priorFlags.length == state.length) {
      _timestampsMs = [...priorTimes, timestampMs];
      _promptFlags = [...priorFlags, promptSpeaking];
    } else {
      _timestampsMs = const [];
      _promptFlags = const [];
    }
    state = [...state, path];
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;
    final store = ref.read(localStoreProvider);
    unawaited(store.setString(LocalStore.kBaselinePendingOwner, userId));
    unawaited(store.setStringList(LocalStore.kBaselinePendingFacePaths, state));
    if (_timestampsMs.length == state.length) {
      unawaited(
        store.setStringList(LocalStore.kBaselinePendingFaceTimes, [
          ..._timestampsMs.map((value) => '$value'),
        ]),
      );
      unawaited(
        store.setStringList(LocalStore.kBaselinePendingFacePromptFlags, [
          ..._promptFlags.map((value) => value ? '1' : '0'),
        ]),
      );
    }
  }

  void clear() {
    state = const [];
    _timestampsMs = const [];
    _promptFlags = const [];
    unawaited(
      ref.read(localStoreProvider).remove(LocalStore.kBaselinePendingFacePaths),
    );
    unawaited(
      ref.read(localStoreProvider).remove(LocalStore.kBaselinePendingFaceTimes),
    );
    unawaited(
      ref
          .read(localStoreProvider)
          .remove(LocalStore.kBaselinePendingFacePromptFlags),
    );
  }
}

final baselineFaceFramesProvider =
    NotifierProvider<BaselineFaceFrames, List<String>>(BaselineFaceFrames.new);
