/// ===========================================================================
/// GAME BALANCE — NƠI DUY NHẤT để chỉnh cân bằng game của PetMath.
///
/// Mọi con số về Thân thiết, mở khoá, bonus EXP/Coin/Kim cương, Hộp mù Skin
/// đều nằm ở đây. Logic gameplay (friendship_level.dart, skin_box_roller.dart,
/// firestore_service.dart) chỉ ĐỌC từ file này, không hard-code lại số nào.
/// ===========================================================================

/// Độ hiếm của skin (thứ tự khai báo = thứ tự từ thường → hiếm nhất).
enum SkinRarity { common, rare, epic, legendary }

/// Loại phần thưởng mở khoá khi đạt một mức Thân thiết.
enum FriendshipUnlockType {
  /// Mở chức năng Gia sư AI.
  aiTutor,

  /// Mở hình dạng (cấp) mới của pet — kèm [FriendshipUnlock.petStage].
  petStage,

  /// Tăng % Coin nhận được.
  coinBonus,

  /// Cho phép hiện profile của bản thân trên bảng xếp hạng.
  rankingVisibility,

  /// Tăng % Coin và % Kim cương nhận được.
  coinGemBonus,
}

class FriendshipUnlock {
  final FriendshipUnlockType type;

  /// Chỉ dùng cho [FriendshipUnlockType.petStage]: cấp pet (1..5) được mở.
  final int? petStage;

  const FriendshipUnlock(this.type, {this.petStage});
}

class GameBalance {
  GameBalance._();

  // ---------------------------------------------------------------------
  // THÂN THIẾT
  // ---------------------------------------------------------------------

  /// Điểm Thân thiết cộng cho MỖI lần tương tác hợp lệ với pet
  /// (vuốt ve, cho ăn, tắm, chơi, ngủ).
  static const int friendshipPerInteraction = 100000;

  /// Số lần VUỐT VE tối đa/ngày được cộng điểm (giữ cơ chế sẵn có của app
  /// để không bị "cày" điểm bằng cách chạm liên tục).
  static const int maxPetTapsPerDay = 20;

  /// Điểm TÍCH LUỸ cần để đạt mỗi mức. Chỉ số = mức (0..10);
  /// phần tử [0] luôn là 0 (mức 0 = trạng thái khởi đầu).
  /// Mức X = 10.000 điểm (cao nhất). Mỗi tương tác +100.000 nên 1 lần chăm
  /// pet là lên thẳng mức X — chỉnh [friendshipPerInteraction] để cân lại.
  static const List<int> friendshipThresholds = [
    0, // 0
    100, // I
    500, // II
    1000, // III
    1800, // IV
    2800, // V
    4000, // VI
    5500, // VII
    7000, // VIII
    8500, // IX
    10000, // X
  ];

  /// Phần thưởng mở khoá theo từng mức Thân thiết (mức 0 → Pet cấp 1 có sẵn).
  static const Map<int, FriendshipUnlock> friendshipUnlocks = {
    1: FriendshipUnlock(FriendshipUnlockType.aiTutor),
    2: FriendshipUnlock(FriendshipUnlockType.petStage, petStage: 2),
    3: FriendshipUnlock(FriendshipUnlockType.coinBonus),
    4: FriendshipUnlock(FriendshipUnlockType.petStage, petStage: 3),
    5: FriendshipUnlock(FriendshipUnlockType.rankingVisibility),
    6: FriendshipUnlock(FriendshipUnlockType.coinGemBonus),
    7: FriendshipUnlock(FriendshipUnlockType.petStage, petStage: 4),
    8: FriendshipUnlock(FriendshipUnlockType.coinGemBonus),
    9: FriendshipUnlock(FriendshipUnlockType.coinGemBonus),
    10: FriendshipUnlock(FriendshipUnlockType.petStage, petStage: 5),
  };

  // ---------------------------------------------------------------------
  // BONUS (đều là % CỘNG THÊM trên số gốc, KHÔNG cộng dồn giữa các mức:
  // lấy giá trị của mốc cao nhất đã đạt — vd mức IX → +25% Coin, không phải
  // 10+15+20+25).
  // ---------------------------------------------------------------------

  /// Bonus EXP theo CẤP PET (1..5) đang sở hữu.
  static const Map<int, int> expBonusPercentByPetStage = {
    1: 0,
    2: 10,
    3: 20,
    4: 35,
    5: 50,
  };

  /// Bonus Coin theo mức Thân thiết (mốc: III, VI, VIII, IX).
  static const Map<int, int> coinBonusPercentByLevel = {
    3: 10,
    6: 15,
    8: 20,
    9: 25,
  };

  /// Bonus Kim cương theo mức Thân thiết (mốc: VI, VIII, IX).
  static const Map<int, int> gemBonusPercentByLevel = {
    6: 5,
    8: 10,
    9: 15,
  };

  // ---------------------------------------------------------------------
  // HỘP MÙ SKIN
  // ---------------------------------------------------------------------

  /// Giá 1 lần mở hộp (Kim cương).
  static const int skinBoxPriceGem = 200;

  /// Tỷ lệ rơi theo độ hiếm (đơn vị %, tổng nên = 100; code vẫn đúng nếu
  /// tổng khác 100 vì dùng trọng số tương đối).
  static const Map<SkinRarity, int> skinRatePercent = {
    SkinRarity.common: 65,
    SkinRarity.rare: 20,
    SkinRarity.epic: 10,
    SkinRarity.legendary: 5,
  };

  /// Coin đền bù khi mở trúng skin ĐÃ CÓ (không tạo bản ghi trùng).
  static const Map<SkinRarity, int> duplicateSkinCoinReward = {
    SkinRarity.common: 100,
    SkinRarity.rare: 250,
    SkinRarity.epic: 600,
    SkinRarity.legendary: 1500,
  };
}
