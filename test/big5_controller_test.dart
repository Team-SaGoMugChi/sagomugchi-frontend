import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/auth/application/auth_controller.dart';
import 'package:oddo/features/auth/data/models/app_user.dart';
import 'package:oddo/features/psych_test/application/big5_controller.dart';
import 'package:oddo/features/psych_test/data/models/psych_result.dart';
import 'package:oddo/features/psych_test/data/psych_providers.dart';
import 'package:oddo/features/psych_test/data/repositories/psych_repository.dart';
import 'package:oddo/features/psych_test/domain/ipip_big5.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testConfig = AppConfig(
  environment: AppEnvironment.dev,
  appName: 'Oddo test',
  apiBaseUrl: '',
  useDummyData: true,
);

class _AuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    user: AppUser(id: 'first', email: 'first@test.dev', nickname: 'first'),
  );

  void enter(String id) {
    state = AuthState(
      user: AppUser(id: id, email: '$id@test.dev', nickname: id),
    );
  }
}

class _Repository implements PsychRepository {
  Map<String, int>? scores;
  String? instrument;

  @override
  Future<PsychResult?> fetchResult() async => null;

  @override
  Future<void> saveBig5({
    required Map<String, int> scores,
    required String instrument,
    required DateTime completedAt,
  }) async {
    this.scores = scores;
    this.instrument = instrument;
  }
}

class _FailingLocalStore extends LocalStore {
  _FailingLocalStore(super.prefs);

  @override
  Future<void> setString(String key, String value) async {
    throw StateError('simulated device write failure');
  }
}

Future<({ProviderContainer container, SharedPreferences prefs})>
createContainer({
  Map<String, Object> initialValues = const {},
  PsychRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(_testConfig),
      localStoreProvider.overrideWithValue(LocalStore(prefs)),
      authControllerProvider.overrideWith(_AuthController.new),
      if (repository != null)
        psychRepositoryProvider.overrideWithValue(repository),
    ],
  );
  return (container: container, prefs: prefs);
}

void main() {
  test('restores progress only for the same account', () async {
    final progress = jsonEncode({
      'ownerId': 'first',
      'instrument': ipipBig5Instrument,
      'answers': [1, 2, ...List<Object?>.filled(48, null)],
    });
    final setup = await createContainer(
      initialValues: {LocalStore.kBig5Progress: progress},
    );
    addTearDown(setup.container.dispose);

    expect(setup.container.read(big5ControllerProvider).answeredCount, 2);
    expect(setup.container.read(big5ControllerProvider).currentIndex, 2);

    final auth =
        setup.container.read(authControllerProvider.notifier)
            as _AuthController;
    auth.enter('second');
    expect(setup.container.read(big5ControllerProvider).answeredCount, 0);
  });

  test('completion scores, saves, and clears local progress', () async {
    final repository = _Repository();
    final setup = await createContainer(repository: repository);
    addTearDown(setup.container.dispose);
    final controller = setup.container.read(big5ControllerProvider.notifier);

    for (var index = 0; index < ipipBig5Items.length; index++) {
      final item = ipipBig5Items[index];
      await controller.selectAnswer(item.positiveKeyed ? 5 : 1);
      final completed = await controller.next();
      expect(completed, index == ipipBig5Items.length - 1);
    }

    expect(repository.instrument, ipipBig5Instrument);
    expect(repository.scores, {'O': 100, 'C': 100, 'E': 100, 'A': 100, 'N': 0});
    expect(setup.prefs.getString(LocalStore.kBig5Progress), isNull);
  });

  test('device progress write failure is reported without advancing', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        localStoreProvider.overrideWithValue(_FailingLocalStore(prefs)),
        authControllerProvider.overrideWith(_AuthController.new),
        psychRepositoryProvider.overrideWithValue(_Repository()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(big5ControllerProvider.notifier);
    await controller.selectAnswer(3);
    expect(await controller.next(), isFalse);
    expect(container.read(big5ControllerProvider).currentIndex, 0);
    expect(
      container.read(big5ControllerProvider).errorMessage,
      contains('임시 저장하지 못했어요'),
    );
  });
}
