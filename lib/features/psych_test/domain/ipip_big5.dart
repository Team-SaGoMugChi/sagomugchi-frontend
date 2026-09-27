/// Public-domain IPIP Big-Five Factor Markers, 50-item form.
///
/// The Korean wording follows the translation published by the IPIP project.
/// Items stay in the official mixed order so adjacent questions do not reveal
/// which factor is being measured.
enum Big5Trait {
  openness('O'),
  conscientiousness('C'),
  extraversion('E'),
  agreeableness('A'),
  emotionalStability('ES');

  const Big5Trait(this.code);
  final String code;
}

class IpipBig5Item {
  const IpipBig5Item(this.text, this.trait, {required this.positiveKeyed});

  final String text;
  final Big5Trait trait;
  final bool positiveKeyed;
}

const String ipipBig5Instrument = 'IPIP-BFFM-50-ko';

const List<IpipBig5Item> ipipBig5Items = [
  IpipBig5Item(
    '나는 각종 모임에 다니는 것을 즐긴다.',
    Big5Trait.extraversion,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 다른 사람들의 근심을 거의 알아차리지 못한다.',
    Big5Trait.agreeableness,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 무슨 일이든 항상 준비를 하는 편이다.',
    Big5Trait.conscientiousness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 쉽게 스트레스로 지치는 편이다.',
    Big5Trait.emotionalStability,
    positiveKeyed: false,
  ),
  IpipBig5Item('나는 어휘력이 풍부하다.', Big5Trait.openness, positiveKeyed: true),
  IpipBig5Item('나는 말이 적은 편이다.', Big5Trait.extraversion, positiveKeyed: false),
  IpipBig5Item(
    '나는 다른 사람들에 대해 관심이 있다.',
    Big5Trait.agreeableness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 내 물건들을 여기저기에 그냥 놓는 편이다.',
    Big5Trait.conscientiousness,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 대체적으로 이완된 상태이다.',
    Big5Trait.emotionalStability,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 추상적인 것을 잘 이해하지 못한다.',
    Big5Trait.openness,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 여러 사람들 가운데 있어도 편하다.',
    Big5Trait.extraversion,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 다른 사람들에게 무례한 언행을 사용할 때가 자주 있다.',
    Big5Trait.agreeableness,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 세부사항도 잘 챙기려고 이에 신경을 쓰는 편이다.',
    Big5Trait.conscientiousness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 걱정이 많다.',
    Big5Trait.emotionalStability,
    positiveKeyed: false,
  ),
  IpipBig5Item('나는 생생한 상상력을 가지고 있다.', Big5Trait.openness, positiveKeyed: true),
  IpipBig5Item('나는 나서지 않는 편이다.', Big5Trait.extraversion, positiveKeyed: false),
  IpipBig5Item(
    '나는 다른 사람들의 감정을 잘 공감한다.',
    Big5Trait.agreeableness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 물건들을 어질러 놓는 편이다.',
    Big5Trait.conscientiousness,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 거의 우울함을 느끼지 않는 편이다.',
    Big5Trait.emotionalStability,
    positiveKeyed: true,
  ),
  IpipBig5Item('나는 복잡한 것은 질색이다.', Big5Trait.openness, positiveKeyed: false),
  IpipBig5Item(
    '나는 사람들을 만나면 대화를 먼저 시작하는 편이다.',
    Big5Trait.extraversion,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 다른 사람들의 개인적인 문제에 관심이 없다.',
    Big5Trait.agreeableness,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 자질구레한 일들은 금방금방 해치운다.',
    Big5Trait.conscientiousness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 쉽게 심란해진다.',
    Big5Trait.emotionalStability,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 굉장한 아이디어들을 가지고 있다.',
    Big5Trait.openness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 보통 할 말이 별로 없다.',
    Big5Trait.extraversion,
    positiveKeyed: false,
  ),
  IpipBig5Item('나는 마음이 여린 편이다.', Big5Trait.agreeableness, positiveKeyed: true),
  IpipBig5Item(
    '나는 물건들을 제자리에 되놓는 것을 자주 잊는다.',
    Big5Trait.conscientiousness,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 쉽게 속이 상한다.',
    Big5Trait.emotionalStability,
    positiveKeyed: false,
  ),
  IpipBig5Item('나는 상상력이 좋지 않다.', Big5Trait.openness, positiveKeyed: false),
  IpipBig5Item(
    '나는 모임에서 여러 사람들과 이야기를 나누는 편이다.',
    Big5Trait.extraversion,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 다른 사람들에 대해 별로 관심이 없다.',
    Big5Trait.agreeableness,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 질서정연한 것을 좋아한다.',
    Big5Trait.conscientiousness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 분위기를 많이 탄다.',
    Big5Trait.emotionalStability,
    positiveKeyed: false,
  ),
  IpipBig5Item('나는 무엇이든 매우 빨리 이해한다.', Big5Trait.openness, positiveKeyed: true),
  IpipBig5Item(
    '나는 나에게 관심이나 이목이 집중되는 것을 좋아하지 않는다.',
    Big5Trait.extraversion,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 주변 다른 사람들에게 내 시간을 잘 할애하는 편이다.',
    Big5Trait.agreeableness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '내가 맡은 일들을 대충 처리하는 경우도 많다.',
    Big5Trait.conscientiousness,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 감정의 기복이 심하다.',
    Big5Trait.emotionalStability,
    positiveKeyed: false,
  ),
  IpipBig5Item('나는 수준 높은 단어를 쓰는 편이다.', Big5Trait.openness, positiveKeyed: true),
  IpipBig5Item(
    '나는 다른 사람들의 주목을 받는 것을 꺼리지 않는다.',
    Big5Trait.extraversion,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 주변 다른 사람들의 감정을 잘 알아차린다.',
    Big5Trait.agreeableness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 정해진 일정을 따르는 편이다.',
    Big5Trait.conscientiousness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 쉽게 짜증이 난다.',
    Big5Trait.emotionalStability,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 골똘히 생각하며 시간을 보낼 때가 많다.',
    Big5Trait.openness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 모르는 사람들 가운데 있으면 조용해진다.',
    Big5Trait.extraversion,
    positiveKeyed: false,
  ),
  IpipBig5Item(
    '나는 주변 다른 사람들을 편안하게 해준다.',
    Big5Trait.agreeableness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 내가 맡은 일에 매우 꼼꼼한 사람이다.',
    Big5Trait.conscientiousness,
    positiveKeyed: true,
  ),
  IpipBig5Item(
    '나는 쉽게 우울해진다.',
    Big5Trait.emotionalStability,
    positiveKeyed: false,
  ),
  IpipBig5Item('나는 아이디어가 매우 풍부하다.', Big5Trait.openness, positiveKeyed: true),
];

/// Converts 50 responses (1 = very inaccurate, 5 = very accurate) to OCEAN
/// percentage-like scores. Emotional stability is inverted to Neuroticism.
Map<String, int> scoreIpipBig5(List<int> responses) {
  if (responses.length != ipipBig5Items.length) {
    throw ArgumentError.value(
      responses.length,
      'responses',
      'IPIP Big Five requires exactly ${ipipBig5Items.length} responses.',
    );
  }

  final totals = {for (final trait in Big5Trait.values) trait: 0};
  for (var index = 0; index < responses.length; index++) {
    final response = responses[index];
    if (response < 1 || response > 5) {
      throw ArgumentError.value(response, 'responses[$index]', 'Must be 1–5.');
    }
    final item = ipipBig5Items[index];
    totals[item.trait] =
        totals[item.trait]! + (item.positiveKeyed ? response : 6 - response);
  }

  int percentage(Big5Trait trait) => ((totals[trait]! - 10) * 2.5).round();
  final emotionalStability = percentage(Big5Trait.emotionalStability);
  return {
    'O': percentage(Big5Trait.openness),
    'C': percentage(Big5Trait.conscientiousness),
    'E': percentage(Big5Trait.extraversion),
    'A': percentage(Big5Trait.agreeableness),
    'N': 100 - emotionalStability,
  };
}
