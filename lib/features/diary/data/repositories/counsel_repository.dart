/// 상담 대화에서 앱이 필요로 하는 것.
abstract interface class CounselRepository {
  Future<String> sendTurn({required String userText});
}