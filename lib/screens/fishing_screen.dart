import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/fish_data.dart';
import '../models/pet_model.dart';
import '../models/pet_family_catalog.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/fish_illustration.dart';
import '../theme/app_theme.dart';
import 'fish_collection_screen.dart';

enum _FishState { idle, charging, waiting, biting, result, noEnergy }

/// Khi vừa quăng cần Perfect vừa dùng Mồi câu may mắn trong CÙNG 1 lượt,
/// cộng dồn thêm số lượt reroll này (ngoài phần đã cộng riêng lẻ từ lực
/// quăng cần và từ mồi câu) để độ hiếm cá tăng rõ rệt hơn hẳn so với chỉ
/// dùng 1 trong 2.
const int kPerfectBaitComboExtraRerolls = 2;

/// Mini game Câu cá bản NÂNG CẤP LỚN, lấy cảm hứng từ Fisch / Câu cá vạn
/// cân:
/// 1) QUĂNG CẦN CÓ LỰC — giữ nút để tích lực (thanh lực dao động lên
///    xuống liên tục), thả đúng lúc lực cao để tăng cơ hội gặp cá hiếm.
/// 2) GIẬT CẦN kiểu Blox Fruits — cá di chuyển loạn xạ trên 1 thanh ngang,
///    giữ để kéo thanh trắng của mình đuổi theo, thả để nó rơi do "trọng
///    lực". Trùng vị trí cá thì thanh "câu được" tăng, lệch thì giảm — đầy
///    100% thì bắt được, về 0% thì cá sẩy.
/// 3) CÂN NẶNG NGẪU NHIÊN + SỔ KỶ LỤC — mỗi con cá câu được có 1 cân nặng
///    (kg) ngẫu nhiên riêng; con nặng nhất từng câu của mỗi loài được lưu
///    lại làm kỷ lục.
/// 4) CẦN CÂU / MỒI CÂU nâng cấp mua bằng Coin/Gem — cần cao cấp hơn thì
///    may mắn hơn (dễ ra cá hiếm), thanh giật cần rộng hơn (dễ bắt hơn),
///    tốn ít Năng lượng hơn; mồi câu tự dùng mỗi lượt để cộng thêm may mắn.
/// Mỗi loài câu được lần đầu được lưu vĩnh viễn vào Bộ sưu tập cá.
/// 1 con cá đã câu được và đang đứng yên trên cảnh (vùng số 5).
class _SceneFishEntry {
  final FishSpecies fish;
  final double? weightKg; // null nếu là rác câu được (isJunk)
  // null = cá bình thường (kích thước theo công thức baseSize cố định).
  // khác null = cá KHỔNG LỒ — kích thước = tỉ lệ này x chiều ngang bờ,
  // không giới hạn trên (xem [_buildSceneFishEntry]).
  final double? giantSizeFrac;
  const _SceneFishEntry(this.fish, this.weightKg, [this.giantSizeFrac]);
}

class FishingScreen extends StatefulWidget {
  const FishingScreen({super.key});

  @override
  State<FishingScreen> createState() => _FishingScreenState();
}

class _FishingScreenState extends State<FishingScreen>
    with TickerProviderStateMixin {
  final _firestoreService = FirestoreService();

  late final AnimationController _bobberController;
  late final AnimationController _waveController;
  late final AnimationController _rippleController;
  late final AnimationController _chargeController; // lực quăng cần (0..1)
  late final AnimationController _shakeController; // rung màn hình
  late final AnimationController _confettiController; // pháo hoa ăn mừng
  late final AnimationController
      _auraController; // luồng ánh sáng xoay quanh cá khi câu được
  Timer? _biteTimer;

  // ---------- Mini game giật cần (kiểu Blox Fruits) ----------
  Ticker? _reelTicker;
  Duration _lastTick = Duration.zero;
  Timer? _fishRetargetTimer;
  double _fishPos = 0.5; // vị trí hiện tại của cá trên thanh (0..1)
  double _fishTarget = 0.5; // điểm cá đang "lao" tới
  double _fishSpeed = 0.7; // tốc độ cá di chuyển (đơn vị/giây)
  double _markerPos = 0.5; // tâm thanh trắng người chơi điều khiển (0..1)
  double _markerHalfSize = 0.10; // nửa độ rộng thanh trắng — nhỏ hơn = khó hơn
  double _catchProgress = 0.35; // % câu được (0..1) — đầy 1.0 thì thắng
  double _fillRate = 0.45; // tốc độ tăng progress mỗi giây khi trúng cá
  double _drainRate = 0.30; // tốc độ giảm progress mỗi giây khi lệch cá
  bool _holding = false; // đang giữ để kéo thanh lên hay không
  // Góc quay (radian) của nút cuộn cáp — cá kéo dây ra thì quay ngược chiều
  // kim đồng hồ (nhanh), giữ nút để kéo cá vào thì quay thuận chiều kim
  // đồng hồ (chậm hơn). Tích luỹ liên tục trong [_onReelTick] để không bị
  // giật khi đổi chiều.
  double _reelKnobAngle = 0;

  double _castPower = 0.5; // lực quăng cần đã chốt (0..1)
  double _backTiltAtRelease = 0; // góc nghiêng ra sau (radian) tại lúc thả tay
  bool _perfectRelease = false; // vừa thả tay đúng lúc lực đạt ~100%
  bool _usedBaitThisCast = false;
  bool _isGiantCatch = false; // lượt câu này có trúng cá "khổng lồ" không
  List<_ConfettiParticle> _confettiParticles = [];

  _FishState _state = _FishState.idle;
  FishSpecies? _pendingFish; // cá đã "cắn câu", chờ giật đúng lúc
  FishSpecies? _caughtFish;
  double? _caughtWeightKg;
  // Toàn bộ cá đã câu được trong phiên chơi này -> hiển thị CÙNG LÚC trên
  // cảnh (vùng số 5), mỗi con 1 vị trí riêng, KHÔNG bị con câu sau ghi đè.
  // Chỉ con câu MỚI NHẤT mới có hào quang phát sáng (khi đang ở đúng màn
  // kết quả của lượt vừa câu nó).
  final List<_SceneFishEntry> _sceneFishes = [];

  /// Các vị trí (tỉ lệ 0..1) rải trong vùng số 5 để xếp nhiều con cá cạnh
  /// nhau mà không đè lên nhau — hết slot thì các lượt câu tiếp theo vòng
  /// lại từ đầu (con mới luôn được vẽ đè lên trên con cũ ở cùng vị trí).
  static const List<Offset> _sceneFishSlots = [
    Offset(0.46, 0.90),
    Offset(0.60, 0.80),
    Offset(0.74, 0.90),
    Offset(0.62, 0.97),
    Offset(0.86, 0.83),
    Offset(0.90, 0.96),
    Offset(0.52, 0.99),
    Offset(0.80, 0.98),
    Offset(0.68, 0.85),
    Offset(0.95, 0.90),
  ];
  int _caughtCoinReward = 0;
  int _caughtGemReward = 0;
  bool _isPerfect = false;
  bool _isComboBonus = false; // Perfect + Mồi may mắn cùng lúc -> cộng dồn
  int _rewardMultiplier =
      1; // x1 thường, x2 khi có 1 hiệu ứng, x3 khi cộng dồn cả 2
  bool _isNewRecord = false;
  bool _escaped = false;
  bool _isNewDiscovery = false;
  String _biteHint = '';

  int _sessionCoin = 0;
  int _sessionGem = 0;
  int _sessionCatches = 0;

  // ---------- Bối cảnh bờ hồ thật + pet cầm cần đi lại ----------
  // Mọi toạ độ dưới đây là TỈ LỆ (0..1) trong ảnh nền gốc
  // assets/images/fishing/pond_bg.png (kích thước gốc 1672x941), khớp
  // đúng 5 vùng học sinh đã khoanh: (1) vùng nước cá xuất hiện — xem
  // [_shoreline]/[_shoreBoundaryX], (2) điểm neo pet đứng câu —
  // [_petAnchorFrac], (3) dải cát pet đi lại — [_randomSandSpot], (4) nút
  // quăng/kéo cần — [_castButtonFrac], (5) chỗ đặt cá câu được — dùng
  // trong [_buildSceneFishEntry].
  static const double _bgImgW = 1672;
  static const double _bgImgH = 941;
  static const Offset _petAnchorFrac = Offset(0.68, 0.60);
  static const Offset _castButtonFrac = Offset(0.90, 0.79);
  static const double _petSpriteSize = 84;
  // Nghiêng người RA SAU tối đa khi tích lực (như kéo cung), rồi vung MẠNH
  // RA TRƯỚC (về phía mặt nước) khi thả tay ném cần đi.
  static const double _maxBackTiltRad = pi / 6; // 30 độ ra sau
  static const double _maxForwardTiltRad = pi / 3; // 60 độ ra trước

  /// Đường ranh giới cát/nước đo trực tiếp từ ảnh nền thật (quét màu từng
  /// hàng pixel) — với mỗi độ cao [y] (tỉ lệ 0..1), trả về ranh giới x
  /// (tỉ lệ 0..1): bên TRÁI của x này là NƯỚC, bên PHẢI là CÁT.
  static const List<Offset> _shoreline = [
    Offset(0.17, 0.87),
    Offset(0.20, 0.85),
    Offset(0.30, 0.83),
    Offset(0.40, 0.80),
    Offset(0.45, 0.785),
    Offset(0.50, 0.681),
    Offset(0.55, 0.613),
    Offset(0.60, 0.566),
    Offset(0.65, 0.527),
    Offset(0.70, 0.490),
    Offset(0.75, 0.459),
    Offset(0.80, 0.428),
    Offset(0.85, 0.399),
    Offset(0.90, 0.374),
    Offset(0.95, 0.353),
    Offset(1.00, 0.329),
  ];

  double _shoreBoundaryX(double y) {
    final points = _shoreline;
    if (y <= points.first.dx) return points.first.dy;
    if (y >= points.last.dx) return points.last.dy;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (y >= a.dx && y <= b.dx) {
        final t = (y - a.dx) / (b.dx - a.dx);
        return a.dy + (b.dy - a.dy) * t;
      }
    }
    return points.last.dy;
  }

  Offset _petPos = _petAnchorFrac; // vị trí hiện tại của pet (tỉ lệ 0..1)
  Offset _petWalkFrom = _petAnchorFrac;
  Offset _petWalkTo = _petAnchorFrac;
  bool _petFacingRight = false; // false = quay trái = hướng ra mặt nước
  Timer? _petWanderTimer;
  Offset _bobberFrac = const Offset(0.42, 0.5); // vị trí phao câu (vùng nước)
  late final AnimationController _petWalkController;
  late final AnimationController
      _castFollowController; // trớn thân sau khi thả cần, từ nghiêng -> thẳng

  @override
  void initState() {
    super.initState();
    _bobberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _chargeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _petWalkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _castFollowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..value = 1;
    _restartPetWander();
  }

  @override
  void dispose() {
    _biteTimer?.cancel();
    _fishRetargetTimer?.cancel();
    _petWanderTimer?.cancel();
    _reelTicker?.dispose();
    _bobberController.dispose();
    _waveController.dispose();
    _rippleController.dispose();
    _chargeController.dispose();
    _shakeController.dispose();
    _confettiController.dispose();
    _auraController.dispose();
    _petWalkController.dispose();
    _castFollowController.dispose();
    super.dispose();
  }

  RodTier get _rodTier => kRodTiers[context
          .read<AuthProvider>()
          .currentStudent
          ?.fishingRodTier
          .clamp(0, kRodTiers.length - 1) ??
      0];

  // Việc random cá cắn câu giờ dùng [pickFishByRarity] (lib/models/fish_data.dart)
  // — random ĐỘ HIẾM trước theo % cố định (đúng yêu cầu cân bằng), rồi mới
  // random loài cụ thể trong đúng độ hiếm đó.

  // ---------- Pet đi tới đi lui trong vùng cát khi đang rảnh ----------

  /// Chọn 1 điểm ngẫu nhiên NẰM TRÊN CÁT (bên phải đường bờ [_shoreBoundaryX])
  /// để pet đi dạo qua lại khi không có ai đang câu.
  Offset _randomSandSpot() {
    final random = Random();
    final y = 0.55 + random.nextDouble() * 0.34;
    final leftBound = (_shoreBoundaryX(y) + 0.06).clamp(0.0, 0.9);
    const rightBound = 0.94;
    final span = max(0.04, rightBound - leftBound);
    final x = leftBound + random.nextDouble() * span;
    return Offset(x, y);
  }

  void _restartPetWander() {
    _petWanderTimer?.cancel();
    _petWanderTimer =
        Timer(Duration(seconds: 4 + Random().nextInt(4)), _tryPetWander);
  }

  /// Chỉ đi dạo khi đang KHÔNG câu (idle) — nếu đang bận thì tự dời lại,
  /// tự động thử lại sau nên không cần gọi lại thủ công ở nơi khác.
  void _tryPetWander() {
    if (!mounted) return;
    if (_state != _FishState.idle) {
      _restartPetWander();
      return;
    }
    final target = _randomSandSpot();
    setState(() {
      _petWalkFrom = _petPos;
      _petWalkTo = target;
      // Ảnh gốc pet quay mặt sang TRÁI mặc định (giống quy ước bên Nhà
      // pet) nên khi đi sang PHẢI (target.dx lớn hơn) mới cần lật ảnh.
      _petFacingRight = target.dx >= _petPos.dx;
    });
    _petWalkController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() => _petPos = _petWalkTo);
      _restartPetWander();
    });
  }

  /// Vị trí hiện tại của pet (tỉ lệ 0..1), có nội suy mượt khi đang đi bộ.
  Offset _currentPetFrac() {
    if (_petWalkController.isAnimating) {
      final t = Curves.easeInOut.transform(_petWalkController.value);
      return Offset.lerp(_petWalkFrom, _petWalkTo, t)!;
    }
    return _petPos;
  }

  /// Chọn 1 điểm phao câu ngẫu nhiên trong đúng vùng nước (vùng số 1) mỗi
  /// lượt quăng cần, để cá "xuất hiện" rải khắp cả mặt hồ chứ không cố định
  /// 1 chỗ.
  Offset _pickBobberSpot() {
    final random = Random();
    final y = 0.36 + random.nextDouble() * 0.34;
    final boundary = _shoreBoundaryX(y);
    final maxX = (boundary - 0.05).clamp(0.06, 0.9);
    final minX = (boundary - 0.36).clamp(0.04, maxX);
    final x = minX + random.nextDouble() * max(0.02, maxX - minX);
    return Offset(x, y);
  }

  // ---------- Quăng cần có lực ----------

  void _startCharging() {
    if (_state != _FishState.idle) return;
    _petWalkController.stop(); // dừng đi dạo dở nếu có
    setState(() {
      _state = _FishState.charging;
      // Pet quay ngay về đúng điểm neo câu cá và quay mặt ra phía mặt
      // nước trước khi bắt đầu tích lực quăng cần.
      _petPos = _petAnchorFrac;
      _petWalkFrom = _petAnchorFrac;
      _petWalkTo = _petAnchorFrac;
      _petFacingRight = false;
    });
    HapticFeedback.selectionClick();
    _perfectRelease = false; // reset cho lượt quăng cần mới
    _chargeController
      ..reset()
      ..repeat(reverse: true);
  }

  void _releaseCharge() {
    if (_state != _FishState.charging) return;
    final power = _chargeController.value;
    // Thả tay đúng lúc lực gần chạm đỉnh 100% -> tính là "Perfect" (khó vì
    // thanh lực dao động liên tục, đòi hỏi canh đúng thời điểm).
    _perfectRelease = power >= 0.97;
    _chargeController.stop();
    _backTiltAtRelease = -_maxBackTiltRad * power; // điểm bắt đầu vung cần
    _castFollowController.forward(from: 0); // vung cần ra trước rồi thẳng lại
    if (_perfectRelease) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    _cast(power);
  }

  Future<void> _cast(double power) async {
    final petProvider = context.read<PetProvider>();
    final pet = petProvider.pet;
    final energyCost = _rodTier.energyCost;
    if (pet == null || pet.energy < energyCost) {
      setState(() => _state = _FishState.noEnergy);
      return;
    }

    await _firestoreService.adjustPetEnergy(pet.id, -energyCost);

    setState(() {
      _state = _FishState.waiting;
      _castPower = power;
      _escaped = false;
      _caughtFish = null;
      _isNewDiscovery = false;
      _usedBaitThisCast = false;
      _isGiantCatch = false;
      _bobberFrac = _pickBobberSpot();
    });
    _rippleController.repeat();
    HapticFeedback.selectionClick();

    final random = Random();
    // Quăng càng mạnh, dây câu càng xa -> chờ cá cắn câu lâu hơn 1 chút,
    // nhưng đổi lại vẫn có thêm reroll để ra loài "xịn" hơn TRONG ĐÚNG độ
    // hiếm đã random được (xem [pickFishByRarity]) — không làm lệch %
    // tổng theo độ hiếm đã cố định.
    final waitMs = 1000 + (power * 900).round() + random.nextInt(2200);
    _biteTimer?.cancel();
    _biteTimer = Timer(Duration(milliseconds: waitMs), _onBite);
  }

  void _onBite() {
    if (!mounted || _state != _FishState.waiting) return;
    final random = Random();
    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent;
    final rodTier = _rodTier;

    // Tổng lượt "may mắn": lực quăng cần + cấp cần câu + mồi câu (nếu có).
    var extraRerolls = (_castPower * 2).round() + rodTier.extraRerolls;
    final hasBait = (student?.baitCharges ?? 0) > 0;
    if (hasBait) {
      extraRerolls += kBaitExtraRerolls;
      _usedBaitThisCast = true;
      _firestoreService.consumeFishingBait(student!.uid);
      auth.currentStudent =
          student.copyWith(baitCharges: student.baitCharges - 1);
      auth.notifyListeners();
    }
    // Cộng dồn: quăng cần Perfect + có dùng Mồi câu may mắn trong cùng 1
    // lượt thì được thưởng thêm reroll, thay vì chỉ cộng riêng lẻ từng cái.
    if (_perfectRelease && hasBait) {
      extraRerolls += kPerfectBaitComboExtraRerolls;
    }

    // Chọn TRƯỚC con cá sẽ cắn câu — random ĐỘ HIẾM theo đúng % cố định
    // (bảng khác nhau tùy có dùng Mồi câu may mắn hay không), sau đó mới
    // random loài cụ thể trong đúng độ hiếm đó (xem [pickFishByRarity]).
    // Độ hiếm của loài chọn được quyết định độ khó của mini game giật cần
    // (cá càng hiếm, di chuyển càng nhanh/loạn, thanh kéo của người chơi
    // càng nhỏ) và câu gợi ý kịch tính hiển thị cho học sinh (không lộ
    // chính xác là cá gì).
    final rates = hasBait ? kLuckyRarityRates : kNormalRarityRates;
    final fish = pickFishByRarity(random, rates, extraRerolls: extraRerolls);
    final rarityRatio = fish.weight / kMaxFishWeight; // 1.0 = phổ biến nhất

    String hint;
    if (rarityRatio >= 0.7) {
      hint = 'Có cá cắn câu! Giật ngay!';
    } else if (rarityRatio >= 0.35) {
      hint = 'Cắn khá mạnh đấy... chuẩn bị giật!';
    } else {
      hint = '‼️ CÓ GÌ ĐÓ RẤT LỚN ĐANG CẮN CÂU!!!';
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _pendingFish = fish;
      _biteHint = hint;
      _state = _FishState.biting;
    });
    _startReelGame(rarityRatio, rodTier.markerSizeBonus);
  }

  /// Cấu hình độ khó và bắt đầu mini game giật cần kiểu Blox Fruits: cá
  /// càng hiếm (rarityRatio càng nhỏ) thì di chuyển càng nhanh/đổi hướng
  /// càng dồn dập, thanh kéo của người chơi càng nhỏ (được cần câu bù lại
  /// 1 phần qua [markerBonus]), và càng dễ tuột mất tiến trình khi bị lệch.
  void _startReelGame(double rarityRatio, double markerBonus) {
    _markerHalfSize =
        ((0.075 + rarityRatio * 0.085) + markerBonus).clamp(0.075, 0.2);
    _fishSpeed = 0.35 + (1 - rarityRatio) * 0.85;
    _fillRate = 0.65 - (1 - rarityRatio) * 0.15;
    _drainRate = 0.15 + (1 - rarityRatio) * 0.18;
    _fishPos = 0.5;
    _markerPos = 0.5;
    _catchProgress = 0.45;
    _holding = false;
    _pickNewFishTarget();
    _scheduleFishRetarget(rarityRatio);

    _lastTick = Duration.zero;
    _reelTicker?.dispose();
    _reelTicker = createTicker(_onReelTick)..start();
  }

  void _pickNewFishTarget() {
    final random = Random();
    _fishTarget = 0.08 + random.nextDouble() * 0.84;
  }

  /// Cá thỉnh thoảng "lao" tới 1 điểm mới ngẫu nhiên trên thanh — cá càng
  /// hiếm thì đổi hướng càng thường xuyên (loạn xạ hơn, khó đoán hơn).
  void _scheduleFishRetarget(double rarityRatio) {
    final random = Random();
    final minMs = (400 + rarityRatio * 300).round();
    final maxMs = (750 + rarityRatio * 550).round();
    final delay = minMs + random.nextInt(max(1, maxMs - minMs));
    _fishRetargetTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _state != _FishState.biting) return;
      _pickNewFishTarget();
      _scheduleFishRetarget(rarityRatio);
    });
  }

  /// Vòng lặp chính của mini game — chạy mỗi khung hình (~60 lần/giây).
  void _onReelTick(Duration elapsed) {
    if (_state != _FishState.biting) return;
    final dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.2) return; // bỏ qua khung hình đầu tiên/giật lag

    setState(() {
      // 1) Cá di chuyển dần tới điểm đích hiện tại.
      final toTarget = _fishTarget - _fishPos;
      final maxStep = _fishSpeed * dt;
      _fishPos +=
          toTarget.abs() <= maxStep ? toTarget : maxStep * toTarget.sign;

      // 2) Thanh trắng của người chơi: giữ thì kéo lên, thả thì rơi xuống.
      const riseSpeed = 1.0; // đơn vị/giây khi giữ
      const fallSpeed = 0.6; // đơn vị/giây khi thả (trọng lực)
      _markerPos += (_holding ? riseSpeed : -fallSpeed) * dt;
      _markerPos = _markerPos.clamp(_markerHalfSize, 1 - _markerHalfSize);

      // 3) Trùng vị trí cá thì tăng tiến trình câu được, lệch thì giảm.
      final overlapping = (_fishPos - _markerPos).abs() <= _markerHalfSize;
      _catchProgress += (overlapping ? _fillRate : -_drainRate) * dt;
      _catchProgress = _catchProgress.clamp(0.0, 1.0);

      // 4) Nút cuộn cáp quay theo: giữ nút để kéo cá vào -> quay THUẬN
      // chiều kim đồng hồ, tốc độ CHẬM; thả ra để cá kéo dây đi -> quay
      // NGƯỢC chiều kim đồng hồ, tốc độ NHANH hơn hẳn.
      const reelInSpeed = 2.4; // rad/giây khi giữ để kéo cá vào (chậm)
      const reelOutSpeed = 6.5; // rad/giây khi cá đang kéo dây ra (nhanh)
      _reelKnobAngle += (_holding ? reelInSpeed : -reelOutSpeed) * dt;
    });

    if (_catchProgress >= 1.0) {
      _resolveReel(success: true);
    } else if (_catchProgress <= 0.0) {
      _resolveReel(success: false);
    }
  }

  void _stopReelGame() {
    _reelTicker?.stop();
    _fishRetargetTimer?.cancel();
  }

  Future<void> _resolveReel({required bool success}) async {
    _stopReelGame();
    _rippleController.stop();
    final fish = _pendingFish;

    if (!success || fish == null) {
      HapticFeedback.lightImpact();
      setState(() {
        _state = _FishState.result;
        _escaped = true;
        _caughtFish = null;
        _caughtWeightKg = null;
        _caughtCoinReward = 0;
        _caughtGemReward = 0;
        _isPerfect = false;
        _isComboBonus = false;
        _rewardMultiplier = 1;
        _isNewRecord = false;
        _isGiantCatch = false;
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent;
    bool isNew = false;
    bool isNewRecord = false;

    // Thưởng CỘNG DỒN theo số hiệu ứng đang có: (a) thả tay đúng lúc lực
    // quăng cần đạt 100% ("Perfect") cộng thêm x1, (b) có dùng Mồi câu may
    // mắn cho lượt này cộng thêm x1 nữa — có cả 2 cùng lúc thì cộng dồn
    // thành x3 thay vì chỉ x2 như dùng riêng lẻ 1 cái. Nhãn "PERFECT!" chỉ
    // hiện khi (a) xảy ra; nếu chỉ nhờ mồi câu thì thưởng vẫn tăng nhưng
    // ÂM THẦM, không có thông báo (để không nhầm với thành tích tự tay
    // canh đúng lực).
    final showPerfectBadge = _perfectRelease;
    final isComboBonus = _perfectRelease && _usedBaitThisCast;
    final rewardMultiplier =
        1 + (_perfectRelease ? 1 : 0) + (_usedBaitThisCast ? 1 : 0);
    final coinReward = fish.coin * rewardMultiplier;
    final gemReward = fish.gem * rewardMultiplier;

    // Cân nặng ngẫu nhiên riêng cho lần câu này. Phần lớn nằm trong khoảng
    // bình thường của loài (thỉnh thoảng "trúng số" gần mức tối đa kiểu "cá
    // kỷ lục"), nhưng có 1 tỉ lệ nhỏ trúng "CÁ KHỔNG LỒ": vượt XA mức tối đa
    // bình thường, kích thước hiển thị (xem [_buildSceneFishEntry]) trung
    // bình to bằng khoảng nửa chiều ngang bờ và KHÔNG GIỚI HẠN trên (siêu
    // hiếm có thể to hơn cả chiều ngang bờ) — hệ số tăng theo kg cũng cao
    // hơn hẳn cá bình thường.
    final random = Random();
    final (minKg, maxKg) = fishWeightRangeKg(fish);
    final isGiant = !fish.isJunk && random.nextDouble() < 0.06;
    double weightKg;
    double? giantSizeFrac;
    if (isGiant) {
      // Phân phối lệch: đa số quanh mức "nửa bờ" (~0.3-0.9), thỉnh thoảng
      // vượt hẳn ra ngoài (>1.0 = to hơn cả bờ). ~10% số cá khổng lồ còn
      // được cộng thêm 1 lượt "siêu khổng lồ" (đuôi phân phối không giới
      // hạn) để đúng nghĩa "không giới hạn trên".
      final severity = random.nextDouble();
      giantSizeFrac = 0.30 + pow(severity, 1.8) * 0.9;
      if (random.nextDouble() < 0.10) {
        giantSizeFrac +=
            -log(1 - random.nextDouble().clamp(0.0, 0.999)) * 0.8;
      }
      // Hệ số tăng kg cao hơn hẳn cá thường — càng "khổng lồ" thì kg càng
      // vọt xa mức tối đa bình thường của loài.
      weightKg = maxKg * (2.0 + giantSizeFrac * 6.0);
    } else {
      final isTrophyRoll = !fish.isJunk && random.nextDouble() < 0.08;
      weightKg = isTrophyRoll
          ? maxKg - random.nextDouble() * (maxKg - minKg) * 0.15
          : minKg + random.nextDouble() * (maxKg - minKg);
    }

    if (student != null) {
      isNew = !student.unlockedFish.contains(fish.id);
      if (coinReward > 0 || gemReward > 0) {
        await _firestoreService.claimMiniGameRewardWithGem(
          student.uid,
          coinAmount: coinReward,
          gemAmount: gemReward,
        );
      }
      if (isNew) {
        await _firestoreService.unlockFish(student.uid, fish.id);
      }
      Map<String, double> newRecords = student.fishRecords;
      if (!fish.isJunk) {
        final prevRecord = student.fishRecords[fish.id] ?? 0;
        isNewRecord = weightKg > prevRecord;
        if (isNewRecord) {
          await _firestoreService.updateFishRecord(
              student.uid, fish.id, weightKg);
          newRecords = {...student.fishRecords, fish.id: weightKg};
        }
      }
      auth.currentStudent = student.copyWith(
        coin: student.coin + coinReward,
        gem: student.gem + gemReward,
        unlockedFish:
            isNew ? [...student.unlockedFish, fish.id] : student.unlockedFish,
        fishRecords: newRecords,
      );
      auth.notifyListeners();
      if (isNew) {
        // Sưu tầm được loài cá MỚI có thể vừa đạt mốc thành tựu (5/15 loài
        // cá) — refresh để AuthProvider tự kiểm tra & mở khoá nếu đủ.
        await auth.refreshCurrentStudent();
      }
    }

    HapticFeedback.heavyImpact();
    _sessionCoin += coinReward;
    _sessionGem += gemReward;
    if (!fish.isJunk) _sessionCatches++;

    final rarityRatio = fish.weight / kMaxFishWeight;
    final isRareCatch = showPerfectBadge ||
        (!fish.isJunk && (rarityRatio < 0.35 || isNewRecord));

    setState(() {
      _state = _FishState.result;
      _escaped = false;
      _caughtFish = fish;
      _caughtWeightKg = fish.isJunk ? null : weightKg;
      _isGiantCatch = isGiant;
      _sceneFishes.add(_SceneFishEntry(
          fish, fish.isJunk ? null : weightKg, giantSizeFrac));
      _caughtCoinReward = coinReward;
      _caughtGemReward = gemReward;
      _isPerfect = showPerfectBadge;
      _isComboBonus = isComboBonus;
      _rewardMultiplier = rewardMultiplier;
      _isNewRecord = isNewRecord;
      _isNewDiscovery = isNew && !fish.isJunk;
    });

    if (isRareCatch || isGiant) {
      _triggerCelebration();
    }
  }

  /// Rung nhẹ màn hình + bắn pháo hoa emoji khi câu được cá hiếm/kỷ lục.
  void _triggerCelebration() {
    final random = Random();
    _confettiParticles = List.generate(18, (i) {
      return _ConfettiParticle(
        emoji: const ['🎉', '✨', '⭐', '🎊'][random.nextInt(4)],
        angle: random.nextDouble() * 2 * pi,
        distance: 60 + random.nextDouble() * 90,
        size: 16 + random.nextDouble() * 14,
        delay: random.nextDouble() * 0.25,
      );
    });
    _shakeController.forward(from: 0);
    _confettiController.forward(from: 0);
  }

  /// Số luồng ánh sáng của hào quang — cá càng hiếm càng nhiều luồng sáng
  /// (rực rỡ hơn), nhưng RÁC vẫn có hào quang riêng (màu bạc xám, xem
  /// [rarityAuraColor]) theo đúng yêu cầu, không chỉ cá quý mới có.
  int _auraRayCount(FishRarity rarity) => switch (rarity) {
        FishRarity.junk => 8,
        FishRarity.common => 8,
        FishRarity.uncommon => 10,
        FishRarity.rare => 12,
        FishRarity.superRare => 14,
        FishRarity.legendary => 18,
      };

  void _endSession() {
    Navigator.of(context).pop();
  }

  void _showGearShop() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FishingGearSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetProvider>().pet;
    final student = context.watch<AuthProvider>().currentStudent;
    final rodTier = kRodTiers[
        (student?.fishingRodTier ?? 0).clamp(0, kRodTiers.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Câu cá'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront_rounded),
            tooltip: tr('Cửa hàng câu cá'),
            onPressed: _showGearShop,
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: tr('Bộ sưu tập cá'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FishCollectionScreen()),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final shake = sin(_shakeController.value * pi * 8) *
              (1 - _shakeController.value) *
              8;
          return Transform.translate(offset: Offset(shake, 0), child: child);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            final bottomSafeInset = MediaQuery.of(context).padding.bottom;
            Offset mapFrac(Offset f) =>
                _mapFracToScreen(f, viewport, bottomSafeInset);
            return Stack(
              fit: StackFit.expand,
              children: [
                // Nền mở rộng phía trên dải ảnh — gradient hoà theo đúng tông
                // núi đồi trong ảnh gốc, để không bị hụt khoảng trống trần trụi.
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFBFDCD3), Color(0xFF6FA382)],
                    ),
                  ),
                ),
                // 1) Ảnh nền bờ hồ thật — hiển thị TRỌN VẸN theo đúng tỉ lệ
                // gốc, neo ở đáy màn hình (không dùng BoxFit.cover vì ảnh
                // ngang trong khi màn hình dọc sẽ cắt mất phần pet/nút bấm).
                Builder(builder: (context) {
                  final band = _pondBandRect(viewport, bottomSafeInset);
                  return Positioned(
                    left: band.left,
                    top: band.top,
                    width: band.width,
                    height: band.height,
                    child: Image.asset(
                      'assets/images/fishing/pond_bg.png',
                      fit: BoxFit.fill,
                    ),
                  );
                }),
                // 2) Sóng nước nổi lên quanh phao câu — mạnh hơn hẳn khi cá
                // đang giật cần (vùng số 1).
                if (_state == _FishState.waiting ||
                    _state == _FishState.biting)
                  _buildBobberWaterFx(mapFrac),
                // 3) Dây câu nối từ pet ra đúng vị trí phao.
                if (_state == _FishState.waiting ||
                    _state == _FishState.biting)
                  _buildFishingLine(mapFrac),
                // 4) Pet cầm cần câu, đi lại trong vùng cát / nghiêng người
                // khi quăng cần / run giật khi cá cắn câu (vùng số 2 & 3).
                _buildPetOnScene(pet, mapFrac),
                // 5) Toàn bộ cá đã câu được trong phiên, mỗi con đứng ở 1
                // chỗ riêng trong vùng số 5 — vẫn nằm đó qua các lượt câu
                // tiếp theo, chỉ con MỚI NHẤT mới có hào quang phát sáng.
                for (var i = 0; i < _sceneFishes.length; i++)
                  _buildSceneFishEntry(i, mapFrac),
                // 6) Bảng chỉ số + trạng thái nổi phía trên.
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _InfoChip(
                                emoji: '⚡', label: '${pet?.energy ?? 0}/100'),
                            _InfoChip(
                                emoji: rodTier.emoji, label: rodTier.name),
                            _InfoChip(
                                emoji: '🧪',
                                label: '${student?.baitCharges ?? 0}'),
                            _InfoChip(
                                emoji: '🎣', label: '$_sessionCatches cá'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Center(child: _buildStatusPanel()),
                      ),
                    ],
                  ),
                ),
                // 7) Nút quăng cần / kéo cần / câu tiếp — cố định ở vùng số 4.
                _buildCastButton(mapFrac),
                // Pháo hoa ăn mừng cá hiếm/kỷ lục.
                if (_confettiController.value > 0 ||
                    _confettiController.isAnimating)
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _confettiController,
                      builder: (context, _) => CustomPaint(
                        size: Size.infinite,
                        painter: _ConfettiPainter(
                            _confettiParticles, _confettiController.value),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Hình chữ nhật (pixel màn hình thật) mà ảnh nền chiếm — luôn giữ ĐÚNG
  /// tỉ lệ khung hình gốc (1672:941), neo ở ĐÁY màn hình, và luôn hiển thị
  /// TRỌN VẸN ảnh (không cắt xén như BoxFit.cover) để pet/nút bấm/khu đặt cá
  /// không bao giờ bị lọt ra ngoài vùng nhìn thấy trên màn hình dọc.
  Rect _pondBandRect(Size viewport, double bottomSafeInset) {
    const imgAspect = _bgImgW / _bgImgH;
    final usableHeight = viewport.height - bottomSafeInset - 12;
    double bandWidth = viewport.width;
    double bandHeight = bandWidth / imgAspect;
    if (bandHeight > usableHeight) {
      // Màn hình rất thấp (ví dụ máy tính bảng nằm ngang) -> đổi sang giới
      // hạn theo chiều cao để vẫn không bị cắt.
      bandHeight = usableHeight;
      bandWidth = bandHeight * imgAspect;
    }
    final left = (viewport.width - bandWidth) / 2;
    final top = usableHeight - bandHeight;
    return Rect.fromLTWH(left, top, bandWidth, bandHeight);
  }

  /// Quy đổi 1 toạ độ TỈ LỆ (0..1, theo ảnh nền gốc 1672x941) sang toạ độ
  /// PIXEL thật trên màn hình, dựa trên đúng dải ảnh [_pondBandRect] đang
  /// hiển thị — mọi vùng (pet, nút bấm, phao câu...) luôn khớp chính xác
  /// với ảnh nền dù màn hình thiết bị to nhỏ khác nhau.
  Offset _mapFracToScreen(Offset frac, Size viewport, double bottomSafeInset) {
    final band = _pondBandRect(viewport, bottomSafeInset);
    return Offset(
      band.left + frac.dx * band.width,
      band.top + frac.dy * band.height,
    );
  }

  /// Sóng nước lan tỏa quanh phao câu — lặp liên tục khi đang chờ/giật cần,
  /// mạnh hơn hẳn (bán kính + độ đậm) khi cá đang giật (biting).
  Widget _buildBobberWaterFx(Offset Function(Offset) mapFrac) {
    final bobberScreen = mapFrac(_bobberFrac);
    final strong = _state == _FishState.biting;
    return Positioned(
      left: bobberScreen.dx - 55,
      top: bobberScreen.dy - 55,
      width: 110,
      height: 110,
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _rippleController,
              builder: (context, _) => CustomPaint(
                painter: _RipplePainter(_rippleController.value,
                    strength: strong ? 1.6 : 1.0),
              ),
            ),
            AnimatedBuilder(
              animation: _bobberController,
              builder: (context, child) => Transform.translate(
                offset:
                    Offset(0, _bobberController.value * (strong ? 5 : 9)),
                child: child,
              ),
              child: const Text('🔴', style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
      ),
    );
  }

  /// Sợi dây câu nối từ tay pet (ước lượng) tới đúng vị trí phao trên mặt
  /// nước — dây căng ra khi cá đang giật (đường vẽ đậm/thẳng hơn 1 chút).
  Widget _buildFishingLine(Offset Function(Offset) mapFrac) {
    final petScreen = mapFrac(_currentPetFrac());
    final handPoint = petScreen + const Offset(6, -_petSpriteSize * 0.78);
    final bobberPoint = mapFrac(_bobberFrac);
    final taut = _state == _FishState.biting;
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SceneLinePainter(
            from: handPoint, to: bobberPoint, taut: taut),
      ),
    );
  }

  /// Pet cầm cần câu: đi tới đi lui trong vùng cát khi rảnh, quay mặt ra
  /// nước + nghiêng người tối đa 60 độ khi tích lực quăng cần, trớn người
  /// thẳng lại sau khi thả tay, và run giật khi đang giữ cần lúc cá cắn câu.
  Widget _buildPetOnScene(PetModel? pet, Offset Function(Offset) mapFrac) {
    if (pet == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge([
        _petWalkController,
        _chargeController,
        _castFollowController,
        _bobberController,
      ]),
      builder: (context, _) {
        final frac = _currentPetFrac();
        final screenPos = mapFrac(frac);

        double liftY = 0;
        if (_petWalkController.isAnimating) {
          liftY = sin(_petWalkController.value * pi * 6).abs() * 6;
        } else if (_state == _FishState.idle) {
          liftY = sin(_bobberController.value * pi) * 3;
        }

        // Nghiêng người RA SAU (như kéo cung) khi đang tích lực, rồi vung
        // MẠNH RA TRƯỚC về phía mặt nước lúc thả tay ném cần, sau đó thẳng
        // người lại. Dương = nghiêng ra trước (phía nước), âm = ra sau.
        double tilt = 0;
        if (_state == _FishState.charging) {
          tilt = -_maxBackTiltRad * _chargeController.value;
        } else if (_castFollowController.value < 1) {
          final t = _castFollowController.value;
          final forwardPeak = _maxForwardTiltRad * (0.55 + _castPower * 0.45);
          if (t < 0.35) {
            // Giai đoạn 1: vung nhanh từ tư thế ngả ra sau -> bật mạnh ra
            // trước (động tác ném cần).
            final localT = Curves.easeOutCubic.transform(t / 0.35);
            tilt = _backTiltAtRelease +
                (forwardPeak - _backTiltAtRelease) * localT;
          } else {
            // Giai đoạn 2: từ từ thẳng người lại sau khi ném xong.
            final localT = Curves.easeOutBack.transform((t - 0.35) / 0.65);
            tilt = forwardPeak * (1 - localT);
          }
        }

        // Run giật để giữ cho cá khỏi sổng khi đang giữ nút kéo cần.
        double jitterX = 0, jitterY = 0;
        if (_state == _FishState.biting) {
          final tSec = _lastTick.inMilliseconds / 1000.0;
          final freq = _holding ? 20.0 : 11.0;
          final amp = _holding ? 2.6 : 1.3;
          jitterX = sin(tSec * 2 * pi * freq) * amp;
          jitterY = cos(tSec * 2 * pi * freq * 1.3) * amp * 0.6;
        }

        final flip = _petFacingRight ? -1.0 : 1.0;

        return Positioned(
          left: screenPos.dx - _petSpriteSize / 2 + jitterX,
          top: screenPos.dy - _petSpriteSize + jitterY - liftY,
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()..rotateZ(-tilt),
            // Lật CẢ pet lẫn cần câu cùng lúc như 1 khối cứng -> cần luôn
            // dính đúng vào tay pet dù pet quay trái/phải.
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(flip, 1.0),
              child: SizedBox(
                width: _petSpriteSize,
                height: _petSpriteSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      pet.idleAsset,
                      width: _petSpriteSize,
                      height: _petSpriteSize,
                      fit: BoxFit.contain,
                    ),
                    // Cần câu to hơn, chĩa chéo lên từ tay/ngực pet — xoay
                    // quanh đúng điểm tay cầm (gốc cần) nên vung tự nhiên
                    // theo nhịp nghiêng người thay vì trôi nổi trên đầu.
                    Positioned(
                      left: _petSpriteSize * 0.30,
                      top: _petSpriteSize * 0.30,
                      child: Transform.rotate(
                        angle: -1.0 - tilt * 0.75,
                        alignment: Alignment.bottomLeft,
                        child: Text('🎣',
                            style: TextStyle(
                                fontSize: _petSpriteSize * 0.62)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Vẽ 1 con cá (theo [index] trong [_sceneFishes]) đứng ở đúng slot vị trí
  /// riêng của nó trong vùng số 5 — cân nặng câu được càng lớn (so với
  /// khoảng cân nặng của đúng loài đó) thì kích thước hiển thị càng to.
  /// Mọi con cá đã câu trong phiên đều ở lại trên cảnh cùng lúc, chỉ con
  /// MỚI NHẤT mới có hào quang phát sáng (và chỉ khi đang ở đúng màn kết
  /// quả của chính lượt câu ra nó).
  Widget _buildSceneFishEntry(int index, Offset Function(Offset) mapFrac) {
    final entry = _sceneFishes[index];
    final fish = entry.fish;
    final isLatest = index == _sceneFishes.length - 1;
    final showAura = isLatest && _state == _FishState.result && !_escaped;
    final slot = _sceneFishSlots[index % _sceneFishSlots.length];
    final screenPos = mapFrac(slot);
    final (minKg, maxKg) = fishWeightRangeKg(fish);
    final weightKg = entry.weightKg ?? minKg;
    final ratio = maxKg > minKg
        ? ((weightKg - minKg) / (maxKg - minKg)).clamp(0.0, 1.0)
        : 0.5;
    final baseSize = switch (fish.rarity) {
      FishRarity.junk => 26.0,
      FishRarity.common => 30.0,
      FishRarity.uncommon => 35.0,
      FishRarity.rare => 41.0,
      FishRarity.superRare => 49.0,
      FishRarity.legendary => 58.0,
    };
    double displaySize = baseSize + ratio * baseSize * 1.6;
    if (entry.giantSizeFrac != null) {
      // CÁ KHỔNG LỒ: kích thước = tỉ lệ x chiều ngang bờ đang hiển thị
      // (không phải theo baseSize cố định) -> không giới hạn trên, to hơn
      // hẳn cá thường, có thể vượt cả chiều ngang bờ ở tỉ lệ hiếm.
      final bandWidthPx =
          mapFrac(const Offset(1, 0)).dx - mapFrac(const Offset(0, 0)).dx;
      displaySize = max(displaySize, bandWidthPx * entry.giantSizeFrac!);
    }
    final auraSize = displaySize * 2.3;

    Widget fishVisual;
    if (showAura) {
      fishVisual = SizedBox(
        width: auraSize,
        height: auraSize,
        child: AnimatedBuilder(
          animation: _auraController,
          builder: (context, _) {
            final isFlashy = fish.rarity == FishRarity.superRare ||
                fish.rarity == FishRarity.legendary;
            final pulse = 1 +
                (isFlashy ? 0.09 : 0.04) *
                    sin(_auraController.value * 2 * pi * 2);
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: pulse,
                  child: CustomPaint(
                    size: Size(auraSize, auraSize),
                    painter: _AuraPainter(
                      progress: _auraController.value,
                      color: rarityAuraColor(fish.rarity),
                      rayCount: _auraRayCount(fish.rarity),
                    ),
                  ),
                ),
                FishIllustration(
                  shape: fish.shape,
                  color: fish.color,
                  size: displaySize,
                ),
              ],
            );
          },
        ),
      );
    } else {
      // Không phải con mới nhất (hoặc đã sang lượt câu khác) -> không còn
      // hào quang, chỉ còn cá đứng yên.
      fishVisual = SizedBox(
        width: auraSize,
        height: auraSize,
        child: Center(
          child: FishIllustration(
            shape: fish.shape,
            color: fish.color,
            size: displaySize,
          ),
        ),
      );
    }

    return Positioned(
      left: screenPos.dx - auraSize / 2,
      top: screenPos.dy - auraSize / 2,
      // Con mới nhất vẽ đè lên trên cùng, nếu trùng slot với con cũ.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isLatest
              ? TweenAnimationBuilder<double>(
                  key: ValueKey('${fish.id}_${weightKg.toStringAsFixed(2)}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.elasticOut,
                  builder: (context, t, child) =>
                      Transform.scale(scale: t.clamp(0.0, 1.3), child: child),
                  child: fishVisual,
                )
              : fishVisual,
          if (!fish.isJunk)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('⚖️ ${weightKg.toStringAsFixed(2)}kg',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  /// Nút tròn nổi cố định ở vùng số 4 — giữ để quăng cần / giữ để kéo cần /
  /// chạm để câu tiếp / chạm để kết thúc, tuỳ theo trạng thái hiện tại.
  Widget _buildCastButton(Offset Function(Offset) mapFrac) {
    final screenPos = mapFrac(_castButtonFrac);
    const size = 72.0;

    late final Color color;
    late final Widget inner;
    switch (_state) {
      case _FishState.idle:
        color = AppColors.primary;
        inner = const Text('🎣', style: TextStyle(fontSize: 28));
        break;
      case _FishState.charging:
        color = AppColors.danger;
        inner = const Text('🎣', style: TextStyle(fontSize: 28));
        break;
      case _FishState.waiting:
        color = Colors.grey;
        inner = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2.4, color: Colors.white),
        );
        break;
      case _FishState.biting:
        color = const Color(0xFF1C1D22); // nền tối kiểu tời cuộn cáp
        inner = SizedBox(
          width: size - 8,
          height: size - 8,
          child: CustomPaint(painter: _ReelWheelPainter(_reelKnobAngle)),
        );
        break;
      case _FishState.result:
        color = AppColors.success;
        inner =
            const Icon(Icons.refresh_rounded, color: Colors.white, size: 28);
        break;
      case _FishState.noEnergy:
        color = Colors.grey.shade600;
        inner =
            const Icon(Icons.close_rounded, color: Colors.white, size: 28);
        break;
    }

    final button = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: inner,
    );

    Widget positioned(Widget child) => Positioned(
          left: screenPos.dx - size / 2,
          top: screenPos.dy - size / 2,
          child: child,
        );

    switch (_state) {
      case _FishState.idle:
      case _FishState.charging:
        return positioned(Listener(
          onPointerDown: (_) => _startCharging(),
          onPointerUp: (_) => _releaseCharge(),
          onPointerCancel: (_) => _releaseCharge(),
          child: button,
        ));
      case _FishState.biting:
        return positioned(Listener(
          onPointerDown: (_) {
            _holding = true;
            HapticFeedback.selectionClick();
          },
          onPointerUp: (_) => _holding = false,
          onPointerCancel: (_) => _holding = false,
          child: button,
        ));
      case _FishState.result:
        return positioned(GestureDetector(
          onTap: () => setState(() => _state = _FishState.idle),
          child: button,
        ));
      case _FishState.noEnergy:
        return positioned(
            GestureDetector(onTap: _endSession, child: button));
      case _FishState.waiting:
        return positioned(button);
    }
  }

  /// Bảng nổi phía trên hiển thị hint/lực quăng cần/thanh giật cần/kết quả
  /// theo đúng trạng thái hiện tại — thay cho phần giữa màn hình trống
  /// trước đây (giờ giữa màn hình là cảnh bờ hồ thật + pet).
  Widget _buildStatusPanel() {
    Widget content;
    switch (_state) {
      case _FishState.idle:
        content = const Text('Nhấn giữ nút 🎣 để quăng cần!',
            style: TextStyle(color: Colors.white70, fontSize: 12));
        break;

      case _FishState.charging:
        content = AnimatedBuilder(
          animation: _chargeController,
          builder: (context, _) {
            final power = _chargeController.value;
            final color = Color.lerp(AppColors.info, AppColors.danger, power)!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 16,
                      child: Stack(
                        children: [
                          Container(
                              color: Colors.black.withValues(alpha: 0.25)),
                          FractionallySizedBox(
                            widthFactor: power,
                            child: Container(color: color),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  power >= 0.97
                      ? 'PERFECT! Thả ngay! 🌟'
                      : 'Lực quăng: ${(power * 100).round()}%',
                  style: TextStyle(
                      color: power >= 0.97 ? AppColors.gold : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            );
          },
        );
        break;

      case _FishState.waiting:
        content = const Text('Đang chờ cá cắn câu...',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13));
        break;

      case _FishState.biting:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_biteHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            if (_usedBaitThisCast) ...[
              const SizedBox(height: 3),
              const Text('🧪 Đã dùng Mồi câu may mắn!',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ],
            const SizedBox(height: 10),
            _buildReelBar(),
            const SizedBox(height: 10),
            _buildProgressBar(),
          ],
        );
        break;

      case _FishState.result:
        if (_escaped) {
          content = const Text('🐟💨 Cá đã sẩy mất rồi!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15));
          break;
        }
        final fish = _caughtFish!;
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isGiantCatch)
              _statusBadge('🐋 CÁ KHỔNG LỒ!!!', const Color(0xFFE85D2F)),
            if (_isNewDiscovery)
              _statusBadge('🆕 LOÀI MỚI! Đã thêm vào Bộ sưu tập', AppColors.gold),
            if (_isNewRecord) _statusBadge('🏆 KỶ LỤC MỚI!', AppColors.danger),
            if (_isPerfect && !fish.isJunk)
              _statusBadge(
                  _isComboBonus
                      ? '🌟🧪 PERFECT + MAY MẮN! Cộng dồn x$_rewardMultiplier'
                      : '🌟 PERFECT! Thưởng x$_rewardMultiplier',
                  AppColors.gold),
            Text(
              fish.isJunk
                  ? 'Bạn câu được... ${fish.name}! 😅'
                  : 'Câu được: ${fish.name}!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: rarityBackgroundColor(fish.rarity),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(rarityLabel(fish.rarity),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
            if (!fish.isJunk) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 10, alignment: WrapAlignment.center, children: [
                if (_caughtWeightKg != null)
                  Text('⚖️ ${_caughtWeightKg!.toStringAsFixed(2)}kg',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                if (_caughtCoinReward > 0)
                  Text('🪙 +$_caughtCoinReward',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                if (_caughtGemReward > 0)
                  Text('💎 +$_caughtGemReward',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            ],
          ],
        );
        break;

      case _FishState.noEnergy:
        content = const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('😴 Pet hết năng lượng để câu cá rồi!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            SizedBox(height: 4),
            Text('Cho pet ăn hoặc nghỉ ngơi để hồi Năng lượng nhé.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        );
        break;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
      ),
      child: content,
    );
  }

  Widget _statusBadge(String text, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.white)),
      );


  /// Thanh giật cần: 🐟 là cá đang di chuyển loạn xạ, khối trắng là phần
  /// người chơi điều khiển (giữ để kéo lên, thả để rơi xuống). Có 1 sợi
  /// dây câu vẽ nối từ đầu cần xuống đúng vị trí cá cho sinh động. Thuần
  /// hiển thị — thao tác giữ/thả nằm ở nút tròn nổi ([_buildCastButton]).
  Widget _buildReelBar() {
    const barWidth = 280.0;
    const barHeight = 26.0;
    return SizedBox(
      width: barWidth,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: const Size(barWidth, 70),
            painter: _FishingLinePainter(barWidth * _fishPos),
          ),
          Positioned(
            top: 44,
            left: 0,
            right: 0,
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
            ),
          ),
          Positioned(
            top: 44,
            left: (barWidth * (_markerPos - _markerHalfSize))
                .clamp(0.0, barWidth),
            width: (barWidth * _markerHalfSize * 2).clamp(0.0, barWidth),
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: (barWidth * _fishPos - 14).clamp(0.0, barWidth - 28),
            child: const Text('🐟', style: TextStyle(fontSize: 28)),
          ),
        ],
      ),
    );
  }

  /// Thanh "câu được bao nhiêu %" — đầy thì bắt được cá, cạn thì cá sẩy.
  Widget _buildProgressBar() {
    const barWidth = 220.0;
    final color =
        Color.lerp(AppColors.danger, AppColors.success, _catchProgress)!;
    return SizedBox(
      width: barWidth,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 16,
              child: Stack(
                children: [
                  Container(color: Colors.black.withValues(alpha: 0.25)),
                  FractionallySizedBox(
                    widthFactor: _catchProgress.clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('Câu được: ${(_catchProgress * 100).round()}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

}

/// Vẽ 2-3 vòng gợn sóng lan ra từ tâm rồi mờ dần — dùng khi thả cần và khi
/// cá cắn câu để tạo cảm giác "có gì đó động dưới nước".
class _RipplePainter extends CustomPainter {
  final double progress; // 0..1, lặp liên tục khi đang chờ/giật cần
  final double strength; // 1.0 bình thường, cao hơn khi cá đang giật mạnh
  _RipplePainter(this.progress, {this.strength = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 * (0.7 + strength * 0.3);
    for (int i = 0; i < 3; i++) {
      final t = (progress - i * 0.2).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final radius = maxRadius * t;
      final opacity = (1 - t) * 0.5 * strength.clamp(0.5, 1.6);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 0.8))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * strength.clamp(0.8, 1.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.strength != strength;
}

/// Vẽ 2 lớp sóng hình sin cuộn ngang liên tục ở đáy màn hình.
class _WavePainter extends CustomPainter {
  final double phase; // 0..1
  _WavePainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    _drawWave(
        canvas, size, phase, Colors.white.withValues(alpha: 0.08), 14, 0.75);
    _drawWave(canvas, size, phase + 0.3, Colors.white.withValues(alpha: 0.12),
        10, 0.85);
  }

  void _drawWave(Canvas canvas, Size size, double phaseOffset, Color color,
      double amplitude, double heightRatio) {
    final path = Path();
    final baseHeight = size.height * heightRatio;
    path.moveTo(0, baseHeight);
    for (double x = 0; x <= size.width; x += 8) {
      final y = baseHeight +
          sin((x / size.width * 2 * pi) + (phaseOffset * 2 * pi)) * amplitude;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.phase != phase;
}

/// Vẽ bánh cuộn cáp (tời câu) xoay tròn cho nút giữ/thả lúc cá cắn câu —
/// lấy cảm hứng từ nút "Giảm cáp" kiểu tời công nghiệp: các nan hoa toả ra
/// từ tâm + 1 điểm sáng đánh dấu để nhìn rõ chiều quay.
class _ReelWheelPainter extends CustomPainter {
  final double angle; // radian, tích luỹ liên tục từ [_onReelTick]
  _ReelWheelPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    canvas.save();
    canvas.translate(radius, radius);
    canvas.rotate(angle);

    // Vòng ngoài mờ + các nan hoa như bánh tời cáp.
    canvas.drawCircle(
      Offset.zero,
      radius * 0.92,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final spokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final a = i * (pi / 4);
      final inner = Offset(cos(a) * radius * 0.32, sin(a) * radius * 0.32);
      final outer = Offset(cos(a) * radius * 0.80, sin(a) * radius * 0.80);
      canvas.drawLine(inner, outer, spokePaint);
    }
    // Tâm bánh tời.
    canvas.drawCircle(Offset.zero, radius * 0.30,
        Paint()..color = Colors.white.withValues(alpha: 0.18));
    canvas.drawCircle(
      Offset.zero,
      radius * 0.30,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Điểm sáng đánh dấu để mắt bắt được chiều/tốc độ quay rõ ràng hơn.
    canvas.drawCircle(Offset(radius * 0.62, 0), radius * 0.11,
        Paint()..color = AppColors.gold);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReelWheelPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

/// Vẽ sợi dây câu thật từ tay pet ra tới đúng vị trí phao trên mặt nước
/// (dùng ở cảnh nền thật, KHÁC với [_FishingLinePainter] bên dưới — cái đó
/// chỉ dùng trong thanh giật cần thu nhỏ). Dây căng thẳng hơn khi [taut]
/// (đang giật cần) để có cảm giác cá đang kéo mạnh.
class _SceneLinePainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final bool taut;
  _SceneLinePainter({required this.from, required this.to, this.taut = false});

  @override
  void paint(Canvas canvas, Size size) {
    final sag = taut ? 4.0 : 14.0;
    final control = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 + sag);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: taut ? 0.85 : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = taut ? 1.8 : 1.3,
    );
  }

  @override
  bool shouldRepaint(covariant _SceneLinePainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to || oldDelegate.taut != taut;
}

/// Vẽ sợi dây câu (đường cong nhẹ) từ đầu cần (giữa, phía trên) xuống
/// đúng vị trí cá hiện tại trên thanh giật cần — cho cảm giác "dây đang
/// căng theo cá" sinh động hơn.
class _FishingLinePainter extends CustomPainter {
  final double fishX;
  _FishingLinePainter(this.fishX);

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width / 2, 0);
    final end = Offset(fishX, 20);
    final control = Offset((start.dx + end.dx) / 2, 10);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _FishingLinePainter oldDelegate) =>
      oldDelegate.fishX != fishX;
}

/// Vẽ hào quang xoay quanh con cá vừa câu được ở màn kết quả: 1 vòng sáng
/// mờ (glow) phía sau + các luồng ánh sáng dạng tia xoay liên tục + 1 vòng
/// viền mỏng, tất cả cùng màu theo độ hiếm ([rarityAuraColor]) — RÁC cũng
/// có hào quang riêng (màu bạc xám), không chỉ cá quý mới có hiệu ứng.
class _AuraPainter extends CustomPainter {
  final double progress; // 0..1, lặp lại liên tục để tạo hiệu ứng xoay
  final Color color;
  final int rayCount;

  _AuraPainter({
    required this.progress,
    required this.color,
    required this.rayCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    final rotation = progress * 2 * pi;

    // Hào quang mờ lan tỏa phía sau — CHỦ ĐẠO là màu độ hiếm; chỉ có 1
    // điểm sáng trắng NHỎ ở tâm, không lấn màu chính.
    canvas.drawCircle(
      center,
      maxRadius * 0.62,
      Paint()
        ..color = color.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    canvas.drawCircle(
      center,
      maxRadius * 0.22,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Các luồng ánh sáng hình tia — MÀU ĐỘ HIẾM là chủ đạo (thân tia to,
    // đậm), mỗi tia chỉ có 1 lõi trắng MỎNG ở giữa để "xen lẫn 1 chút màu
    // trắng" chứ không thay hẳn màu như trước.
    Path rayPath(double angle, double spread, double length) {
      final p2 = center +
          Offset(cos(angle - spread), sin(angle - spread)) * length;
      final p3 = center +
          Offset(cos(angle + spread), sin(angle + spread)) * length;
      return Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
    }

    // Các luồng ánh sáng hình tia — đồng nhất 1 MÀU ĐỘ HIẾM, xoay liên tục.
    for (var i = 0; i < rayCount; i++) {
      final baseAngle = (2 * pi / rayCount) * i + rotation;
      final halfSpread = (pi / rayCount) * 0.34;

      canvas.drawPath(
        rayPath(baseAngle, halfSpread, maxRadius),
        Paint()..color = color.withValues(alpha: 0.65),
      );
    }

    // Lấp lánh (sparkle) nhấp nháy nhẹ quanh vòng ngoài — chỉ là điểm nhấn
    // trắng nhỏ, không phải 1 lớp tia riêng.
    final sparkleCount = (rayCount / 2).round().clamp(3, 8);
    for (var i = 0; i < sparkleCount; i++) {
      final angle = (2 * pi / sparkleCount) * i + rotation * 1.4;
      final twinkle = (sin(progress * 2 * pi * 3 + i) + 1) / 2; // 0..1
      final pos = center + Offset(cos(angle), sin(angle)) * maxRadius * 0.8;
      canvas.drawCircle(
        pos,
        1.8 + twinkle * 1.8,
        Paint()..color = Colors.white.withValues(alpha: 0.3 + twinkle * 0.4),
      );
    }

    // Viền: màu độ hiếm là chính, viền trắng chỉ là nét mỏng bên trong.
    canvas.drawCircle(
      center,
      maxRadius * 0.6,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(
      center,
      maxRadius * 0.6,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.rayCount != rayCount;
}

class _ConfettiParticle {
  final String emoji;
  final double angle;
  final double distance;
  final double size;
  final double delay;
  const _ConfettiParticle({
    required this.emoji,
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });
}

/// Vẽ pháo hoa emoji bắn ra từ tâm màn hình khi câu được cá hiếm/kỷ lục.
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress; // 0..1
  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final eased = Curves.easeOut.transform(t);
      final dist = p.distance * eased;
      final dx = cos(p.angle) * dist;
      final dy = sin(p.angle) * dist + eased * eased * 40; // rơi nhẹ xuống
      final opacity = (1 - t).clamp(0.0, 1.0);

      final textPainter = TextPainter(
        text: TextSpan(
          text: p.emoji,
          style: TextStyle(
              fontSize: p.size, color: Colors.white.withValues(alpha: opacity)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center +
            Offset(dx, dy) -
            Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _InfoChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _InfoChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ]),
    );
  }
}

/// Cửa hàng câu cá — nâng cấp Cần câu (Coin) và mua Mồi câu may mắn (Gem).
class _FishingGearSheet extends StatefulWidget {
  const _FishingGearSheet();

  @override
  State<_FishingGearSheet> createState() => _FishingGearSheetState();
}

class _FishingGearSheetState extends State<_FishingGearSheet> {
  final _firestoreService = FirestoreService();
  bool _busy = false;

  Future<void> _upgradeRod(int newTier) async {
    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent;
    if (student == null || _busy) return;
    final cost = kRodTiers[newTier].priceCoin;
    if (!student.hasEnoughCoin(cost)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không đủ Coin!')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _firestoreService.upgradeFishingRod(student.uid, newTier, cost);
      auth.currentStudent =
          student.copyWith(coin: student.coin - cost, fishingRodTier: newTier);
      auth.notifyListeners();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Có lỗi xảy ra: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyBait(int quantity) async {
    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent;
    if (student == null || _busy) return;
    final cost = kBaitGemPrice * quantity;
    if (!student.hasEnoughGem(cost)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không đủ Kim cương!')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _firestoreService.buyFishingBait(student.uid, quantity, cost);
      auth.currentStudent = student.copyWith(
          gem: student.gem - cost, baitCharges: student.baitCharges + quantity);
      auth.notifyListeners();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Có lỗi xảy ra: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent;
    final currentTier = student?.fishingRodTier ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('🎣 Cửa hàng câu cá',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 4),
            const Text('Nâng cấp cần câu và mua mồi câu để dễ gặp cá hiếm hơn!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Cần câu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            for (var i = 0; i < kRodTiers.length; i++)
              _RodTierTile(
                tier: kRodTiers[i],
                owned: i <= currentTier,
                isCurrent: i == currentTier,
                canAfford:
                    student?.hasEnoughCoin(kRodTiers[i].priceCoin) ?? false,
                busy: _busy,
                onUpgrade: () => _upgradeRod(i),
              ),
            const SizedBox(height: 20),
            const Text('Mồi câu may mắn 🧪',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
                'Đang có: ${student?.baitCharges ?? 0} lượt — mỗi lượt câu tự dùng 1 mồi để tăng thêm cơ hội gặp cá hiếm.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _buyBait(5),
                    child: Text('Mua 5 (${kBaitGemPrice * 5} 💎)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _buyBait(20),
                    child: Text('Mua 20 (${kBaitGemPrice * 20} 💎)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RodTierTile extends StatelessWidget {
  final RodTier tier;
  final bool owned;
  final bool isCurrent;
  final bool canAfford;
  final bool busy;
  final VoidCallback onUpgrade;

  const _RodTierTile({
    required this.tier,
    required this.owned,
    required this.isCurrent,
    required this.canAfford,
    required this.busy,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(tier.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '+${tier.extraRerolls} may mắn · +${(tier.markerSizeBonus * 100).round()}% dễ giật · ${tier.energyCost}⚡/lượt',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (isCurrent)
            const Chip(
                label: Text('Đang dùng', style: TextStyle(fontSize: 11)),
                backgroundColor: AppColors.success,
                labelStyle: TextStyle(color: Colors.white))
          else if (owned)
            const Text('Đã có',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          else
            FilledButton(
              onPressed: (busy || !canAfford) ? null : onUpgrade,
              child: Text(
                  tier.priceCoin == 0 ? 'Miễn phí' : '${tier.priceCoin} 🪙'),
            ),
        ],
      ),
    );
  }
}