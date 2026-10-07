/// 생성된 숏폼을 Firebase Storage `users/{uid}/videos/{yyyy-MM-dd}.mp4`에 보관하고
/// 다시 재생할 주소를 돌려준다. AI 서버는 영상을 메모리·작업 폴더에만 두므로
/// 지난 날짜의 영상은 여기서만 다시 볼 수 있다.
abstract interface class VideoArchiveDataSource {
  /// 서버가 만든 영상([sourceUrl])을 받아 그날 경로로 올리고 Storage 경로를 돌려준다.
  /// 같은 날짜로 다시 올리면 덮어쓴다.
  Future<String> archive({required DateTime date, required String sourceUrl});

  /// 일기 문서에 저장한 [storagePath] → 플레이어가 재생할 주소.
  Future<String> playableUrl(String storagePath);
}
