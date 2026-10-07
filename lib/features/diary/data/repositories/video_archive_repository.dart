/// 생성된 숏폼 보관(Firebase Storage)과 다시 재생할 주소.
abstract interface class VideoArchiveRepository {
  Future<String> archive({required DateTime date, required String sourceUrl});

  Future<String> playableUrl(String storagePath);
}
