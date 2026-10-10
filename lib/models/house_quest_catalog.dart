/// Nhiệm vụ chăm sóc hằng ngày trong Nhà pet — tiến độ lưu theo ngày thật,
/// sang ngày mới tự làm mới. Hoàn thành nhiệm vụ → bấm nhận thưởng Coin;
/// nhận hết cả 5 nhiệm vụ → mở thêm Rương thưởng cuối ngày.
class HouseQuestDef {
  final String id;
  final String emoji;
  final String title;
  final int target;
  final int rewardCoin;

  const HouseQuestDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.target,
    required this.rewardCoin,
  });
}

class HouseQuestCatalog {
  HouseQuestCatalog._();

  static const String feed = 'feed';
  static const String bathe = 'bathe';
  static const String play = 'play';
  static const String pat = 'pat';
  static const String rooms = 'rooms';

  /// Thưởng thêm khi đã nhận đủ thưởng của mọi nhiệm vụ trong ngày.
  static const int bonusCoin = 30;

  static const List<HouseQuestDef> all = [
    HouseQuestDef(
        id: feed,
        emoji: '🍗',
        title: 'Cho pet ăn 1 lần',
        target: 1,
        rewardCoin: 10),
    HouseQuestDef(
        id: bathe,
        emoji: '🛁',
        title: 'Tắm cho pet 1 lần',
        target: 1,
        rewardCoin: 10),
    HouseQuestDef(
        id: play,
        emoji: '🎾',
        title: 'Chơi hoặc làm hoạt động 2 lần',
        target: 2,
        rewardCoin: 15),
    HouseQuestDef(
        id: pat,
        emoji: '🤗',
        title: 'Vuốt ve pet 5 lần',
        target: 5,
        rewardCoin: 5),
    HouseQuestDef(
        id: rooms,
        emoji: '🏠',
        title: 'Ghé thăm cả 3 phòng',
        target: 3,
        rewardCoin: 5),
  ];

  static HouseQuestDef? byId(String id) {
    for (final q in all) {
      if (q.id == id) return q;
    }
    return null;
  }
}
