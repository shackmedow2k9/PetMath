import '../config/game_balance.dart'; // SkinRarity dùng chung với Hộp mù Skin
import 'pet_model.dart';

/// 1 mốc điểm Thân thiết — đạt đủ [requiredPoints] thì mở khoá skin.
///
/// [skinAssetPath] để `null` cho tới khi có ảnh skin thật — UI sẽ tự
/// hiển thị icon 🎁 placeholder thay vì cố load ảnh không tồn tại. Khi
/// thêm loài mới có skin, chỉ cần thêm 1 entry vào [kSpeciesSkins] bên
/// dưới, không cần sửa gì ở màn hình Nhà pet.
class AffectionMilestone {
  final int requiredPoints;
  final String title;
  final SkinRarity rarity;
  final String? skinAssetPath;

  const AffectionMilestone({
    required this.requiredPoints,
    required this.title,
    this.rarity = SkinRarity.common,
    this.skinAssetPath,
  });
}

/// Mốc Thân thiết mặc định cho loài CHƯA có skin riêng — vẫn cho tiến
/// trình lên điểm bình thường, chỉ là hiển thị 🔒/🎁 placeholder thay vì
/// ảnh skin thật cho tới khi được bổ sung.
const List<AffectionMilestone> _kPlaceholderMilestones = [
  AffectionMilestone(requiredPoints: 50, title: 'Thân thiết I'),
  AffectionMilestone(requiredPoints: 150, title: 'Thân thiết II'),
  AffectionMilestone(requiredPoints: 300, title: 'Thân thiết III'),
  AffectionMilestone(requiredPoints: 500, title: 'Thân thiết IV'),
  AffectionMilestone(requiredPoints: 800, title: 'Thân thiết V'),
  AffectionMilestone(requiredPoints: 1200, title: 'Thân thiết VI'),
];

/// Danh sách skin theo từng loài — hiện chỉ Panda có skin thật (10 skin,
/// từ ảnh bạn gửi), các loài khác dùng [_kPlaceholderMilestones] tạm thời
/// cho tới khi có ảnh riêng.
const Map<PetSpecies, List<AffectionMilestone>> kSpeciesSkins = {
  PetSpecies.panda: [
    AffectionMilestone(
      requiredPoints: 30,
      title: 'Gấu Trúc',
      rarity: SkinRarity.common,
      skinAssetPath: 'assets/images/pet_skins/panda/common_plain.jpg',
    ),
    AffectionMilestone(
      requiredPoints: 80,
      title: 'Gấu Trúc Khủng Long',
      rarity: SkinRarity.common,
      skinAssetPath: 'assets/images/pet_skins/panda/common_dino.jpg',
    ),
    AffectionMilestone(
      requiredPoints: 150,
      title: 'Gấu Trúc Thám Tử',
      rarity: SkinRarity.rare,
      skinAssetPath: 'assets/images/pet_skins/panda/rare_detective.jpg',
    ),
    AffectionMilestone(
      requiredPoints: 250,
      title: 'Gấu Trúc Ninja',
      rarity: SkinRarity.rare,
      skinAssetPath: 'assets/images/pet_skins/panda/rare_ninja.jpg',
    ),
    AffectionMilestone(
      requiredPoints: 380,
      title: 'Gấu Trúc Vũ Trụ',
      rarity: SkinRarity.rare,
      skinAssetPath: 'assets/images/pet_skins/panda/rare_space.jpg',
    ),
    AffectionMilestone(
      requiredPoints: 550,
      title: 'Gấu Trúc Cổ Trang',
      rarity: SkinRarity.epic,
      skinAssetPath: 'assets/images/pet_skins/panda/epic_ancient.jpg',
    ),
    AffectionMilestone(
      requiredPoints: 750,
      title: 'Gấu Trúc Chiến Thần',
      rarity: SkinRarity.epic,
      skinAssetPath: 'assets/images/pet_skins/panda/epic_warlord.jpg',
    ),
    AffectionMilestone(
      requiredPoints: 1000,
      title: 'Gấu Trúc Hỏa Long',
      rarity: SkinRarity.legendary,
      skinAssetPath: 'assets/images/pet_skins/panda/legendary_fire.jpg',
    ),
    AffectionMilestone(
      requiredPoints: 1400,
      title: 'Gấu Trúc Băng Tuyết',
      rarity: SkinRarity.legendary,
      skinAssetPath: 'assets/images/pet_skins/panda/legendary_ice.jpg',
    ),
    AffectionMilestone(
      requiredPoints: 2000,
      title: 'Gấu Trúc Thiên Sứ',
      rarity: SkinRarity.legendary,
      skinAssetPath: 'assets/images/pet_skins/panda/legendary_angel.jpg',
    ),
  ],
};

/// Lấy đúng danh sách mốc cho 1 loài — có skin riêng thì trả skin thật,
/// chưa có thì trả danh sách placeholder chung.
List<AffectionMilestone> milestonesForSpecies(PetSpecies species) =>
    kSpeciesSkins[species] ?? _kPlaceholderMilestones;

/// Mốc kế tiếp chưa đạt của 1 loài (null nếu đã mở hết tất cả mốc).
AffectionMilestone? nextAffectionMilestone(
    PetSpecies species, int currentPoints) {
  for (final m in milestonesForSpecies(species)) {
    if (currentPoints < m.requiredPoints) return m;
  }
  return null;
}
