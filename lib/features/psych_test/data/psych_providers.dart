import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import 'models/psych_result.dart';
import 'repositories/psych_repository.dart';

final psychRepositoryProvider = Provider<PsychRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useDummyData
      ? PsychDummyRepository()
      : PsychFirestoreRepository();
});

final psychResultProvider = FutureProvider<PsychResult?>((ref) {
  return ref.watch(psychRepositoryProvider).fetchResult();
});
