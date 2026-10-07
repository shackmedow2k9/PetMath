/// Danh mục đồ ăn cho pet — mua ở Cửa hàng (mục "Đồ ăn"), dùng trong Phòng
/// ăn (kéo thả cho pet ăn kiểu Talking Tom).
///
/// Giá tăng theo cả 2 yếu tố: [hungerRestore] (độ no hồi được) và
/// [expReward] (EXP thưởng khi ăn) — công thức: 20 + hungerRestore*2 +
/// expReward*4, món càng "bổ" (no nhiều, nhiều EXP) thì càng đắt.
class FoodTemplate {
  final String id;
  final String name;
  final String assetPath;
  final int hungerRestore; // độ no hồi được khi ăn (0-100)
  final int expReward;
  final int priceCoin;

  const FoodTemplate({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.hungerRestore,
    required this.expReward,
    required this.priceCoin,
  });
}

class FoodCatalog {
  static const List<FoodTemplate> all = [
    FoodTemplate(
      id: 'banh_mi',
      name: 'Bánh mì',
      assetPath: 'assets/food/banh_mi.png',
      hungerRestore: 20,
      expReward: 5,
      priceCoin: 80,
    ),
    FoodTemplate(
      id: 'kem_dau',
      name: 'Kem dâu',
      assetPath: 'assets/food/kem_dau.png',
      hungerRestore: 15,
      expReward: 6,
      priceCoin: 74,
    ),
    FoodTemplate(
      id: 'kem_ly_ong_que',
      name: 'Kem ly ống quế',
      assetPath: 'assets/food/kem_ly_ong_que.png',
      hungerRestore: 18,
      expReward: 9,
      priceCoin: 92,
    ),
    FoodTemplate(
      id: 'kem_ly_nhieu_vi',
      name: 'Kem ly nhiều vị',
      assetPath: 'assets/food/kem_ly_nhieu_vi.png',
      hungerRestore: 20,
      expReward: 10,
      priceCoin: 100,
    ),
    FoodTemplate(
      id: 'pho_don_gian',
      name: 'Phở',
      assetPath: 'assets/food/pho_don_gian.png',
      hungerRestore: 25,
      expReward: 8,
      priceCoin: 102,
    ),
    FoodTemplate(
      id: 'kem_dua_hau',
      name: 'Kem dưa hấu',
      assetPath: 'assets/food/kem_dua_hau.png',
      hungerRestore: 22,
      expReward: 11,
      priceCoin: 108,
    ),
    FoodTemplate(
      id: 'banh_kem_cuon',
      name: 'Bánh kem cuộn dâu',
      assetPath: 'assets/food/banh_kem_cuon.png',
      hungerRestore: 20,
      expReward: 12,
      priceCoin: 108,
    ),
    FoodTemplate(
      id: 'pho_su_xanh',
      name: 'Phở tô sứ',
      assetPath: 'assets/food/pho_su_xanh.png',
      hungerRestore: 30,
      expReward: 10,
      priceCoin: 120,
    ),
    FoodTemplate(
      id: 'banh_kem_tho',
      name: 'Bánh kem thỏ dâu',
      assetPath: 'assets/food/banh_kem_tho.png',
      hungerRestore: 25,
      expReward: 15,
      priceCoin: 130,
    ),
    FoodTemplate(
      id: 'pho_bo_chanh',
      name: 'Phở bò chanh',
      assetPath: 'assets/food/pho_bo_chanh.png',
      hungerRestore: 35,
      expReward: 16,
      priceCoin: 154,
    ),
    FoodTemplate(
      id: 'pizza',
      name: 'Pizza phô mai',
      assetPath: 'assets/food/pizza.png',
      hungerRestore: 40,
      expReward: 18,
      priceCoin: 172,
    ),
    FoodTemplate(
      id: 'ga_ran',
      name: 'Gà rán',
      assetPath: 'assets/food/ga_ran.png',
      hungerRestore: 45,
      expReward: 20,
      priceCoin: 190,
    ),
    FoodTemplate(
      id: 'pho_dac_biet',
      name: 'Phở đặc biệt',
      assetPath: 'assets/food/pho_dac_biet.png',
      hungerRestore: 50,
      expReward: 22,
      priceCoin: 208,
    ),
  ];

  static FoodTemplate byId(String id) => all.firstWhere(
        (f) => f.id == id,
        orElse: () => all.first,
      );
}
