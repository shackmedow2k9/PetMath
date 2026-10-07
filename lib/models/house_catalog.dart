/// Danh mục nhà cho thú cưng — mua ở Cửa hàng (mục "Nhà").
/// "Nhà gỗ" là nhà mặc định, học sinh nào cũng có sẵn miễn phí.
/// Giá tăng dần theo thứ tự từ trái qua phải (theo đúng thứ tự hiển thị
/// trong cửa hàng), Lâu đài là nhà đắt nhất với giá 1000 Coin.
class HouseTemplate {
  final String id;
  final String name;
  final String assetPath;
  final int priceCoin;

  const HouseTemplate({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.priceCoin,
  });
}

class HouseCatalog {
  /// ID của nhà mặc định — mọi pet đều sở hữu sẵn nhà này, không cần mua.
  static const String defaultHouseId = 'wood';

  static const List<HouseTemplate> all = [
    HouseTemplate(
      id: 'wood',
      name: 'Nhà gỗ',
      assetPath: 'assets/images/houses/house_wood.png',
      priceCoin: 0,
    ),
    HouseTemplate(
      id: 'tree',
      name: 'Nhà cây',
      assetPath: 'assets/images/houses/house_tree.png',
      priceCoin: 300,
    ),
    HouseTemplate(
      id: 'mushroom',
      name: 'Nhà nấm',
      assetPath: 'assets/images/houses/house_mushroom.png',
      priceCoin: 500,
    ),
    HouseTemplate(
      id: 'gingerbread',
      name: 'Nhà bánh gừng',
      assetPath: 'assets/images/houses/house_gingerbread.png',
      priceCoin: 700,
    ),
    HouseTemplate(
      id: 'tech',
      name: 'Nhà công nghệ',
      assetPath: 'assets/images/houses/house_tech.png',
      priceCoin: 850,
    ),
    HouseTemplate(
      id: 'castle',
      name: 'Lâu đài',
      assetPath: 'assets/images/houses/house_castle.png',
      priceCoin: 1000,
    ),
  ];

  static HouseTemplate byId(String id) => all.firstWhere(
        (h) => h.id == id,
        orElse: () => all.first,
      );
}
