import 'package:cloud_firestore/cloud_firestore.dart';

import 'friendship_level.dart';
import 'pet_family_catalog.dart';

/// 10 loài thú cưng — khớp 1-1 với 10 họ trong assets/pets_v2/<họ>/
/// (xem [PetFamily]). Mỗi loài là đúng 1 họ, không có loài trùng.
///
/// Firestore lưu loài theo TÊN enum (`species.name`). Pet tạo từ bản cũ có
/// thể còn lưu tên 1 trong 40 loài cũ (orangeCat, shibaInu...) — luôn đọc
/// qua [petSpeciesFromStored] để quy về 10 loài này, không dùng
/// `PetSpecies.values.byName` trực tiếp.
enum PetSpecies {
  bunny,
  cat,
  chicken,
  dog,
  dragon,
  kitsune,
  panda,
  robot,
  slime,
  whale,
}

/// Tên loài cũ (40 loài) → loài mới (10 loài). Các loài mèo cũ chuyển sang
/// panda; các loài còn lại giữ nguyên họ như bảng ánh xạ cũ.
const Map<String, PetSpecies> _legacySpeciesMap = {
  // mèo → panda
  'orangeCat': PetSpecies.panda,
  'whiteCat': PetSpecies.panda,
  'grayCat': PetSpecies.panda,
  'blackCat': PetSpecies.panda,
  'lionCub': PetSpecies.panda,
  'tigerCub': PetSpecies.panda,
  // panda
  'redPanda': PetSpecies.panda,
  'koala': PetSpecies.panda,
  'brownBear': PetSpecies.panda,
  'babyMonkey': PetSpecies.panda,
  // dog
  'brownPuppy': PetSpecies.dog,
  'borderCollie': PetSpecies.dog,
  'shibaInu': PetSpecies.dog,
  'corgi': PetSpecies.dog,
  'piglet': PetSpecies.dog,
  'calf': PetSpecies.dog,
  'pony': PetSpecies.dog,
  'babyElephant': PetSpecies.dog,
  // bunny
  'whiteRabbit': PetSpecies.bunny,
  'brownRabbit': PetSpecies.bunny,
  'hamster': PetSpecies.bunny,
  'squirrel': PetSpecies.bunny,
  'lamb': PetSpecies.bunny,
  // kitsune
  'fox': PetSpecies.kitsune,
  'unicorn': PetSpecies.kitsune,
  // robot
  'raccoon': PetSpecies.robot,
  // whale
  'penguin': PetSpecies.whale,
  'turtle': PetSpecies.whale,
  'octopus': PetSpecies.whale,
  'goldfish': PetSpecies.whale,
  'crab': PetSpecies.whale,
  'seal': PetSpecies.whale,
  // chicken
  'owl': PetSpecies.chicken,
  'duckling': PetSpecies.chicken,
  // slime
  'hedgehog': PetSpecies.slime,
  'frog': PetSpecies.slime,
  'axolotl': PetSpecies.slime,
  // dragon
  'babyDragon': PetSpecies.dragon,
  'dinosaur': PetSpecies.dragon,
};

/// Đọc loài từ giá trị lưu trong Firestore: tên mới → dùng luôn; tên loài
/// cũ → quy đổi theo [_legacySpeciesMap]; thiếu/lạ → [PetSpecies.cat].
PetSpecies petSpeciesFromStored(Object? raw) {
  final name = raw is String ? raw : '';
  for (final s in PetSpecies.values) {
    if (s.name == name) return s;
  }
  return _legacySpeciesMap[name] ?? PetSpecies.cat;
}

/// Model thú cưng - trung tâm của vòng lặp động lực:
/// Làm bài -> EXP -> Lên level -> Pet đẹp hơn -> Muốn đẹp hơn -> Học tiếp
class PetModel {
  final String id;
  final String ownerId;
  final PetSpecies species;
  final String name;
  final int level;
  final int exp;
  final int expToNextLevel;

  // Chỉ số theo tài liệu: HP, Happiness, Hunger, Energy
  final int hp;
  final int happiness;
  final int hunger;
  final int energy;
  final int hygiene; // độ sạch sẽ — giảm dần theo thời gian, tắm để hồi lại
  final int playfulness; // mức hứng thú chơi — giảm theo thời gian, chơi để hồi
  final int toiletNeed; // nhu cầu đi vệ sinh: 0 = chưa cần, 100 = rất cần

  final List<String> equippedItemIds; // đồ đang mặc: áo, mũ, kính...
  final bool isRare; // pet hiếm nhận được từ streak 30 ngày
  final DateTime lastFedAt;

  // Vuốt ve (chạm vào pet ở Nhà pet) — giống hệ thống "thân thiết" của
  // Linh Bảo trong Liên Quân Mobile: mỗi ngày chỉ cộng Vui vẻ một số lượt
  // giới hạn (xem FirestoreService.maxPetInteractionsPerDay), chạm thêm
  // vẫn có hiệu ứng vui mắt nhưng không cộng thêm chỉ số. lastPetInteractionAt
  // dùng để biết ngày mới thì reset petInteractionsToday về 0.
  final int petInteractionsToday;
  final DateTime? lastPetInteractionAt;

  // Điểm Thân thiết — cộng dồn từ mọi tương tác chăm sóc (cho ăn, tắm,
  // chơi, ngủ, vuốt ve), giống hệ thống thân thiết của Linh Bảo trong
  // Liên Quân Mobile. Đạt mốc điểm sẽ mở khoá trang phục/skin tương ứng
  // (xem kSpeciesSkins). KHÔNG bị reset theo ngày — tích luỹ mãi.
  final int affectionPoints;

  // Mốc thời gian lần gần nhất các chỉ số No bụng/Sạch sẽ/Năng lượng đã
  // được "trừ hao" theo thời gian thực trôi qua — xem
  // [FirestoreService.applyTimeDecay]. Nhờ mốc này, pet vẫn đói dần/dơ
  // dần/mệt dần đúng theo thời gian thực kể cả khi học sinh không mở app
  // hay không vào Nhà pet, thay vì chỉ giảm khi có màn hình cụ thể đang mở.
  final DateTime lastDecayAt;

  // Nhà của pet: nhà đang ở (hiển thị ngoài Nhà của thú cưng) và danh sách
  // các nhà đã mua/sở hữu. "wood" (Nhà gỗ) là nhà mặc định, luôn sở hữu sẵn.
  final String currentHouseId;
  final List<String> ownedHouseIds;

  // ---- PetMath: Skin (Hộp mù) ----
  // Skin đã sở hữu (id dạng `dragon_03`, xem PetFamilyCatalog) và skin đang
  // trang bị ('' = không trang bị → hiện ảnh IDLE theo cấp pet). Pet cũ chưa
  // có 2 field này trong Firestore → mặc định rỗng, không mất dữ liệu.
  final List<String> unlockedSkins;
  final String equippedSkin;

  // Mức Thân thiết cao nhất ĐÃ ĂN MỪNG (popup mở khoá). Tách khỏi điểm để
  // popup chỉ hiện đúng 1 lần cho mỗi mốc, kể cả reload/đổi máy.
  final int celebratedFriendshipLevel;

  PetModel({
    required this.id,
    required this.ownerId,
    required this.species,
    required this.name,
    this.level = 1,
    this.exp = 0,
    this.expToNextLevel = 100,
    this.hp = 100,
    this.happiness = 100,
    this.hunger = 100,
    this.energy = 100,
    this.hygiene = 100,
    this.playfulness = 100,
    this.toiletNeed = 0,
    this.equippedItemIds = const [],
    this.isRare = false,
    required this.lastFedAt,
    this.petInteractionsToday = 0,
    this.lastPetInteractionAt,
    this.affectionPoints = 0,
    DateTime? lastDecayAt,
    this.currentHouseId = 'wood',
    this.ownedHouseIds = const ['wood'],
    this.unlockedSkins = const [],
    this.equippedSkin = '',
    this.celebratedFriendshipLevel = 0,
  }) : lastDecayAt = lastDecayAt ?? DateTime.now();

  /// Không bao giờ để pet "chết" - tránh gây áp lực cho học sinh.
  /// Pet chỉ buồn / đói, các chỉ số có sàn tối thiểu.
  static int clampStat(int value) => value.clamp(10, 100);

  factory PetModel.fromMap(String id, Map<String, dynamic> map) {
    return PetModel(
      id: id,
      ownerId: map['ownerId'] ?? '',
      species: petSpeciesFromStored(map['species']),
      name: map['name'] ?? 'Pet',
      level: map['level'] ?? 1,
      exp: map['exp'] ?? 0,
      expToNextLevel: map['expToNextLevel'] ?? 100,
      hp: map['hp'] ?? 100,
      happiness: map['happiness'] ?? 100,
      hunger: map['hunger'] ?? 100,
      energy: map['energy'] ?? 100,
      hygiene: map['hygiene'] ?? 100,
      playfulness: ((map['playfulness'] ?? 100) as num).round().clamp(10, 100),
      toiletNeed: ((map['toiletNeed'] ?? 0) as num).round().clamp(0, 100),
      equippedItemIds: List<String>.from(map['equippedItemIds'] ?? []),
      isRare: map['isRare'] ?? false,
      lastFedAt: (map['lastFedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      petInteractionsToday: map['petInteractionsToday'] ?? 0,
      lastPetInteractionAt:
          (map['lastPetInteractionAt'] as Timestamp?)?.toDate(),
      affectionPoints: map['affectionPoints'] ?? 0,
      // Pet tạo TRƯỚC khi có tính năng "trừ hao theo thời gian thực" sẽ
      // chưa có field này trong Firestore — dùng lastFedAt làm mốc khởi
      // điểm thay thế (hợp lý hơn DateTime.now(), tránh vô tình "khựng"
      // việc trừ hao ngay sau khi nâng cấp app).
      lastDecayAt: (map['lastDecayAt'] as Timestamp?)?.toDate() ??
          (map['lastFedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      currentHouseId: map['currentHouseId'] ?? 'wood',
      ownedHouseIds: List<String>.from(map['ownedHouseIds'] ?? const ['wood']),
      unlockedSkins: List<String>.from(map['unlockedSkins'] ?? const []),
      equippedSkin: (map['equippedSkin'] ?? '') as String,
      celebratedFriendshipLevel: (map['celebratedFriendshipLevel'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'species': species.name,
      'name': name,
      'level': level,
      'exp': exp,
      'expToNextLevel': expToNextLevel,
      'hp': hp,
      'happiness': happiness,
      'hunger': hunger,
      'energy': energy,
      'hygiene': hygiene,
      'playfulness': playfulness,
      'toiletNeed': toiletNeed,
      'equippedItemIds': equippedItemIds,
      'isRare': isRare,
      'lastFedAt': Timestamp.fromDate(lastFedAt),
      'petInteractionsToday': petInteractionsToday,
      'lastPetInteractionAt': lastPetInteractionAt == null
          ? null
          : Timestamp.fromDate(lastPetInteractionAt!),
      // KHÔNG ghi 'affectionPoints' / 'unlockedSkins' / 'equippedSkin' /
      // 'celebratedFriendshipLevel' ở đây: các field này chỉ được sửa bằng
      // lệnh riêng (increment/arrayUnion/transaction) trong FirestoreService.
      // Nếu ghi cả map theo bản đọc cũ, một lệnh ghi chậm nhịp có thể đè mất
      // điểm Thân thiết hoặc skin vừa nhận.
      'lastDecayAt': Timestamp.fromDate(lastDecayAt),
      'currentHouseId': currentHouseId,
      'ownedHouseIds': ownedHouseIds,
    };
  }

  /// EXP cần để đi từ [level] lên [level]+1.
  /// Quy tắc: mức tăng thêm mỗi bậc lại nhiều hơn bậc trước 50 EXP:
  ///   Lv1->2: 100 | Lv2->3: 150 (+50) | Lv3->4: 250 (+100) | Lv4->5: 400 (+150) | ...
  /// Rút gọn thành công thức: EXP(level) = 100 + 25 * level * (level - 1)
  static int expRequiredForLevel(int level) => 100 + 25 * level * (level - 1);

  /// Cộng EXP sau khi làm bài đúng, tự động tính lên level.
  /// Ví dụ trong tài liệu: đúng 10 câu -> +100 EXP -> lên level.
  PetModel addExp(int amount) {
    int newExp = exp + amount;
    int newLevel = level;
    int newExpToNext = expToNextLevel;

    while (newExp >= newExpToNext) {
      newExp -= newExpToNext;
      newLevel++;
      newExpToNext = expRequiredForLevel(newLevel); // độ khó tăng dần
    }

    return copyWith(exp: newExp, level: newLevel, expToNextLevel: newExpToNext);
  }

  PetModel copyWith({
    String? name,
    int? level,
    int? exp,
    int? expToNextLevel,
    int? hp,
    int? happiness,
    int? hunger,
    int? energy,
    int? hygiene,
    int? playfulness,
    int? toiletNeed,
    List<String>? equippedItemIds,
    bool? isRare,
    DateTime? lastFedAt,
    int? petInteractionsToday,
    DateTime? lastPetInteractionAt,
    int? affectionPoints,
    DateTime? lastDecayAt,
    String? currentHouseId,
    List<String>? ownedHouseIds,
    List<String>? unlockedSkins,
    String? equippedSkin,
    int? celebratedFriendshipLevel,
  }) {
    return PetModel(
      id: id,
      ownerId: ownerId,
      species: species,
      name: name ?? this.name,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      expToNextLevel: expToNextLevel ?? this.expToNextLevel,
      hp: clampStat(hp ?? this.hp),
      happiness: clampStat(happiness ?? this.happiness),
      hunger: clampStat(hunger ?? this.hunger),
      energy: clampStat(energy ?? this.energy),
      hygiene: clampStat(hygiene ?? this.hygiene),
      playfulness: clampStat(playfulness ?? this.playfulness),
      toiletNeed: (toiletNeed ?? this.toiletNeed).clamp(0, 100),
      equippedItemIds: equippedItemIds ?? this.equippedItemIds,
      isRare: isRare ?? this.isRare,
      lastFedAt: lastFedAt ?? this.lastFedAt,
      petInteractionsToday:
          petInteractionsToday ?? this.petInteractionsToday,
      lastPetInteractionAt: lastPetInteractionAt ?? this.lastPetInteractionAt,
      affectionPoints: affectionPoints ?? this.affectionPoints,
      lastDecayAt: lastDecayAt ?? this.lastDecayAt,
      currentHouseId: currentHouseId ?? this.currentHouseId,
      ownedHouseIds: ownedHouseIds ?? this.ownedHouseIds,
      unlockedSkins: unlockedSkins ?? this.unlockedSkins,
      equippedSkin: equippedSkin ?? this.equippedSkin,
      celebratedFriendshipLevel:
          celebratedFriendshipLevel ?? this.celebratedFriendshipLevel,
    );
  }
}

/// Tên hiển thị theo thứ tự enum [PetSpecies].
const List<String> _petDisplayNames = [
  'Thỏ', // bunny
  'Mèo', // cat
  'Gà', // chicken
  'Chó', // dog
  'Rồng', // dragon
  'Cáo chín đuôi', // kitsune
  'Gấu trúc', // panda
  'Robot', // robot
  'Slime', // slime
  'Cá voi', // whale
];

extension PetFriendship on PetModel {
  /// Trạng thái Thân thiết suy ra từ [PetModel.affectionPoints].
  FriendshipInfo get friendship => FriendshipInfo.fromPoints(affectionPoints);
}

extension PetSpeciesAsset on PetSpecies {
  /// Ảnh minh họa loài (pet cấp 1) lấy từ assets/pets_v2/<họ>/.
  String get assetPath =>
      PetArt.stageIdle(PetFamilyCatalog.familyOf(this), 1);

  String get displayName => _petDisplayNames[index];
}
