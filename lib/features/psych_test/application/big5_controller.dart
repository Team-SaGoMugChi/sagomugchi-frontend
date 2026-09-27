import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/application/auth_controller.dart';
import '../data/psych_providers.dart';
import '../domain/ipip_big5.dart';

class Big5State {
  const Big5State({
    required this.answers,
    this.currentIndex = 0,
    this.isSaving = false,
    this.errorMessage,
  });

  factory Big5State.empty() =>
      Big5State(answers: List<int?>.filled(ipipBig5Items.length, null));

  final List<int?> answers;
  final int currentIndex;
  final bool isSaving;
  final String? errorMessage;

  int get answeredCount => answers.whereType<int>().length;
  int? get selectedAnswer => answers[currentIndex];
  bool get canGoBack => currentIndex > 0;
  bool get isLastQuestion => currentIndex == answers.length - 1;

  Big5State copyWith({
    List<int?>? answers,
    int? currentIndex,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) => Big5State(
    answers: answers ?? this.answers,
    currentIndex: currentIndex ?? this.currentIndex,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

class Big5Controller extends Notifier<Big5State> {
  Future<void> _pendingWrite = Future.value();
  String? _ownerId;

  @override
  Big5State build() {
    final authId = ref.watch(
      authControllerProvider.select((value) => value.user?.id),
    );
    final useDummy = ref.watch(appConfigProvider).useDummyData;
    _ownerId = authId ?? (useDummy ? 'dummy-user' : null);
    return _restoreProgress();
  }

  Big5State _restoreProgress() {
    final ownerId = _ownerId;
    if (ownerId == null) return Big5State.empty();

    final raw = ref
        .read(localStoreProvider)
        .getString(LocalStore.kBig5Progress);
    if (raw == null) return Big5State.empty();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['ownerId'] != ownerId ||
          json['instrument'] != ipipBig5Instrument) {
        return Big5State.empty();
      }
      final values = (json['answers'] as List<dynamic>)
          .map((value) => value == null ? null : (value as num).toInt())
          .toList();
      if (values.length != ipipBig5Items.length ||
          values.whereType<int>().any((value) => value < 1 || value > 5)) {
        return Big5State.empty();
      }
      final firstMissing = values.indexWhere((value) => value == null);
      return Big5State(
        answers: values,
        currentIndex: firstMissing < 0 ? values.length - 1 : firstMissing,
      );
    } catch (_) {
      return Big5State.empty();
    }
  }

  Future<void> selectAnswer(int value) {
    if (value < 1 || value > 5 || state.isSaving) return Future.value();
    final answers = [...state.answers]..[state.currentIndex] = value;
    state = state.copyWith(answers: answers, clearError: true);
    // Selection callbacks are synchronous UI hooks. Keep a failed device write
    // from becoming an unhandled async error; [next] reports it to the user.
    return _queueProgressWrite().catchError((_) {});
  }

  Future<bool> next() async {
    if (state.selectedAnswer == null || state.isSaving) return false;
    try {
      await _pendingWrite;
    } catch (_) {
      state = state.copyWith(errorMessage: '답변을 기기에 임시 저장하지 못했어요. 다시 시도해주세요.');
      return false;
    }
    if (!state.isLastQuestion) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
      await _queueProgressWrite();
      return false;
    }

    final responses = state.answers.whereType<int>().toList();
    if (responses.length != ipipBig5Items.length) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final now = DateTime.now().toUtc();
      await ref
          .read(psychRepositoryProvider)
          .saveBig5(
            scores: scoreIpipBig5(responses),
            instrument: ipipBig5Instrument,
            completedAt: now,
          );
      await ref.read(localStoreProvider).remove(LocalStore.kBig5Progress);
      ref.invalidate(psychResultProvider);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void previous() {
    if (!state.canGoBack || state.isSaving) return;
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      clearError: true,
    );
  }

  Future<void> reset() async {
    state = Big5State.empty();
    await ref.read(localStoreProvider).remove(LocalStore.kBig5Progress);
  }

  Future<void> _queueProgressWrite() {
    final ownerId = _ownerId;
    if (ownerId == null) return Future.value();
    final snapshot = jsonEncode({
      'ownerId': ownerId,
      'instrument': ipipBig5Instrument,
      'answers': state.answers,
    });
    _pendingWrite = _pendingWrite
        .catchError((_) {})
        .then(
          (_) => ref
              .read(localStoreProvider)
              .setString(LocalStore.kBig5Progress, snapshot),
        );
    return _pendingWrite;
  }
}

final big5ControllerProvider = NotifierProvider<Big5Controller, Big5State>(
  Big5Controller.new,
);
