import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/auth/application/auth_controller.dart';
import 'package:oddo/features/auth/data/models/app_user.dart';
import 'package:oddo/features/notifications/application/diary_reminder_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthController {
  void enter(String? id) => state = AuthState(
    user: id == null
        ? null
        : AppUser(id: id, email: '$id@example.test', nickname: 'test'),
  );
}

class _Service extends DiaryReminderService {
  bool permission = true;
  bool available = true;
  bool failNextEnable = false;
  Completer<bool>? pendingPermission;
  final calls = <(bool, int, int)>[];
  @override
  Future<bool> requestPermission() async =>
      pendingPermission == null ? permission : pendingPermission!.future;
  @override
  Future<bool> configure({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    calls.add((enabled, hour, minute));
    if (enabled && failNextEnable) {
      failNextEnable = false;
      throw StateError('test scheduling failure');
    }
    return available;
  }
}

void main() {
  late ProviderContainer container;
  late _Service service;
  late LocalStore store;
  late _Auth auth;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance());
    service = _Service();
    container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        diaryReminderServiceProvider.overrideWithValue(service),
        authControllerProvider.overrideWith(_Auth.new),
      ],
    );
    auth = container.read(authControllerProvider.notifier) as _Auth;
    auth.enter('first');
    container.listen(diaryReminderControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() => container.dispose());

  test('opt in schedules selected time and disabling cancels', () async {
    final controller = container.read(diaryReminderControllerProvider.notifier);
    expect(container.read(diaryReminderControllerProvider).enabled, isFalse);
    expect(
      await controller.update(enabled: true, hour: 20, minute: 30),
      isTrue,
    );
    expect(service.calls.last, (true, 20, 30));
    expect(store.getBool(LocalStore.kReminderEnabled), isTrue);
    expect(await controller.update(enabled: false), isTrue);
    expect(service.calls.last, (false, 20, 30));
    expect(store.getBool(LocalStore.kReminderEnabled), isFalse);
  });
  test('permission rejection does not claim scheduling succeeded', () async {
    service.permission = false;
    expect(
      await container
          .read(diaryReminderControllerProvider.notifier)
          .update(enabled: true),
      isFalse,
    );
    expect(container.read(diaryReminderControllerProvider).enabled, isFalse);
    expect(container.read(diaryReminderControllerProvider).busy, isFalse);
    expect(service.calls.where((call) => call.$1), isEmpty);
  });
  test(
    'platform failure restores previous schedule and releases busy state',
    () async {
      service.failNextEnable = true;
      expect(
        await container
            .read(diaryReminderControllerProvider.notifier)
            .update(enabled: true),
        isFalse,
      );
      expect(service.calls.last.$1, isFalse);
      expect(container.read(diaryReminderControllerProvider).enabled, isFalse);
      expect(container.read(diaryReminderControllerProvider).busy, isFalse);
      expect(store.getBool(LocalStore.kReminderEnabled), isFalse);
    },
  );
  test(
    'logout cancels and another account does not inherit reminders',
    () async {
      await container
          .read(diaryReminderControllerProvider.notifier)
          .update(enabled: true);
      auth.enter(null);
      await Future<void>.delayed(Duration.zero);
      expect(service.calls.last.$1, isFalse);
      auth.enter('second');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(diaryReminderControllerProvider).enabled, isFalse);
      expect(service.calls.last.$1, isFalse);
    },
  );
  test(
    'account switch while asking permission cannot enable old reminder',
    () async {
      service.pendingPermission = Completer<bool>();
      final pending = container
          .read(diaryReminderControllerProvider.notifier)
          .update(enabled: true);
      auth.enter('second');
      await Future<void>.delayed(Duration.zero);
      service.pendingPermission!.complete(true);
      expect(await pending, isFalse);
      expect(service.calls.last.$1, isFalse);
      expect(store.getBool(LocalStore.kReminderEnabled), isFalse);
    },
  );
  test(
    'restoration schedules saved settings without asking permission',
    () async {
      await container
          .read(diaryReminderControllerProvider.notifier)
          .update(enabled: true, hour: 19);
      auth.enter(null);
      await Future<void>.delayed(Duration.zero);
      service.permission = false;
      auth.enter('first');
      await Future<void>.delayed(Duration.zero);
      expect(service.calls.last, (true, 19, 0));
      expect(container.read(diaryReminderControllerProvider).enabled, isTrue);
    },
  );
}
