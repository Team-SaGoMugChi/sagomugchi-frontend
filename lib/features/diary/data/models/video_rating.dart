/// Step 3 완료 화면 "이 영상은 어땠나요?" 응답. 영상 연출 품질을 개선할 때
/// 참고하려고 그날 일기 문서에 `videoRating`(= [key])으로 저장한다.
enum VideoRating {
  good('good', '😊', '좋았어요'),
  okay('okay', '🙂', '보통이에요'),
  bad('bad', '😕', '별로였어요');

  const VideoRating(this.key, this.emoji, this.label);

  /// Firestore에 저장하는 값. 라벨 문구가 바뀌어도 데이터가 흔들리지 않게 따로 둔다.
  final String key;
  final String emoji;
  final String label;

  static VideoRating? fromKey(Object? key) {
    for (final rating in values) {
      if (rating.key == key) return rating;
    }
    return null;
  }
}
