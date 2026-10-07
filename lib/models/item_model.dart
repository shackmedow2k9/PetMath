enum ItemCategory {
  shirt,
  pants,
  hat,
  glasses,
  shoes,
  wing,
  weapon,
  vehicle,
  house,
  furniture,
  food,
}

enum ItemRarity { common, rare, epic, legendary }

/// Model vật phẩm trong cửa hàng (~100 món theo đặc tả)
class ItemModel {
  final String id;
  final String name;
  final ItemCategory category;
  final ItemRarity rarity;
  final int priceCoin;
  final int priceGem;
  final String imageUrl;
  final bool isLimitedEvent; // đồ theo sự kiện Noel, Tết, Trung thu...

  ItemModel({
    required this.id,
    required this.name,
    required this.category,
    this.rarity = ItemRarity.common,
    this.priceCoin = 0,
    this.priceGem = 0,
    this.imageUrl = '',
    this.isLimitedEvent = false,
  });

  factory ItemModel.fromMap(String id, Map<String, dynamic> map) {
    return ItemModel(
      id: id,
      name: map['name'] ?? '',
      category: ItemCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ItemCategory.shirt,
      ),
      rarity: ItemRarity.values.firstWhere(
        (r) => r.name == map['rarity'],
        orElse: () => ItemRarity.common,
      ),
      priceCoin: map['priceCoin'] ?? 0,
      priceGem: map['priceGem'] ?? 0,
      imageUrl: map['imageUrl'] ?? '',
      isLimitedEvent: map['isLimitedEvent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'rarity': rarity.name,
      'priceCoin': priceCoin,
      'priceGem': priceGem,
      'imageUrl': imageUrl,
      'isLimitedEvent': isLimitedEvent,
    };
  }
}
