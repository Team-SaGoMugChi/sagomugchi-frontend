import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../baseline/data/baseline_providers.dart';
import '../../persona/data/persona_providers.dart';
import '../../psych_test/data/psych_providers.dart';

/// Confirms every persisted onboarding prerequisite before marking the account
/// complete. This also protects direct links to the final screen.
class OnboardingCompletionService {
  OnboardingCompletionService(this.ref);

  final Ref ref;

  Future<void> complete() async {
    final baseline = await ref.read(baselineRepositoryProvider).fetchSaved();
    if (baseline?.isAnalysisReady != true) {
      throw const AppException('최신 첫 측정 결과가 필요해요. 측정을 다시 진행해주세요.');
    }

    final psych = await ref.read(psychRepositoryProvider).fetchResult();
    if (psych?.isComplete != true) {
      throw const AppException('완료된 Big Five 결과를 확인할 수 없어요.');
    }

    final persona = await ref.read(personaRepositoryProvider).fetchPersona();
    if (persona?.isValid != true) {
      throw const AppException('저장된 페르소나 설정을 확인할 수 없어요.');
    }

    await ref.read(authControllerProvider.notifier).completeOnboarding();
  }
}

final onboardingCompletionServiceProvider =
    Provider<OnboardingCompletionService>(OnboardingCompletionService.new);
