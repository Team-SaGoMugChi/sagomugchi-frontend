import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import 'counsel_data_source.dart';

/// 실제 AI 서버 호출.
class CounselRemoteDataSource implements CounselDataSource {
  CounselRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<String> sendTurn({required String userText}) async {
    final json = await _apiClient.post(
      '/counsel/turn',
      body: {'user_text': userText},
    );
    final reply = json['reply'];
    if (reply is! String) {
      throw const ServerException('상담 응답을 처리하지 못했어요.');
    }
    return reply;
  }
}