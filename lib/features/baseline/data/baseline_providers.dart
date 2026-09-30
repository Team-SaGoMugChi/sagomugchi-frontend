import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../../../core/network/api_client.dart';
import 'datasources/baseline_data_source.dart';
import 'datasources/baseline_dummy_data_source.dart';
import 'datasources/baseline_file_data_source.dart';
import 'datasources/baseline_remote_data_source.dart';
import 'repositories/baseline_repository.dart';
import 'repositories/baseline_repository_impl.dart';

/// 에뮬레이터 테스트용 baseline JSON 파일 이름 — 비어 있으면 Firestore를 읽는다.
/// `--dart-define=ODDO_BASELINE_FILE=baseline.json` ([BaselineFileDataSource]).
const _baselineTestFile = String.fromEnvironment('ODDO_BASELINE_FILE');

/// Swap point: dummy vs real data source, chosen by [AppConfig] (diary와 동일 패턴).
final baselineDataSourceProvider = Provider<BaselineDataSource>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useDummyData) {
    return BaselineDummyDataSource();
  }
  final remote = BaselineRemoteDataSource(ref.watch(apiClientProvider));
  if (_baselineTestFile.isNotEmpty) {
    return BaselineFileDataSource(_baselineTestFile, remote);
  }
  return remote;
});

final baselineRepositoryProvider = Provider<BaselineRepository>((ref) {
  return BaselineRepositoryImpl(ref.watch(baselineDataSourceProvider));
});
