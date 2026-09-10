import '../datasources/counsel_data_source.dart';
import 'counsel_repository.dart';

class CounselRepositoryImpl implements CounselRepository {
  CounselRepositoryImpl(this._dataSource);

  final CounselDataSource _dataSource;

  @override
  Future<String> sendTurn({required String userText}) {
    return _dataSource.sendTurn(userText: userText);
  }
}