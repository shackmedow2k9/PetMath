import '../config/game_balance.dart';
import 'friendship_level.dart';
import 'pet_model.dart';

/// 10 "họ" pet có đủ bộ ảnh 5 cấp + 10 skin (assets/pets_v2/<họ>/...).
///
/// [PetSpecies] có đúng 10 giá trị cùng tên với 10 họ này; Firestore lưu tên
/// loài. Tên loài của bản cũ (40 loài) được quy đổi trong
/// [petSpeciesFromStored] khi đọc dữ liệu.
enum PetFamily { bunny, cat, chicken, dog, dragon, kitsune, panda, robot, slime, whale }

/// Một skin của một họ pet. [id] dạng `dragon_03` (lưu trong Firestore).
class PetSkin {
  final PetFamily family;

  /// 1..10 — cũng là số thứ tự file `skinNN_*.png`.
  final int number;
  final SkinRarity rarity;
  final String nameVi;
  final String nameEn;

  const PetSkin({
    required this.family,
    required this.number,
    required this.rarity,
    required this.nameVi,
    required this.nameEn,
  });

  String get id => '${family.name}_${number.toString().padLeft(2, '0')}';
}

/// Ảnh pet: tách bạch ảnh LIST (thẻ trong thư viện/danh sách) và ảnh IDLE
/// (pet hiển thị trong game). KHÔNG dùng lẫn.
class PetArt {
  PetArt._();

  static const String _root = 'assets/pets_v2';

  /// Các họ mà file "IDLE" nhà thiết kế gửi thực chất là ẢNH THẺ (trùng hệt
  /// ảnh list, không có sprite nền trong suốt). Với các họ này [stageIdle] /
  /// [skinIdle] trả về chính ảnh thẻ để app vẫn chạy; khi có sprite thật chỉ
  /// cần thêm file `lvlN_idle.png` / `skinNN_idle.png` và xoá họ khỏi 2 set này.
  static const Set<PetFamily> levelIdleIsCard = {
    PetFamily.bunny, PetFamily.chicken, PetFamily.dog,
    PetFamily.kitsune, PetFamily.whale,
  };
  static const Set<PetFamily> skinIdleIsCard = {
    PetFamily.bunny, PetFamily.chicken, PetFamily.dog,
    PetFamily.kitsune, PetFamily.slime, PetFamily.whale,
  };

  static int _clampStage(int s) => s < 1 ? 1 : (s > 5 ? 5 : s);

  static String stageList(PetFamily f, int stage) =>
      '$_root/${f.name}/lvl${_clampStage(stage)}_list.png';

  static String stageIdle(PetFamily f, int stage) => levelIdleIsCard.contains(f)
      ? stageList(f, stage)
      : '$_root/${f.name}/lvl${_clampStage(stage)}_idle.png';

  static String skinList(PetSkin s) =>
      '$_root/${s.family.name}/skin${s.number.toString().padLeft(2, '0')}_list.png';

  static String skinIdle(PetSkin s) => skinIdleIsCard.contains(s.family)
      ? skinList(s)
      : '$_root/${s.family.name}/skin${s.number.toString().padLeft(2, '0')}_idle.png';

  /// ẢNH PET ĐANG HIỂN THỊ trong game: ưu tiên skin IDLE đang trang bị,
  /// nếu không có (hoặc skin lỗi/không hợp lệ) thì IDLE theo cấp pet.
  static String idleFor(PetModel pet) {
    final family = PetFamilyCatalog.familyOf(pet.species);
    final skin = PetFamilyCatalog.skinById(pet.equippedSkin);
    if (skin != null && skin.family == family && pet.unlockedSkins.contains(skin.id)) {
      return skinIdle(skin);
    }
    return stageIdle(family, FriendshipInfo.fromPoints(pet.affectionPoints).petStage);
  }
}

class PetFamilyCatalog {
  PetFamilyCatalog._();

  /// Mỗi loài [PetSpecies] tương ứng đúng 1 họ cùng tên (10 loài ↔ 10 họ).
  static PetFamily familyOf(PetSpecies species) =>
      PetFamily.values.byName(species.name);

  // ----- Skin -----

  /// Độ hiếm theo số thứ tự skin (1..10). Mặc định: 2 Thường / 3 Hiếm /
  /// 2 Sử thi / 3 Huyền thoại. Rồng in nhãn khác nên có bảng riêng
  /// (4 Thường / 2 Hiếm / 2 Sử thi / 2 Huyền thoại — "Không Thường" gộp vào
  /// Thường, "Thượng Hạng" gộp vào Sử thi). Mỗi họ PHẢI có ≥ 1 skin ở mỗi
  /// độ hiếm để weighted random luôn có skin để chọn.
  static const List<SkinRarity> _defaultRarity = [
    SkinRarity.common, SkinRarity.common,
    SkinRarity.rare, SkinRarity.rare, SkinRarity.rare,
    SkinRarity.epic, SkinRarity.epic,
    SkinRarity.legendary, SkinRarity.legendary, SkinRarity.legendary,
  ];
  static const List<SkinRarity> _dragonRarity = [
    SkinRarity.common, SkinRarity.common, SkinRarity.common, SkinRarity.common,
    SkinRarity.rare, SkinRarity.rare,
    SkinRarity.epic, SkinRarity.epic,
    SkinRarity.legendary, SkinRarity.legendary,
  ];

  /// Tên skin (vi, en) theo họ — đúng thứ tự số thứ tự 1..10.
  static const List<List<String>> _themeA = [
    ['Cổ điển', 'Classic'], ['Khủng Long', 'Dino'], ['Thám Tử', 'Detective'],
    ['Ninja', 'Ninja'], ['Vũ Trụ', 'Astronaut'], ['Cổ Trang', 'Traditional'],
    ['Chiến Thần', 'War God'], ['Hỏa Long', 'Fire Dragon'],
    ['Băng Tuyết', 'Frost'], ['Thiên Sứ', 'Angel'],
  ];
  static const List<List<String>> _themeB = [
    ['Tinh Nghịch', 'Playful'], ['Khám Phá', 'Explorer'], ['Thám Tử', 'Detective'],
    ['Siêu Anh Hùng', 'Superhero'], ['Vũ Trụ', 'Astronaut'], ['Công Chúa', 'Princess'],
    ['Samurai', 'Samurai'], ['Hỏa Long', 'Fire Dragon'],
    ['Băng Tuyết', 'Frost'], ['Thiên Sứ', 'Angel'],
  ];
  static const List<List<String>> _dragonNames = [
    ['Kim Long Đại Đế', 'Golden Dragon Emperor'], ['Hỏa Long Thần Hỏa', 'Inferno Dragon'],
    ['Băng Tinh Thần Long', 'Crystal Frost Dragon'], ['Địa Nham Tượng Long', 'Stone Dragon'],
    ['Hải Thần Thủy Long', 'Sea God Dragon'], ['Ám Ảnh Ma Long', 'Shadow Dragon'],
    ['Thần Linh Mộc Long', 'Forest Spirit Dragon'], ['Hư Không Dục Long', 'Void Dragon'],
    ['Quang Minh Thần Long', 'Radiant Dragon'], ['Tinh Không Đế Vương', 'Cosmic Emperor'],
  ];
  static const List<List<String>> _kitsuneNames = [
    ['Cửu Vĩ Thiên Tiên', 'Celestial Kitsune'], ['Cửu Vĩ Đấu Sĩ', 'Warrior Kitsune'],
    ['Cửu Vĩ Tân Nương', 'Bride Kitsune'], ['Cửu Vĩ Hoa Mai', 'Blossom Kitsune'],
    ['Cửu Vĩ Thần Thú', 'Divine Kitsune'], ['Cửu Vĩ Tuyết Sơn', 'Snow Kitsune'],
    ['Cửu Vĩ Hỏa Diệm', 'Flame Kitsune'], ['Cửu Vĩ Ma Hồ', 'Demon Kitsune'],
    ['Cửu Vĩ Lôi Đỉnh', 'Thunder Kitsune'], ['Cửu Vĩ Thiên Hà', 'Galaxy Kitsune'],
  ];
  static const List<List<String>> _slimeNames = [
    ['Xanh Cơ Bản', 'Basic Green'], ['Bống Bóng Bọc', 'Bubble'],
    ['Tuyết Băng', 'Snow Ice'], ['Nham Thạch', 'Magma'],
    ['Thợ Săn', 'Hunter'], ['Ninja Bóng Đêm', 'Night Ninja'],
    ['Giải Mã Dữ Liệu', 'Data Decoder'], ['Ngân Hoa', 'Silver Bloom'],
    ['Vua Slime', 'Slime King'], ['Tinh Không', 'Starry Void'],
  ];

  static List<List<String>> _namesOf(PetFamily f) {
    switch (f) {
      case PetFamily.dragon:
        return _dragonNames;
      case PetFamily.kitsune:
        return _kitsuneNames;
      case PetFamily.slime:
        return _slimeNames;
      case PetFamily.chicken:
      case PetFamily.dog:
      case PetFamily.whale:
        return _themeB;
      default:
        return _themeA;
    }
  }

  static final Map<PetFamily, List<PetSkin>> _skins = {
    for (final f in PetFamily.values)
      f: List<PetSkin>.unmodifiable([
        for (var i = 0; i < 10; i++)
          PetSkin(
            family: f,
            number: i + 1,
            rarity: (f == PetFamily.dragon ? _dragonRarity : _defaultRarity)[i],
            nameVi: _namesOf(f)[i][0],
            nameEn: _namesOf(f)[i][1],
          ),
      ]),
  };

  static List<PetSkin> skinsOf(PetFamily f) => _skins[f]!;

  /// Tìm skin theo id (`dragon_03`). null nếu id lỗi/không tồn tại — caller
  /// phải xử lý (không crash vì dữ liệu hỏng).
  static PetSkin? skinById(String? id) {
    if (id == null) return null;
    final parts = id.split('_');
    if (parts.length != 2) return null;
    final n = int.tryParse(parts[1]);
    if (n == null || n < 1 || n > 10) return null;
    for (final f in PetFamily.values) {
      if (f.name == parts[0]) return _skins[f]![n - 1];
    }
    return null;
  }
}

extension PetDisplayArt on PetModel {
  /// Ảnh IDLE đang hiển thị của pet (skin đang trang bị, nếu không thì
  /// theo cấp pet) — dùng ở MỌI nơi pet "đứng" trong game.
  String get idleAsset => PetArt.idleFor(this);
}
