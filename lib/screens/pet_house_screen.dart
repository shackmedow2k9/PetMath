import 'package:flutter/material.dart' hide Text;
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../models/house_catalog.dart';
import '../models/item_model.dart';
import '../models/pet_model.dart';
import '../models/pet_family_catalog.dart';
import '../widgets/skin_room_sheet.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_bar.dart';
import 'shop_screen.dart';

/// Màn hình "Nhà của pet" — mở ra khi bấm vào ô nhà ở Nhà của thú cưng.
/// Học sinh có thể cho pet ăn, tắm rửa, đổi skin, hoặc đổi sang
/// một căn nhà khác đã sở hữu / đi mua nhà mới ở Cửa hàng.
class PetHouseScreen extends StatefulWidget {
  const PetHouseScreen({super.key});

  @override
  State<PetHouseScreen> createState() => _PetHouseScreenState();
}

class _PetHouseScreenState extends State<PetHouseScreen> {
  final _firestoreService = FirestoreService();
  bool _busy = false;

  Future<void> _feed() async {
    final auth = context.read<AuthProvider>();
    final pet = context.read<PetProvider>().pet;
    final student = auth.currentStudent;
    if (pet == null || student == null) return;

    if (!student.hasEnoughCoin(FirestoreService.feedCostCoin)) {
      _showMessage('Bạn không đủ Coin để mua đồ ăn, hãy làm thêm bài tập nhé!');
      return;
    }

    setState(() => _busy = true);
    try {
      await _firestoreService.feedPet(studentId: student.uid, petId: pet.id);
      auth.currentStudent =
          student.copyWith(coin: student.coin - FirestoreService.feedCostCoin);
      auth.notifyListeners();
      _showMessage('Pet đã được ăn no nê! 🍗');
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bathe() async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null) return;

    setState(() => _busy = true);
    try {
      await _firestoreService.bathePet(pet.id);
      _showMessage('Pet sạch sẽ thơm tho rồi! 🛁');
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openWardrobe() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SkinRoomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petProvider = context.watch<PetProvider>();
    final pet = petProvider.pet;

    if (pet == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final house = HouseCatalog.byId(pet.currentHouseId);

    return Scaffold(
      appBar: AppBar(title: Text('Nhà của ${pet.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Khung cảnh nhà + pet.
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.info.withValues(alpha: 0.18),
                    AppColors.success.withValues(alpha: 0.18),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 10,
                    child: Image.asset(house.assetPath, height: 190),
                  ),
                  Positioned(
                    bottom: 16,
                    child: Container(
                      width: 84,
                      height: 84,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: AppColors.gold, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 8),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(pet.idleAsset,
                            fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(house.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),

            // Chỉ số của pet.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    StatBar(
                        emoji: '🍗',
                        label: 'No bụng',
                        value: pet.hunger,
                        color: AppColors.secondary),
                    StatBar(
                        emoji: '❤️',
                        label: 'HP',
                        value: pet.hp,
                        color: AppColors.danger),
                    StatBar(
                        emoji: '⚡',
                        label: 'Năng lượng',
                        value: pet.energy,
                        color: AppColors.info),
                    StatBar(
                        emoji: '😊',
                        label: 'Vui vẻ',
                        value: pet.happiness,
                        color: AppColors.success),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Các hành động chăm sóc pet.
            Row(
              children: [
                Expanded(
                  child: _CareButton(
                    emoji: '🍗',
                    label: 'Cho ăn',
                    sublabel: '🪙 ${FirestoreService.feedCostCoin}',
                    color: AppColors.secondary,
                    onTap: _busy ? null : _feed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CareButton(
                    emoji: '🛁',
                    label: 'Tắm rửa',
                    sublabel: 'Miễn phí',
                    color: AppColors.info,
                    onTap: _busy ? null : _bathe,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CareButton(
                    emoji: '🎭',
                    label: 'Đổi skin',
                    sublabel: 'Phòng skin',
                    color: AppColors.primary,
                    onTap: _busy ? null : _openWardrobe,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CareButton(
                    emoji: '🏠',
                    label: 'Đổi nhà',
                    sublabel: 'Cửa hàng',
                    color: AppColors.gold,
                    onTap: _busy
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ShopScreen(
                                    initialCategory: ItemCategory.house),
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CareButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback? onTap;

  const _CareButton({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: onTap == null ? 0.08 : 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(sublabel,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
