import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/crop_catalog.dart';
import '../models/farm_layout.dart';
import '../models/farm_plot_model.dart';
import '../models/house_catalog.dart';
import '../models/pet_model.dart';
import '../models/pet_family_catalog.dart';
import '../models/student_model.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Mini game Nông trại (lấy ý tưởng từ Hay Day): trồng HOA (bán lấy
/// Coin/Gem) và TRÁI CÂY (cho pet ăn) trên nền hình khu vườn thật, cây
/// lớn dần theo thời gian THỰC qua 5 giai đoạn, cần tưới nước đều đặn
/// (không thì héo rồi chết), bón phân giúp lớn nhanh hơn. Pet của học
/// sinh đi dạo quanh vườn cho sinh động — kế thừa cử động/hiệu ứng từ
/// "Nhà của pet" (bập bênh nhẹ khi đứng yên, nhún theo bước chân khi di
/// chuyển) nhưng CHỈ giữ lại hành động đi dạo, không mang theo 4 hành
/// động tự chơi còn lại (quay mặt tại chỗ, nhảy nhẹ, xoay vòng, nhảy
/// cao) — đây là tương tác duy nhất của pet ở màn hình này.
class PlantGrowingScreen extends StatefulWidget {
  const PlantGrowingScreen({super.key});

  @override
  State<PlantGrowingScreen> createState() => _PlantGrowingScreenState();
}

class _PlantGrowingScreenState extends State<PlantGrowingScreen>
    with TickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _random = Random();
  Timer? _ticker;
  Timer? _wanderTimer;
  Timer? _walkArrivalTimer;
  bool _busy = false;

  // ---- Pet đi dạo: chỉ đổi vị trí đích định kỳ, AnimatedPositioned lo
  // phần trượt mượt giữa 2 điểm. Đây là DUY NHẤT hành động pet có ở màn
  // hình này (kế thừa từ "Nhà của pet" nhưng KHÔNG mang theo 4 hành động
  // tự chơi còn lại — quay mặt tại chỗ/nhảy nhẹ/xoay vòng/nhảy cao — chỉ
  // giữ lại phần đi dạo + 2 hiệu ứng bập bênh đi kèm nó: bập bênh nhẹ khi
  // đứng yên và nhún bước chân khi đang di chuyển) ----
  Offset _petTarget = FarmLayout.petWanderSpots.first;
  bool _petFacingLeft = false;
  bool _petWalking = false;
  Duration _petMoveDuration = const Duration(seconds: 4);

  // Bập bênh nhẹ khi pet đứng yên giữa 2 lượt đi dạo.
  late final AnimationController _idleBobController;
  // Nhún theo bước chân khi pet đang di chuyển.
  late final AnimationController _walkBobController;

  @override
  void initState() {
    super.initState();
    // Cập nhật lại giao diện mỗi giây để thanh Nước/Dinh dưỡng và trạng
    // thái héo/chín/chết luôn đúng — KHÔNG đọc lại Firestore, mọi thứ
    // tính từ [FarmPlotState] dựa theo đồng hồ máy.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _idleBobController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _walkBobController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _scheduleNextWander();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _wanderTimer?.cancel();
    _walkArrivalTimer?.cancel();
    _idleBobController.dispose();
    _walkBobController.dispose();
    super.dispose();
  }

  void _scheduleNextWander() {
    final waitSeconds =
        5 + _random.nextInt(6); // đứng lại 5-10s rồi mới đi tiếp
    _wanderTimer = Timer(Duration(seconds: waitSeconds), _startNextWalk);
  }

  void _startNextWalk() {
    if (!mounted) return;
    final spots = FarmLayout.petWanderSpots;
    Offset next;
    do {
      next = spots[_random.nextInt(spots.length)];
    } while (next == _petTarget && spots.length > 1);
    final dist = (next - _petTarget).distance;
    final duration =
        Duration(milliseconds: (dist * 9000).clamp(1800, 5000).round());
    setState(() {
      _petFacingLeft = next.dx < _petTarget.dx;
      _petTarget = next;
      _petMoveDuration = duration;
      _petWalking = true;
    });
    _walkBobController.repeat();
    _walkArrivalTimer?.cancel();
    _walkArrivalTimer = Timer(duration, () {
      if (!mounted) return;
      _walkBobController
        ..stop()
        ..value = 0;
      setState(() => _petWalking = false);
      _scheduleNextWander();
    });
  }

  StudentModel? get _student => context.read<AuthProvider>().currentStudent;

  void _updateLocalStudent(StudentModel updated) {
    final auth = context.read<AuthProvider>();
    auth.currentStudent = updated;
    auth.notifyListeners();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= HÀNH ĐỘNG =================

  Future<void> _plant(int plotIndex, CropTemplate crop) async {
    final student = _student;
    if (student == null || _busy) return;
    if (!student.hasEnoughCoin(crop.priceCoin)) {
      _showSnack('Không đủ Coin để mua hạt ${crop.name} 🥲');
      return;
    }
    setState(() => _busy = true);
    final ok = await _firestoreService.plantCrop(
      student.uid,
      plotIndex: plotIndex,
      cropId: crop.id,
      costCoin: crop.priceCoin,
    );
    if (ok) {
      final now = Timestamp.now();
      final newFarmPlots = Map<String, dynamic>.from(student.farmPlots);
      newFarmPlots['$plotIndex'] = {
        'cropId': crop.id,
        'plantedAt': now,
        'growAccumSeconds': 0,
        'lastWateredAt': now,
        'lastFertilizedAt': now,
        'lastCareUpdateAt': now,
      };
      _updateLocalStudent(student.copyWith(
        coin: student.coinInfinite ? null : student.coin - crop.priceCoin,
        farmPlots: newFarmPlots,
      ));
      HapticFeedback.lightImpact();
    } else {
      _showSnack('Không trồng được — thử lại nhé!');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _water(FarmPlotState plot) async {
    final student = _student;
    if (student == null || _busy) return;
    setState(() => _busy = true);
    final ok = await _firestoreService.waterCrop(student.uid, plot.plotIndex);
    if (ok) {
      final now = DateTime.now();
      final newFarmPlots = Map<String, dynamic>.from(student.farmPlots);
      newFarmPlots['${plot.plotIndex}'] = {
        'cropId': plot.cropId,
        'plantedAt': Timestamp.fromDate(plot.plantedAt),
        'growAccumSeconds': plot.liveGrowSeconds(now: now),
        'lastWateredAt': Timestamp.fromDate(now),
        'lastFertilizedAt': Timestamp.fromDate(plot.lastFertilizedAt),
        'lastCareUpdateAt': Timestamp.fromDate(now),
      };
      _updateLocalStudent(student.copyWith(farmPlots: newFarmPlots));
      HapticFeedback.mediumImpact();
      _showSnack('Đã tưới nước cho ${plot.crop.name} 💧');
    } else {
      _showSnack('Không tưới được — có thể cây đã chết rồi 💀');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _fertilize(FarmPlotState plot) async {
    final student = _student;
    if (student == null || _busy) return;
    if (!student.hasEnoughCoin(kFertilizeCostCoin)) {
      _showSnack('Không đủ Coin để mua phân bón (cần $kFertilizeCostCoin 🪙)');
      return;
    }
    setState(() => _busy = true);
    final ok =
        await _firestoreService.fertilizeCrop(student.uid, plot.plotIndex);
    if (ok) {
      final now = DateTime.now();
      final newFarmPlots = Map<String, dynamic>.from(student.farmPlots);
      newFarmPlots['${plot.plotIndex}'] = {
        'cropId': plot.cropId,
        'plantedAt': Timestamp.fromDate(plot.plantedAt),
        'growAccumSeconds': plot.liveGrowSeconds(now: now),
        'lastWateredAt': Timestamp.fromDate(plot.lastWateredAt),
        'lastFertilizedAt': Timestamp.fromDate(now),
        'lastCareUpdateAt': Timestamp.fromDate(now),
      };
      _updateLocalStudent(student.copyWith(
        coin: student.coinInfinite ? null : student.coin - kFertilizeCostCoin,
        farmPlots: newFarmPlots,
      ));
      HapticFeedback.mediumImpact();
      _showSnack('Đã bón phân cho ${plot.crop.name} 🌰');
    } else {
      _showSnack('Không bón được — có thể cây đã chết rồi 💀');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _harvest(FarmPlotState plot) async {
    final student = _student;
    if (student == null || _busy || !plot.isReady()) return;
    setState(() => _busy = true);
    final crop = plot.crop;
    var coinReward = 0;
    var gemReward = 0;
    if (!crop.isFruit) {
      coinReward = crop.coinRewardMin +
          _random.nextInt(crop.coinRewardMax - crop.coinRewardMin + 1);
      gemReward = crop.gemChance > 0 && _random.nextDouble() < crop.gemChance
          ? 1 + _random.nextInt(crop.gemRewardMax)
          : 0;
    }
    final ok = await _firestoreService.harvestCrop(
      student.uid,
      plot.plotIndex,
      coinReward: coinReward,
      gemReward: gemReward,
      isFruit: crop.isFruit,
    );
    if (ok) {
      final newFarmPlots = Map<String, dynamic>.from(student.farmPlots)
        ..remove('${plot.plotIndex}');
      final newFoodInventory = Map<String, int>.from(student.foodInventory);
      if (crop.isFruit) {
        newFoodInventory[crop.id] = (newFoodInventory[crop.id] ?? 0) + 1;
      }
      _updateLocalStudent(student.copyWith(
        coin: crop.isFruit ? null : student.coin + coinReward,
        gem: crop.isFruit ? null : student.gem + gemReward,
        farmPlots: newFarmPlots,
        foodInventory: newFoodInventory,
      ));
      HapticFeedback.heavyImpact();
      if (crop.isFruit) {
        _showFruitHarvestDialog(crop);
      } else {
        _showFlowerHarvestDialog(crop, coinReward, gemReward);
      }
    } else {
      _showSnack('Không thu hoạch được — thử làm mới lại nhé!');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _clearDead(FarmPlotState plot) async {
    final student = _student;
    if (student == null || _busy) return;
    setState(() => _busy = true);
    final ok =
        await _firestoreService.clearDeadPlot(student.uid, plot.plotIndex);
    if (ok) {
      final newFarmPlots = Map<String, dynamic>.from(student.farmPlots)
        ..remove('${plot.plotIndex}');
      _updateLocalStudent(student.copyWith(farmPlots: newFarmPlots));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _unlockPlot(int plotIndex) async {
    final student = _student;
    if (student == null || _busy) return;
    final costIndex = plotIndex - kFarmFreePlots;
    if (costIndex < 0 || costIndex >= kFarmUnlockCosts.length) return;
    final cost = kFarmUnlockCosts[costIndex];
    if (!student.hasEnoughCoin(cost)) {
      _showSnack('Không đủ Coin để mở ô đất này (cần $cost 🪙)');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mở khoá ô đất mới'),
        content: Text('Tốn $cost 🪙 để mở thêm 1 ô đất trồng cây.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mở khoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final ok = await _firestoreService.unlockFarmPlot(student.uid, cost);
    if (ok) {
      _updateLocalStudent(student.copyWith(
        coin: student.coinInfinite ? null : student.coin - cost,
        farmPlotsUnlocked: student.farmPlotsUnlocked + 1,
      ));
      HapticFeedback.mediumImpact();
    } else {
      _showSnack('Không mở khoá được — thử lại nhé!');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _feedFruitToPet(CropTemplate crop) async {
    final student = _student;
    final pet = context.read<PetProvider>().pet;
    if (student == null || pet == null || _busy) return;
    final owned = student.foodInventory[crop.id] ?? 0;
    if (owned < 1) return;
    setState(() => _busy = true);
    final ok = await _firestoreService.feedPetWithFood(
      studentId: student.uid,
      petId: pet.id,
      foodId: crop.id,
      hungerRestore: crop.hungerRestore,
      expReward: crop.expReward,
    );
    if (ok) {
      final newFoodInventory = Map<String, int>.from(student.foodInventory);
      newFoodInventory[crop.id] = (newFoodInventory[crop.id] ?? 1) - 1;
      _updateLocalStudent(student.copyWith(foodInventory: newFoodInventory));
      HapticFeedback.lightImpact();
      _showSnack('Pet đã ăn ${crop.name} ${crop.emoji}, thích lắm! 🥰');
    }
    if (mounted) setState(() => _busy = false);
  }

  // ================= DIALOG / BOTTOM SHEET =================

  void _showFlowerHarvestDialog(CropTemplate crop, int coin, int gem) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Thu hoạch ${crop.name} ${crop.emoji}',
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🪙 +$coin Coin',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (gem > 0) ...[
              const SizedBox(height: 4),
              Text('💎 +$gem Gem',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.info)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tuyệt vời!'),
          ),
        ],
      ),
    );
  }

  void _showFruitHarvestDialog(CropTemplate crop) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Thu hoạch ${crop.name} ${crop.emoji}',
            textAlign: TextAlign.center),
        content: const Text('Đã thêm vào kho đồ ăn — cho pet ăn ngay không?',
            textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _feedFruitToPet(crop);
            },
            child: const Text('Cho ăn luôn 🐾'),
          ),
        ],
      ),
    );
  }

  void _showDeadPlotSheet(FarmPlotState plot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💀', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              Text(
                '${plot.crop.name} đã héo chết vì quên tưới nước quá lâu 😢',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _clearDead(plot);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Dọn dẹp ô đất 🧹'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlotCareSheet(FarmPlotState plot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final now = DateTime.now();
        final wilted = plot.isWilted(now: now);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(plot.stageEmoji(now: now),
                    style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 6),
                Text('${plot.crop.name} • ${plot.stageName}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                if (wilted)
                  const Text('⚠️ Cây đang héo — tưới ngay kẻo chết!',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold))
                else
                  Text('Còn ${plot.remainingLabel(now: now)} nữa sẽ chín 🕒',
                      style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                _MiniLevelBar(
                    label: 'Nước 💧',
                    value: plot.waterLevel(now: now),
                    color: Colors.blue),
                const SizedBox(height: 8),
                _MiniLevelBar(
                    label: 'Dinh dưỡng 🌰',
                    value: plot.nutritionLevel(now: now),
                    color: const Color(0xFF8D6E63)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _water(plot);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue),
                        child: const Text('Tưới nước 💧'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _fertilize(plot);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8D6E63)),
                        child: Text('Bón phân ($kFertilizeCostCoin 🪙)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSeedShop(int? plotIndex) {
    final student = _student;
    if (student == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _SeedShopSheet(
        student: student,
        plantable: plotIndex != null,
        onPick: (crop) {
          Navigator.pop(sheetContext);
          if (plotIndex != null) _plant(plotIndex, crop);
        },
      ),
    );
  }

  void _onTapPlot(int index, FarmPlotState? plot, int unlockedCount) {
    if (_busy) return;
    if (index >= unlockedCount) {
      _unlockPlot(index);
      return;
    }
    if (plot == null) {
      _openSeedShop(index);
      return;
    }
    if (plot.isDead()) {
      _showDeadPlotSheet(plot);
      return;
    }
    if (plot.isReady()) {
      _harvest(plot);
      return;
    }
    _showPlotCareSheet(plot);
  }

  // ================= GIAO DIỆN =================

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent;
    final pet = context.watch<PetProvider>().pet;
    final now = DateTime.now();

    if (student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final plots = parseFarmPlots(student.farmPlots);
    final plotByIndex = {for (final p in plots) p.plotIndex: p};
    final house =
        HouseCatalog.byId(pet?.currentHouseId ?? HouseCatalog.defaultHouseId);

    // Màn hình rộng (vd. để cửa sổ trình duyệt toàn màn hình trên máy
    // tính): bỏ thanh tiêu đề riêng, cho nền vườn chiếm trọn khu vực thân
    // trang, cụm xu/kim cương/số ô + nút quay lại/cửa hàng nổi ngay trên
    // nền vườn thay vì nằm trong dải header tách biệt. Cửa sổ hẹp/nửa màn
    // hình giữ NGUYÊN cách hiển thị cũ (đã ổn).
    final isWide = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      backgroundColor: const Color(0xFF9CCC65),
      appBar: isWide
          ? null
          : AppBar(
              title: const Text('Nông trại 🚜'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.storefront),
                  tooltip: tr('Cửa hàng Nông trại'),
                  onPressed: () => _openSeedShop(null),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isWide)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatChip(emoji: '🪙', label: student.coinDisplay),
                    const SizedBox(width: 10),
                    _StatChip(emoji: '💎', label: student.gemDisplay),
                    const SizedBox(width: 10),
                    _StatChip(
                        emoji: '🌾',
                        label: '${student.farmPlotsUnlocked}/$kFarmMaxPlots'),
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double width;
                    double height;
                    if (isWide) {
                      // Lấp đầy toàn bộ khu vực còn lại — không giữ khung
                      // theo đúng tỉ lệ ảnh gốc nữa (ảnh nền dùng
                      // BoxFit.fill nên vẫn phủ kín, không méo quá mức với
                      // các tỉ lệ màn hình thường gặp), để nền vườn to hết
                      // cỡ thay vì bị viền xanh bao quanh.
                      width = constraints.maxWidth;
                      height = constraints.maxHeight;
                    } else {
                      width = constraints.maxWidth;
                      height = width / FarmLayout.imageAspectRatio;
                      if (height > constraints.maxHeight) {
                        height = constraints.maxHeight;
                        width = height * FarmLayout.imageAspectRatio;
                      }
                    }
                    final stackSize = Size(width, height);
                    return SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/farm/garden_bg.jpg',
                              fit: BoxFit.fill,
                            ),
                          ),
                          _positionedAt(
                            center: FarmLayout.housePosition,
                            widthFrac: FarmLayout.houseWidth,
                            heightFrac: FarmLayout.houseHeight,
                            stackSize: stackSize,
                            // Lật ngang cho nhà quay mặt sang hướng khác,
                            // kiểu ảnh phản chiếu qua gương.
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(pi),
                              child: Image.asset(house.assetPath,
                                  fit: BoxFit.contain),
                            ),
                          ),
                          for (int i = 0; i < kFarmMaxPlots; i++)
                            _positionedAt(
                              center: FarmLayout.plotCenters[i],
                              widthFrac: FarmLayout.plotWidth,
                              heightFrac: FarmLayout.plotHeight,
                              stackSize: stackSize,
                              child: _PlotOverlay(
                                locked: i >= student.farmPlotsUnlocked,
                                unlockCost: i >= student.farmPlotsUnlocked &&
                                        (i - kFarmFreePlots) <
                                            kFarmUnlockCosts.length
                                    ? kFarmUnlockCosts[i - kFarmFreePlots]
                                    : null,
                                plot: plotByIndex[i],
                                now: now,
                                onTap: () => _onTapPlot(i, plotByIndex[i],
                                    student.farmPlotsUnlocked),
                              ),
                            ),
                          if (pet != null)
                            AnimatedPositioned(
                              duration: _petMoveDuration,
                              curve: Curves.easeInOut,
                              left: _petTarget.dx * width - 32,
                              top: _petTarget.dy * height - 56,
                              width: 64,
                              height: 64,
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: Listenable.merge(
                                      [_idleBobController, _walkBobController]),
                                  builder: (context, child) {
                                    // Đang đi dạo: nhún nhanh theo bước chân.
                                    // Đang đứng yên: bập bênh chậm, nhẹ nhàng.
                                    final liftY = _petWalking
                                        ? sin(_walkBobController.value * 2 * pi)
                                                .abs() *
                                            6
                                        : sin(_idleBobController.value * pi) *
                                            4;
                                    return Transform.translate(
                                      offset: Offset(0, -liftY),
                                      child: child,
                                    );
                                  },
                                  child: Transform(
                                    alignment: Alignment.center,
                                    // Ảnh gốc trong assets/pets vẽ pet quay
                                    // mặt sang TRÁI theo mặc định, nên chỉ
                                    // cần lật ảnh khi đang đi sang PHẢI.
                                    transform: Matrix4.rotationY(
                                        _petFacingLeft ? 0 : pi),
                                    child: Image.asset(pet.idleAsset,
                                        fit: BoxFit.contain),
                                  ),
                                ),
                              ),
                            ),
                          // Màn hình rộng: nút quay lại + cụm chỉ số + nút
                          // cửa hàng nổi ngay trên nền vườn (thay cho thanh
                          // tiêu đề riêng đã bị ẩn ở trên).
                          if (isWide)
                            Positioned(
                              top: 12,
                              left: 12,
                              right: 12,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _RoundIconButton(
                                    icon: Icons.arrow_back,
                                    tooltip: tr('Quay lại'),
                                    onTap: () =>
                                        Navigator.of(context).maybePop(),
                                  ),
                                  const Spacer(),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: [
                                      _StatChip(
                                          emoji: '🪙',
                                          label: student.coinDisplay),
                                      _StatChip(
                                          emoji: '💎',
                                          label: student.gemDisplay),
                                      _StatChip(
                                          emoji: '🌾',
                                          label:
                                              '${student.farmPlotsUnlocked}/$kFarmMaxPlots'),
                                    ],
                                  ),
                                  const Spacer(),
                                  _RoundIconButton(
                                    icon: Icons.storefront,
                                    tooltip: tr('Cửa hàng Nông trại'),
                                    onTap: () => _openSeedShop(null),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                'Bấm ô đất trống để trồng cây, bấm cây đang lớn để tưới/bón '
                'phân. Quên tưới quá 12 giờ cây sẽ héo rồi chết!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionedAt({
    required Offset center,
    required double widthFrac,
    required double heightFrac,
    required Size stackSize,
    required Widget child,
  }) {
    final w = widthFrac * stackSize.width;
    final h = heightFrac * stackSize.height;
    return Positioned(
      left: center.dx * stackSize.width - w / 2,
      top: center.dy * stackSize.height - h / 2,
      width: w,
      height: h,
      child: child,
    );
  }
}

/// Lớp phủ hiển thị trên từng ô đất (khoá/trống/đang lớn/chín/chết) — vẽ
/// TRONG SUỐT, không che ảnh nền viên gạch đất đẹp sẵn có, chỉ thêm icon
/// trạng thái + thanh Nước mini ở giữa ô.
class _PlotOverlay extends StatelessWidget {
  final bool locked;
  final int? unlockCost;
  final FarmPlotState? plot;
  final DateTime now;
  final VoidCallback onTap;

  const _PlotOverlay({
    required this.locked,
    required this.unlockCost,
    required this.plot,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (locked) {
      content = Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, color: Colors.white, size: 16),
            if (unlockCost != null)
              Text('$unlockCost🪙',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
          ],
        ),
      );
    } else if (plot == null) {
      content = const SizedBox.shrink();
    } else {
      final p = plot!;
      final dead = p.isDead(now: now);
      final ready = !dead && p.isReady(now: now);
      final wilted = !dead && !ready && p.isWilted(now: now);
      content = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dead ? '💀' : p.stageEmoji(now: now),
            style: TextStyle(fontSize: ready ? 28 : 22),
          ),
          if (!dead && !ready) ...[
            const SizedBox(height: 2),
            SizedBox(
              width: 32,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: p.waterLevel(now: now) / 100,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.6),
                  color: wilted ? Colors.orange : Colors.blue,
                ),
              ),
            ),
          ],
          if (ready) const Text('✨', style: TextStyle(fontSize: 11)),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      // Bọc FittedBox: khi cửa sổ bị kéo hẹp/thấp, ô đất (kích thước theo
      // % chiều rộng/cao) có thể nhỏ hơn nội dung cố định (emoji, thanh
      // nước) — FittedBox tự thu nhỏ toàn bộ nội dung vừa khít thay vì
      // tràn viền (không phóng to quá cỡ gốc nhờ BoxFit.scaleDown).
      child: FittedBox(fit: BoxFit.scaleDown, child: content),
    );
  }
}

class _MiniLevelBar extends StatelessWidget {
  final String label;
  final double value; // 0-100
  final Color color;

  const _MiniLevelBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text('${value.round()}%', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _RoundIconButton(
      {required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _StatChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}

/// Cửa hàng riêng của Nông trại: mục "Hạt giống" (mua & trồng) và "Nội
/// thất" (chỗ trống chờ bổ sung vật phẩm trang trí sau).
class _SeedShopSheet extends StatefulWidget {
  final StudentModel student;
  final bool plantable; // true nếu mở từ việc bấm 1 ô đất trống cụ thể
  final void Function(CropTemplate) onPick;

  const _SeedShopSheet({
    required this.student,
    required this.plantable,
    required this.onPick,
  });

  @override
  State<_SeedShopSheet> createState() => _SeedShopSheetState();
}

class _SeedShopSheetState extends State<_SeedShopSheet> {
  int _tab = 0; // 0 = Hạt giống, 1 = Nội thất

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'Hạt giống 🌱',
                      selected: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: 'Nội thất 🛋️',
                      selected: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: _tab == 0
                    ? _buildSeedList(scrollController)
                    : _buildDecorPlaceholder(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeedList(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (!widget.plantable)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Bấm vào 1 ô đất trống trên nông trại rồi quay lại đây để trồng.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        const Text('🌸 Hoa — bán lấy Coin/Gem',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ...CropCatalog.flowers.map(_cropTile),
        const SizedBox(height: 12),
        const Text('🍇 Trái cây — cho pet ăn',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ...CropCatalog.fruits.map(_cropTile),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _cropTile(CropTemplate crop) {
    final canAfford = widget.student.hasEnoughCoin(crop.priceCoin);
    return Opacity(
      opacity: canAfford ? 1 : 0.4,
      child: ListTile(
        onTap: canAfford ? () => widget.onPick(crop) : null,
        leading: Text(crop.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(crop.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          crop.isFruit
              ? 'Lớn trong ${crop.growDurationLabel} • Hồi ${crop.hungerRestore} '
                  'No bụng, +${crop.expReward} EXP'
              : 'Lớn trong ${crop.growDurationLabel} • Bán '
                  '${crop.coinRewardMin}-${crop.coinRewardMax} 🪙'
                  '${crop.gemChance > 0 ? ' • ${(crop.gemChance * 100).round()}% có Gem' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Text('${crop.priceCoin} 🪙',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.secondary)),
      ),
    );
  }

  Widget _buildDecorPlaceholder(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      children: const [
        SizedBox(height: 40),
        Center(child: Text('🛋️', style: TextStyle(fontSize: 48))),
        SizedBox(height: 12),
        Center(
          child: Text(
            'Đồ trang trí cho Nông trại sẽ sớm được cập nhật!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? AppColors.primary : AppColors.textSecondary),
        ),
      ),
    );
  }
}
