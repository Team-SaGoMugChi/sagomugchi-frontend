import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/storage/local_store.dart';
import '../../auth/application/auth_controller.dart';

class DiaryReminderService {
  static const channel = MethodChannel('app.oddo.oddo/diary_reminder');
  Future<void> _pending = Future.value();

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await channel.invokeMethod<bool>('requestPermission') ?? false;
    }
    return (await Permission.notification.request()).isGranted;
  }

  /// Serialize account changes and settings writes so the latest request wins.
  Future<bool> configure({
    required bool enabled,
    required int hour,
    required int minute,
  }) {
    final completion = Completer<bool>();
    _pending = _pending.then((_) async {
      try {
        completion.complete(
          await channel.invokeMethod<bool>('configure', {
                'enabled': enabled,
                'hour': hour,
                'minute': minute,
              }) ??
              false,
        );
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    });
    return completion.future;
  }
}

final diaryReminderServiceProvider = Provider((ref) => DiaryReminderService());

class DiaryReminderSettings {
  const DiaryReminderSettings({
    this.enabled = false,
    this.hour = 21,
    this.minute = 0,
    this.busy = false,
  });
  final bool enabled;
  final int hour;
  final int minute;
  final bool busy;
}

class DiaryReminderController extends Notifier<DiaryReminderSettings> {
  int _generation = 0;

  @override
  DiaryReminderSettings build() {
    final owner = ref.watch(
      authControllerProvider.select((value) => value.user?.id),
    );
    final store = ref.read(localStoreProvider);
    final sameOwner =
        owner != null && store.getString(LocalStore.kReminderOwner) == owner;
    final settings = DiaryReminderSettings(
      enabled: sameOwner && store.getBool(LocalStore.kReminderEnabled),
      hour: sameOwner
          ? (int.tryParse(store.getString(LocalStore.kReminderHour) ?? '') ??
                    21)
                .clamp(0, 23)
          : 21,
      minute: sameOwner
          ? (int.tryParse(store.getString(LocalStore.kReminderMinute) ?? '') ??
                    0)
                .clamp(0, 59)
          : 0,
    );
    final generation = ++_generation;
    Future.microtask(() async {
      if (!ref.mounted || generation != _generation) return;
      try {
        final allowed = await ref
            .read(diaryReminderServiceProvider)
            .configure(
              enabled: settings.enabled,
              hour: settings.hour,
              minute: settings.minute,
            );
        if (ref.mounted &&
            generation == _generation &&
            !state.busy &&
            settings.enabled &&
            !allowed) {
          state = DiaryReminderSettings(
            hour: settings.hour,
            minute: settings.minute,
          );
          await store.setBool(LocalStore.kReminderEnabled, false);
        }
      } catch (_) {
        // Unsupported platforms must not prevent startup or session restoration.
      }
    });
    return settings;
  }

  Future<bool> update({required bool enabled, int? hour, int? minute}) async {
    if (state.busy || ref.read(authControllerProvider).user == null) {
      return false;
    }
    final generation = _generation;
    final owner = ref.read(authControllerProvider).user!.id;
    final previous = state;
    final next = DiaryReminderSettings(
      enabled: enabled,
      hour: hour ?? previous.hour,
      minute: minute ?? previous.minute,
    );
    if (next.hour < 0 ||
        next.hour > 23 ||
        next.minute < 0 ||
        next.minute > 59) {
      return false;
    }
    state = DiaryReminderSettings(
      enabled: previous.enabled,
      hour: previous.hour,
      minute: previous.minute,
      busy: true,
    );
    try {
      final service = ref.read(diaryReminderServiceProvider);
      if (enabled && !previous.enabled && !await service.requestPermission()) {
        return false;
      }
      if (!ref.mounted || generation != _generation) return false;
      final allowed = await service.configure(
        enabled: enabled,
        hour: next.hour,
        minute: next.minute,
      );
      if (!ref.mounted || generation != _generation) return false;
      if (enabled && !allowed) {
        state = DiaryReminderSettings(hour: next.hour, minute: next.minute);
        await ref
            .read(localStoreProvider)
            .setBool(LocalStore.kReminderEnabled, false);
        return false;
      }
      final store = ref.read(localStoreProvider);
      await store.setString(LocalStore.kReminderOwner, owner);
      await store.setString(LocalStore.kReminderHour, next.hour.toString());
      await store.setString(LocalStore.kReminderMinute, next.minute.toString());
      await store.setBool(LocalStore.kReminderEnabled, enabled);
      if (!ref.mounted || generation != _generation) return false;
      state = next;
      return true;
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        try {
          await ref
              .read(diaryReminderServiceProvider)
              .configure(
                enabled: previous.enabled,
                hour: previous.hour,
                minute: previous.minute,
              );
        } catch (_) {
          // Still report failure if the platform cannot restore the prior setting.
        }
      }
      return false;
    } finally {
      if (ref.mounted && generation == _generation && state.busy) {
        state = previous;
      }
    }
  }
}

final diaryReminderControllerProvider =
    NotifierProvider<DiaryReminderController, DiaryReminderSettings>(
      DiaryReminderController.new,
    );
