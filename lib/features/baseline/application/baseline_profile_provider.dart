import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/baseline_providers.dart';
import '../data/models/baseline_profile.dart';
import 'baseline_upload_controller.dart';

/// Prefer this session's saved upload; reload from storage after an app restart.
final baselineProfileProvider = FutureProvider.autoDispose<BaselineProfile?>((
  ref,
) {
  ref.watch(authControllerProvider.select((value) => value.user?.id));
  final uploaded = ref.watch(baselineUploadControllerProvider).asData?.value;
  if (uploaded != null) return uploaded;
  return ref.watch(baselineRepositoryProvider).fetchSaved();
}, retry: (retryCount, error) => null);
