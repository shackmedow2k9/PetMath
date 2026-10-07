import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../widgets/emoji_icon.dart';
import '../models/food_catalog.dart';
import '../models/house_catalog.dart';
import '../models/item_model.dart';
import '../models/student_model.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Màn hình Cửa hàng — khoảng 100 món theo đặc tả (Áo, Quần, Mũ, Kính...).
/// Nếu 'items' collection rỗng (Nhà sản xuất chưa thêm đồ), hiển thị bộ
/// vật phẩm mẫu để học sinh vẫn trải nghiệm được vòng lặp mua sắm.
///
/// Mục "Nhà" (ItemCategory.house) không dùng danh sách mẫu chung mà hiển
/// thị riêng theo [HouseCatalog], vì nhà có luật chơi khác biệt (chỉ ở
/// được 1 nhà tại 1 thời điểm, mua xong tự chuyển vào ở luôn).
class ShopScreen extends StatefulWidget {
  final ItemCategory? initialCategory;

  const ShopScreen({super.key, this.initialCategory});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _firestoreService = FirestoreService();
  ItemCategory? _filterCategory;
  // Điều khiển cuộn ngang cho hàng danh mục (Tất cả/Áo/Quần...) — cần gắn
  // vào cả Scrollbar lẫn ListView để thanh cuộn hiển thị & hoạt động đúng.
  final _categoryScrollController = ScrollController();

  // Cửa hàng chỉ bán: Nhà, Đồ ăn (đã bỏ Nội thất). Áo/Quần/Mũ/Kính/Giày/Cánh/Vũ khí/Xe
  // đã bị gỡ khỏi cửa hàng (pet đổi diện mạo bằng Skin ở Phòng đổi skin).
  static const List<ItemCategory> _shopCategories = [
    ItemCategory.house,
    ItemCategory.food,
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    _filterCategory = (initial != null && _shopCategories.contains(initial))
        ? initial
        : ItemCategory.house;
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    super.dispose();
  }

  static const _sampleItems = [
    {
      'id': 'house1',
      'name': 'Nhà gỗ ấm cúng',
      'category': 'house',
      'priceCoin': 800
    },
  ];

  List<ItemModel> _itemsFromSample() {
    return _sampleItems
        .map((m) => ItemModel.fromMap(m['id'] as String, m))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final student = auth.currentStudent!;

    return ScreenScaffold(bg: BgKind.light, 
      appBar: AppBar(
        title: const Text('Cửa hàng'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(children: [
                const EmojiIcon('🪙', size: 18),
                const SizedBox(width: 4),
                Text(student.coinDisplay,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _CipherTicketBanner(
            tickets: student.cipherTickets,
            coin: student.coin,
            coinInfinite: student.coinInfinite,
            onBuy: () => _handleBuyCipherTicket(student),
          ),
          SizedBox(
            height: 56,
            child: Scrollbar(
              controller: _categoryScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: ListView(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  ..._shopCategories.map((c) => _CategoryChip(
                        label: _categoryLabel(c),
                        selected: _filterCategory == c,
                        onTap: () => setState(() => _filterCategory = c),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: _filterCategory == ItemCategory.house
                ? const _HouseGrid()
                : _filterCategory == ItemCategory.food
                    ? const _FoodGrid()
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _firestoreService.watchShopItems(),
                        builder: (context, snapshot) {
                          List<ItemModel> items;
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            items = _itemsFromSample();
                          } else {
                            items = snapshot.data!
                                .map((m) => ItemModel.fromMap(m['id'], m))
                                .toList();
                          }

                          if (_filterCategory != null) {
                            items = items
                                .where((i) =>
                                    _shopCategories.contains(i.category) &&
                                    i.category == _filterCategory)
                                .toList();
                          } else {
                            // Ở tab "Tất cả", nhà và đồ ăn có luật mua riêng nên
                            // không trộn chung với danh sách vật phẩm mặc/trang bị.
                            items = items
                                .where((i) =>
                                    i.category != ItemCategory.house &&
                                    i.category != ItemCategory.food)
                                .toList();
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: items.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.85,
                            ),
                            itemBuilder: (context, index) => _ItemCard(
                              item: items[index],
                              studentCoin: student.coin,
                              coinInfinite: student.coinInfinite,
                              onBuy: () => _handleBuy(items[index]),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBuy(ItemModel item) async {
    final auth = context.read<AuthProvider>();
    final petProvider = context.read<PetProvider>();
    final student = auth.currentStudent!;

    if (!student.hasEnoughCoin(item.priceCoin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bạn không đủ Coin, hãy làm thêm bài tập nhé!')),
      );
      return;
    }

    try {
      await _firestoreService.purchaseItem(
        studentId: student.uid,
        itemId: item.id,
        priceCoin: item.priceCoin,
      );
      await _firestoreService.toggleEquipItem(
          petProvider.pet!.id, item.id, true);

      auth.currentStudent = student.copyWith(
        coin: student.coin - item.priceCoin,
        inventoryItemIds: [...student.inventoryItemIds, item.id],
      );
      auth.notifyListeners();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã mua và mặc "${item.name}" cho pet! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mua thất bại: $e')),
        );
      }
    }
  }

  Future<void> _handleBuyCipherTicket(StudentModel student) async {
    final auth = context.read<AuthProvider>();
    if (!student.hasEnoughCoin(FirestoreService.cipherTicketPriceCoin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Bạn không đủ Coin (cần ${FirestoreService.cipherTicketPriceCoin} Coin)')),
      );
      return;
    }
    try {
      await _firestoreService.buyCipherTicket(student.uid);
      auth.currentStudent = student.copyWith(
        coin: student.coin - FirestoreService.cipherTicketPriceCoin,
        cipherTickets: student.cipherTickets + 1,
      );
      auth.notifyListeners();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã mua 1 Vé giải mật mã! 🎫')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mua thất bại: $e')),
        );
      }
    }
  }

  String _categoryLabel(ItemCategory c) => switch (c) {
        ItemCategory.shirt => 'Áo',
        ItemCategory.pants => 'Quần',
        ItemCategory.hat => 'Mũ',
        ItemCategory.glasses => 'Kính',
        ItemCategory.shoes => 'Giày',
        ItemCategory.wing => 'Cánh',
        ItemCategory.weapon => 'Vũ khí',
        ItemCategory.vehicle => 'Xe',
        ItemCategory.house => 'Nhà',
        ItemCategory.furniture => 'Nội thất',
        ItemCategory.food => 'Đồ ăn',
      };
}

class _CipherTicketBanner extends StatelessWidget {
  final int tickets;
  final int coin;
  final bool coinInfinite;
  final VoidCallback onBuy;

  const _CipherTicketBanner(
      {required this.tickets,
      required this.coin,
      this.coinInfinite = false,
      required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final canAfford =
        coinInfinite || coin >= FirestoreService.cipherTicketPriceCoin;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('🎫', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vé giải mật mã',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Đang có $tickets vé · 1 vé = 1 lượt chơi',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canAfford ? onBuy : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                backgroundColor:
                    canAfford ? AppColors.secondary : Colors.grey.shade300,
              ),
              child: Text('🪙 ${FirestoreService.cipherTicketPriceCoin}',
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle:
            TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
      ),
    );
  }
}

/// Lưới các căn nhà trong Cửa hàng — giá tăng dần từ trái qua phải theo
/// đúng thứ tự khai báo trong [HouseCatalog]. Nhà gỗ mặc định luôn miễn phí
/// và đã sở hữu sẵn.
class _HouseGrid extends StatelessWidget {
  const _HouseGrid();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final petProvider = context.watch<PetProvider>();
    final student = auth.currentStudent;
    final pet = petProvider.pet;

    if (student == null || pet == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: HouseCatalog.all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final house = HouseCatalog.all[index];
        final isOwned = pet.ownedHouseIds.contains(house.id);
        final isCurrent = pet.currentHouseId == house.id;

        return _HouseCard(
          house: house,
          isOwned: isOwned,
          isCurrent: isCurrent,
          canAfford: student.hasEnoughCoin(house.priceCoin),
          onTap: () async {
            final firestoreService = FirestoreService();
            try {
              if (isOwned) {
                await firestoreService.setCurrentHouse(pet.id, house.id);
              } else {
                await firestoreService.purchaseHouse(
                  studentId: student.uid,
                  petId: pet.id,
                  houseId: house.id,
                  priceCoin: house.priceCoin,
                );
                auth.currentStudent =
                    student.copyWith(coin: student.coin - house.priceCoin);
                auth.notifyListeners();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(isOwned
                          ? 'Đã chuyển pet vào ở "${house.name}"! 🏠'
                          : 'Đã mua và chuyển vào ở "${house.name}"! 🎉')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Không thể thực hiện: $e')),
                );
              }
            }
          },
        );
      },
    );
  }
}

class _HouseCard extends StatelessWidget {
  final HouseTemplate house;
  final bool isOwned;
  final bool isCurrent;
  final bool canAfford;
  final VoidCallback onTap;

  const _HouseCard({
    required this.house,
    required this.isOwned,
    required this.isCurrent,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = isCurrent ? false : (isOwned || canAfford);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isCurrent
            ? const BorderSide(color: AppColors.gold, width: 2.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(house.assetPath, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(house.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canTap ? onTap : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  backgroundColor: isCurrent
                      ? AppColors.gold
                      : isOwned
                          ? AppColors.success
                          : (canAfford
                              ? AppColors.secondary
                              : Colors.grey.shade300),
                ),
                child: Text(
                  isCurrent
                      ? 'Đang ở'
                      : isOwned
                          ? 'Chuyển vào ở'
                          : (house.priceCoin == 0
                              ? 'Miễn phí'
                              : '🪙 ${house.priceCoin}'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lưới đồ ăn trong Cửa hàng — mỗi món hồi No bụng & EXP khác nhau, giá
/// tăng theo cả 2 chỉ số đó. Mua xong cộng vào kho đồ ăn, dùng ở Phòng ăn
/// (kéo thả cho pet ăn).
class _FoodGrid extends StatelessWidget {
  const _FoodGrid();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final student = auth.currentStudent;
    if (student == null) {
      return const Center(child: CircularProgressIndicator());
    }

    Future<void> handleBuy(FoodTemplate food) async {
      if (!student.hasEnoughCoin(food.priceCoin)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bạn không đủ Coin, hãy làm thêm bài tập nhé!')),
        );
        return;
      }
      try {
        await FirestoreService().buyFood(student.uid, food.id, food.priceCoin);
        final newInventory = Map<String, int>.from(student.foodInventory);
        newInventory[food.id] = (newInventory[food.id] ?? 0) + 1;
        auth.currentStudent = student.copyWith(
          coin: student.coin - food.priceCoin,
          foodInventory: newInventory,
        );
        auth.notifyListeners();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Đã mua "${food.name}"! Vào Phòng ăn để cho pet ăn nhé 🍽️')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mua thất bại: $e')),
          );
        }
      }
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: FoodCatalog.all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final food = FoodCatalog.all[index];
        final owned = student.foodInventory[food.id] ?? 0;
        return _FoodCard(
          food: food,
          owned: owned,
          canAfford: student.hasEnoughCoin(food.priceCoin),
          onBuy: () => handleBuy(food),
        );
      },
    );
  }
}

class _FoodCard extends StatelessWidget {
  final FoodTemplate food;
  final int owned;
  final bool canAfford;
  final VoidCallback onBuy;

  const _FoodCard({
    required this.food,
    required this.owned,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(food.assetPath, fit: BoxFit.contain),
                    ),
                  ),
                  if (owned > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('x$owned',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(food.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('🍗 +${food.hungerRestore} · ⭐ +${food.expReward} EXP',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canAfford ? onBuy : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  backgroundColor:
                      canAfford ? AppColors.secondary : Colors.grey.shade300,
                ),
                child: Text('🪙 ${food.priceCoin}',
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ItemModel item;
  final int studentCoin;
  final bool coinInfinite;
  final VoidCallback onBuy;

  const _ItemCard(
      {required this.item,
      required this.studentCoin,
      this.coinInfinite = false,
      required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final canAfford = coinInfinite || studentCoin >= item.priceCoin;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Text('🎁', style: TextStyle(fontSize: 40))),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canAfford ? onBuy : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  backgroundColor:
                      canAfford ? AppColors.secondary : Colors.grey.shade300,
                ),
                child: Text('🪙 ${item.priceCoin}',
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
