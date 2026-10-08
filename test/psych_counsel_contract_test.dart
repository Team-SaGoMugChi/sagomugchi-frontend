import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/features/diary/application/counsel_controller.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/counsel_report.dart';
import 'package:oddo/features/diary/data/models/counsel_session.dart';
import 'package:oddo/features/diary/data/models/counsel_turn_result.dart';
import 'package:oddo/features/diary/data/repositories/counsel_repository.dart';
import 'package:oddo/features/persona/data/models/persona_config.dart';
import 'package:oddo/features/persona/data/persona_providers.dart';
import 'package:oddo/features/persona/data/repositories/persona_repository.dart';
import 'package:oddo/features/psych_test/data/models/psych_result.dart';
import 'package:oddo/features/psych_test/data/psych_providers.dart';
import 'package:oddo/features/psych_test/data/repositories/psych_repository.dart';
import 'package:oddo/features/psych_test/domain/ipip_big5.dart';

const _testConfig = AppConfig(
  environment: AppEnvironment.dev,
  appName: 'Oddo test',
  apiBaseUrl: '',
  useDummyData: true,
);

class _PsychRepository implements PsychRepository {
  @override
  Future<PsychResult?> fetchResult() async => PsychResult(
    big5: const {'O': 75, 'C': 62, 'E': 38, 'A': 81, 'N': 44},
    big5Instrument: ipipBig5Instrument,
    big5CompletedAt: DateTime.utc(2026, 9, 27),
    updatedAt: DateTime.utc(2026, 9, 27),
  );

  @override
  Future<void> saveBig5({
    required Map<String, int> scores,
    required String instrument,
    required DateTime completedAt,
  }) async {}
}

class _UnversionedPsychRepository implements PsychRepository {
  @override
  Future<PsychResult?> fetchResult() async => PsychResult(
    big5: const {'O': 75, 'C': 62, 'E': 38, 'A': 81, 'N': 44},
    updatedAt: DateTime.utc(2026, 9, 27),
  );

  @override
  Future<void> saveBig5({
    required Map<String, int> scores,
    required String instrument,
    required DateTime completedAt,
  }) async {}
}

class _PersonaRepository implements PersonaRepository {
  @override
  Future<PersonaConfig?> fetchPersona() async => PersonaConfig(
    name: '마음이',
    tone: '차분하고 진중한',
    traits: const ['공감 잘해주는', '신중한'],
    updatedAt: DateTime.utc(2026, 9, 27),
  );

  @override
  Future<void> savePersona(PersonaConfig config) async {}
}

class _CounselRepository implements CounselRepository {
  Map<String, dynamic>? psychProfile;
  Map<String, dynamic>? persona;

  @override
  Future<CounselTurnResult> sendTurn({
    required String userText,
    List<CounselMessage> history = const [],
    Map<String, double>? emotions,
    List<String>? signals,
    String? diarySummary,
    bool incongruent = false,
    Map<String, dynamic>? persona,
    Map<String, dynamic>? psychProfile,
    Map<String, String?>? slots,
    String? emotionArc,
  }) async {
    this.psychProfile = psychProfile;
    this.persona = persona;
    return const CounselTurnResult(reply: '응답');
  }

  @override
  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
    Map<String, String?>? slots,
  }) => throw UnimplementedError();
}

void main() {
  test(
    'completed Big Five result is forwarded to counsel JSON contract',
    () async {
      final counsel = _CounselRepository();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          psychRepositoryProvider.overrideWithValue(_PsychRepository()),
          counselRepositoryProvider.overrideWithValue(counsel),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(counselControllerProvider.notifier)
          .sendTurn('오늘 이야기');

      expect(counsel.psychProfile, {
        'big5': {'O': 75, 'C': 62, 'E': 38, 'A': 81, 'N': 44},
        'big5_instrument': ipipBig5Instrument,
      });
    },
  );

  test('unversioned Big Five result is not forwarded to counsel', () async {
    final counsel = _CounselRepository();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        psychRepositoryProvider.overrideWithValue(
          _UnversionedPsychRepository(),
        ),
        counselRepositoryProvider.overrideWithValue(counsel),
      ],
    );
    addTearDown(container.dispose);

    await container.read(counselControllerProvider.notifier).sendTurn('오늘 이야기');

    expect(counsel.psychProfile, isNull);
  });

  test('Big Five completion rejects malformed score maps', () {
    final malformed = PsychResult(
      big5: const {'O': 50, 'C': 50, 'E': 50, 'A': 50, 'X': 50},
      big5Instrument: ipipBig5Instrument,
      big5CompletedAt: DateTime.utc(2026, 9, 27),
      updatedAt: DateTime.utc(2026, 9, 27),
    );

    expect(malformed.isComplete, isFalse);
  });

  test('validated persona is forwarded without storage metadata', () async {
    final counsel = _CounselRepository();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        personaRepositoryProvider.overrideWithValue(_PersonaRepository()),
        counselRepositoryProvider.overrideWithValue(counsel),
      ],
    );
    addTearDown(container.dispose);

    await container.read(counselControllerProvider.notifier).sendTurn('오늘 이야기');

    expect(counsel.persona, {
      'name': '마음이',
      'tone': '차분하고 진중한',
      'traits': ['공감 잘해주는', '신중한'],
    });
    expect(counsel.persona, isNot(contains('updatedAt')));
  });
}
