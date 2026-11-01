/// Mascot (탄카츄) poses referenced across screens. Each maps to an image file
/// that will be dropped into `assets/images/character/` later. Until then,
/// `MascotImage` renders a styled placeholder, so missing files are harmless.
enum MascotPose {
  front,

  /// 머리+양손만 보이는 '빼꼼' 포즈 — 홈 카드 윗변을 잡는 연출 전용.
  /// (하단이 손 바로 아래에서 잘린 이미지)
  peeking,
  waving,
  thinking,
  writing,
  heart,
  clipboard,
  mic,
  mirror,
  shield,
  celebrate,
  sorry,
  letter,
  check,
  camera,
  counselor,
  wink,
}

/// Centralized asset path constants.
abstract final class AppAssets {
  AppAssets._();

  static const String _imageBase = 'assets/images';
  static const String _characterBase = '$_imageBase/character';
  static const String _iconBase = 'assets/icons';

  static const String logo = '$_imageBase/oddo_logo.png';

  /// Single unified mascot placeholder used everywhere for now. Per-pose
  /// images ([mascot]) will replace it in one pass once art is ready.
  static const String tankachuPlaceholder =
      'assets/characters/tankachu_placeholder.png';

  /// Resolves a character image path for the given [pose].
  static String mascot(MascotPose pose) => '$_characterBase/${pose.name}.png';

  static String icon(String name) => '$_iconBase/$name.png';

  /// 첫 실행 소개 영상(9:16, 27초, 3D 탄카츄 + 배경음). 재생에 실패하면
  /// [introFilmEndCard]를 대신 보여 준다.
  static const String introFilm = 'assets/videos/oddo_intro.mp4';

  /// 소개 영상의 마지막 장면(오또 로고) 정지 화면. 하단 27%는 버튼 자리로 비워 둠.
  static const String introFilmEndCard = '$_imageBase/intro_end_card.jpg';

  /// 체형 전용 리그와 동작 클립(Idle·Wave·Nod·Hop)을 넣은 3D 탄카츄.
  static const String mascotModel = 'assets/models/tankachu_animated.glb';
}
