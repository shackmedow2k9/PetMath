import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart' hide Text;
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../models/food_catalog.dart';
import '../models/house_catalog.dart';
import '../models/item_model.dart';
import '../models/pet_family_catalog.dart';
import '../models/pet_model.dart';
import '../models/room_data.dart';
import '../models/student_model.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/emoji_icon.dart';
import '../widgets/pet_care_dock.dart';
import '../models/pet_activity_catalog.dart';
import 'pet_library_screen.dart';
import 'skin_box_screen.dart';
import '../widgets/friendship_widgets.dart';
import '../theme/app_theme.dart';
import '../widgets/skin_room_sheet.dart';
import 'shop_screen.dart';
import 'minigame_hub_screen.dart';
import 'leaderboard_screen.dart';

/// Pet đang làm gì lúc này — quyết định animation nào đang chạy và có
/// cho phép chạm/kéo hay không.
enum PetActivity {
  idle,
  dragging,
  walking,
  sleeping,
  eating,
  turning, // quay mặt qua lại tại chỗ
  hopping, // nhảy nhẹ tại chỗ vài lần
  spinning, // xoay vòng tại chỗ kiểu mèo đuổi đuôi
  bigJump, // nhảy 1 đoạn cao tại chỗ
  bathing, // đang tắm, có bọt xà phòng
  playing, // chơi trực tiếp với chủ
  toileting, // đi vệ sinh
}

/// "Nhà của pet" kiểu Talking Tom: bước vào Phòng ngủ trước, có thể lướt
/// sang Nhà tắm / Phòng ăn. Pet là 1 sprite 2D sống động: tự đi dạo lung
/// tung quanh nhà khi rảnh, kéo thả được (thả ra rơi bịch xuống kiểu
/// slime), chạm vào thì nhảy lắc chân, có thể dơ dần rồi cần tắm.
class HouseInteriorScreen extends StatefulWidget {
  final bool teacherMode;

  const HouseInteriorScreen({super.key, this.teacherMode = false});

  @override
  State<HouseInteriorScreen> createState() => _HouseInteriorScreenState();
}

class _HouseInteriorScreenState extends State<HouseInteriorScreen>
    with TickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _pageController = PageController();
  final _random = Random();

  int _roomIndex = 0; // phòng học sinh đang xem
  int _petRoomIndex = 0; // phòng pet hiện đang ở (có thể khác phòng đang xem)
  bool _busy = false;

  // ---------- Bàn ăn (Phòng ăn) ----------
  bool _showFoodTable = false;
  int _foodPageStart =
      0; // vị trí bắt đầu trang hiện tại trong danh sách đồ ăn đang sở hữu
  bool _showCrumbs = false; // hiệu ứng vụn đồ ăn khi đang nhai
  bool _showPoof = false; // hiệu ứng "biến mất" khi món ăn được đưa cho pet

  // ---------- Nhà tắm (Nhà tắm) — chà xà phòng rồi xịt nước, 2 bước ----------
  bool _showBathScene = false;
  int _soapScrubCount = 0;
  bool _bathRinsing = false;
  static const int _bathRequiredScrubs = 3;

  PetActivity _activity = PetActivity.idle;
  Offset _petPos = const Offset(0.5, 0.62); // tỉ lệ 0..1 trong không gian phòng
  bool _facingRight = true;
  Offset _walkFrom = Offset.zero;
  Offset _walkTo = Offset.zero;

  Timer? _idleTimer;
  Timer? _clockTimer;
  Timer? _petRefreshTimer;
  Timer? _thoughtTimer;
  bool _refreshingPet = false;

  // Đồng hồ mô phỏng: 1 ngày game (00:00–23:59) = 15 phút ngoài đời.
  // Tách riêng hai đơn vị: 15 phút là thời lượng ngoài đời, còn một ngày
  // hiển thị của game luôn là 24 giờ để đồng hồ không bị lặp ở 00:14.
  static const Duration _gameDurationPerDay = Duration(hours: 24);
  static const int _gameSpeed = 96; // 24 giờ game / 15 phút thực
  static final DateTime _gameEpoch = DateTime(2026, 1, 1);
  // Offset được lưu theo micro-giây của GAME, không phải micro-giây thực.
  Duration _gameTimeOffset = Duration.zero;
  DateTime _gameNow = DateTime.now();
  String? _petThought;

  DateTime _gameClockFromReal(DateTime realNow) {
    final realElapsedMicros = realNow.difference(_gameEpoch).inMicroseconds;
    final gameElapsedMicros =
        realElapsedMicros * _gameSpeed + _gameTimeOffset.inMicroseconds;
    final dayMicros = _gameDurationPerDay.inMicroseconds;
    final position = ((gameElapsedMicros % dayMicros) + dayMicros) % dayMicros;
    return _gameEpoch.add(Duration(microseconds: position));
  }

  /// Sau khi ngủ xong, đưa đồng hồ game tới 05:00 của chu kỳ kế tiếp.
  void _wakeGameAtMorning() {
    final dayMicros = _gameDurationPerDay.inMicroseconds;
    final morningMicros = const Duration(hours: 5).inMicroseconds;
    final currentPosition = _gameClockFromReal(DateTime.now())
        .difference(_gameEpoch)
        .inMicroseconds;
    var forwardGameMicros = morningMicros - currentPosition;
    if (forwardGameMicros <= 0) forwardGameMicros += dayMicros;
    _gameTimeOffset += Duration(microseconds: forwardGameMicros);
    _gameNow = _gameClockFromReal(DateTime.now());
  }

  bool get _isNight => _gameNow.hour >= 19 || _gameNow.hour < 5;

  String get _gameTimeLabel =>
      '${_gameNow.hour.toString().padLeft(2, '0')}:${_gameNow.minute.toString().padLeft(2, '0')}';

  /// Callback chạy khi 1 lượt đi bộ (do bấm nút hành động phòng) tới đích —
  /// dùng để "đi tới phòng rồi mới ăn/tắm/ngủ" thay vì phải đứng sẵn đó.
  VoidCallback? _pendingArrival;

  /// Tăng dần mỗi khi có 1 hành động MỚI giành quyền điều khiển pet — các
  /// vòng lặp bất đồng bộ (quay/nhảy/xoay khi rảnh) tự kiểm tra token này
  /// sau mỗi await để biết mình đã bị "cắt ngang" hay chưa, tránh việc
  /// chúng ghi đè _activity của 1 hành động mới hơn.
  int _actionToken = 0;

  late final AnimationController
      _idleBobController; // bập bênh nhẹ khi đứng yên
  late final AnimationController
      _squashController; // rơi bịch kiểu slime khi thả tay
  late final AnimationController _jumpController; // nhảy lắc chân khi chạm vào
  late final AnimationController
      _walkController; // đi dạo (di chuyển + bước chân)
  late final AnimationController _sleepController; // thở phập phồng khi ngủ
  late final AnimationController _eatController; // nhai nhóp nhép khi ăn
  late final AnimationController _hopController; // nhảy nhẹ tại chỗ (idle)
  late final AnimationController _spinController; // xoay vòng tại chỗ (idle)
  late final AnimationController _bigJumpController; // nhảy 1 đoạn cao (idle)
  late final AnimationController _bathController; // bọt xà phòng khi tắm

  @override
  void initState() {
    super.initState();
    _idleBobController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _squashController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _jumpController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _walkController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _petPos = _walkTo;
            _activity = PetActivity.idle;
          });
          final pending = _pendingArrival;
          _pendingArrival = null;
          if (pending != null) {
            pending();
          } else {
            _restartIdleTimer();
          }
        }
      });
    _sleepController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _eatController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _hopController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _spinController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _bigJumpController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _bathController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));

    _gameNow = _gameClockFromReal(DateTime.now());
    _restartIdleTimer();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final nextGameNow = _gameClockFromReal(DateTime.now());
      if (nextGameNow.minute != _gameNow.minute ||
          nextGameNow.hour != _gameNow.hour ||
          nextGameNow.second != _gameNow.second) {
        setState(() => _gameNow = nextGameNow);
      }
    });
    _petRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted || _refreshingPet) return;
      _refreshingPet = true;
      try {
        await context.read<PetProvider>().refreshPetNow();
      } finally {
        _refreshingPet = false;
      }
    });
    // Khi mở thẳng căn nhà từ cổng giáo viên, PetHomeScreen không còn là
    // bước trung gian để gọi watchPet; vì vậy căn nhà tự kết nối hồ sơ pet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final petId = context.read<AuthProvider>().currentStudent?.petId;
      if (petId != null) context.read<PetProvider>().watchPet(petId);
    });
    // LƯU Ý: trước đây có 1 Timer.periodic 18s tự trừ Sạch sẽ ngay tại
    // đây (_dirtTick) — chỉ hoạt động khi màn hình này đang mở. Đã thay
    // bằng cơ chế trừ hao theo thời gian THỰC dùng chung cho mọi màn hình
    // (xem [FirestoreService.applyTimeDecay]), nên không cần Timer riêng
    // ở đây nữa — pet vẫn dơ dần dù học sinh không vào Nhà pet.
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _clockTimer?.cancel();
    _petRefreshTimer?.cancel();
    _thoughtTimer?.cancel();
    _idleBobController.dispose();
    _squashController.dispose();
    _jumpController.dispose();
    _walkController.dispose();
    _sleepController.dispose();
    _eatController.dispose();
    _hopController.dispose();
    _spinController.dispose();
    _bigJumpController.dispose();
    _bathController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ---------- Đi dạo lung tung khi rảnh ----------

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 7), _tryWander);
  }

  /// Gọi mỗi khi học sinh chạm/kéo/chăm pet — hoãn đồng hồ đi dạo lại.
  void _registerInteraction() => _restartIdleTimer();

  /// Sau 15s không tương tác: chọn ngẫu nhiên 1 trong 4 kiểu "tự chơi 1 mình".
  void _tryWander() {
    if (!mounted) return;
    if (_activity != PetActivity.idle) {
      _restartIdleTimer();
      return;
    }
    switch (_random.nextInt(5)) {
      case 0:
        _startWalkAround();
        break;
      case 1:
        _startTurning();
        break;
      case 2:
        _startHopping();
        break;
      case 3:
        _startSpinning();
        break;
      default:
        _startBigJump();
    }
  }

  Offset _randomSpot() => Offset(
        0.15 + _random.nextDouble() * 0.7,
        0.45 + _random.nextDouble() * 0.32,
      );

  // TH1: đi dạo — đôi khi đổi phòng, đôi khi đi tới 1 điểm ngẫu nhiên.
  void _startWalkAround() {
    final changeRoom = kRooms.length > 1 && _random.nextDouble() < 0.35;
    if (changeRoom) {
      int newRoom;
      do {
        newRoom = _random.nextInt(kRooms.length);
      } while (newRoom == _petRoomIndex);
      setState(() {
        _petRoomIndex = newRoom;
        _petPos = _randomSpot();
      });
      _restartIdleTimer();
    } else {
      _walkToRandomSpot();
    }
  }

  /// Bắt đầu 1 lượt đi bộ tới [target] (tỉ lệ 0..1 trong phòng hiện tại của
  /// pet). Nếu [onArrive] được cung cấp, nó sẽ chạy ngay khi đi tới nơi
  /// (dùng cho trường hợp "đi tới phòng rồi mới ăn/tắm/ngủ").
  void _beginWalkTo(Offset target, {VoidCallback? onArrive}) {
    ++_actionToken; // hủy mọi hành động rảnh rỗi (quay/nhảy/xoay) đang dở
    _walkFrom = _petPos;
    _walkTo = target;
    _facingRight = target.dx >= _petPos.dx;
    _pendingArrival = onArrive;
    setState(() => _activity = PetActivity.walking);
    _walkController.forward(from: 0);
  }

  void _walkToRandomSpot() {
    if (!mounted) return;
    _beginWalkTo(_randomSpot());
  }

  // TH2: quay mặt qua lại tại chỗ, lặp ngẫu nhiên 1-5 lần.
  Future<void> _startTurning() async {
    final token = ++_actionToken;
    final times = 1 + _random.nextInt(5); // 1..5
    setState(() => _activity = PetActivity.turning);
    for (var i = 0; i < times; i++) {
      if (!mounted || token != _actionToken) return;
      setState(() => _facingRight = !_facingRight);
      await Future.delayed(const Duration(milliseconds: 450));
    }
    if (!mounted || token != _actionToken) return;
    setState(() => _activity = PetActivity.idle);
    _restartIdleTimer();
  }

  // TH3: nhảy lên 1 đoạn nhỏ tại chỗ, lặp ngẫu nhiên 1-5 lần.
  Future<void> _startHopping() async {
    final token = ++_actionToken;
    final times = 1 + _random.nextInt(5); // 1..5
    setState(() => _activity = PetActivity.hopping);
    for (var i = 0; i < times; i++) {
      if (!mounted || token != _actionToken) return;
      await _hopController.forward(from: 0);
      if (!mounted || token != _actionToken) return;
      await Future.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted || token != _actionToken) return;
    setState(() => _activity = PetActivity.idle);
    _restartIdleTimer();
  }

  // TH4: xoay vòng tại chỗ kiểu mèo đuổi đuôi, trong ngẫu nhiên 1-5 giây.
  Future<void> _startSpinning() async {
    final token = ++_actionToken;
    final seconds = 1 + _random.nextInt(5); // 1..5
    setState(() => _activity = PetActivity.spinning);
    _spinController.repeat();
    await Future.delayed(Duration(seconds: seconds));
    _spinController.stop();
    _spinController.value = 0;
    if (!mounted || token != _actionToken) return;
    setState(() => _activity = PetActivity.idle);
    _restartIdleTimer();
  }

  // TH5: nhảy 1 đoạn cao tại chỗ (1 lần, cao hơn hẳn nhảy nhẹ).
  Future<void> _startBigJump() async {
    final token = ++_actionToken;
    setState(() => _activity = PetActivity.bigJump);
    await _bigJumpController.forward(from: 0);
    if (!mounted || token != _actionToken) return;
    setState(() => _activity = PetActivity.idle);
    _restartIdleTimer();
  }

  // ---------- Tương tác chạm / kéo thả ----------

  static const _busyActivities = {
    PetActivity.sleeping,
    PetActivity.eating,
    PetActivity.walking,
    PetActivity.turning,
    PetActivity.hopping,
    PetActivity.spinning,
    PetActivity.bigJump,
    PetActivity.bathing,
    PetActivity.playing,
    PetActivity.toileting,
  };

  void _onPetTap() {
    if (_busy ||
        _activity == PetActivity.sleeping ||
        _activity == PetActivity.eating ||
        _activity == PetActivity.bathing ||
        _activity == PetActivity.playing ||
        _activity == PetActivity.toileting) return;
    _registerInteraction();
    // Mỗi lần chạm pet phản ứng khác nhau (như Talking Tom): xoay vòng các câu.
    const lines = [
      'Aww! Mình thích được vuốt ve quá! 💕',
      'Hihi, nhột quá đi! 😆',
      'Mình ở đây nè! 🐾',
      'Bạn thật là tốt với mình! 🥰',
      'Chơi với mình tiếp đi! ✨',
      'Hì hì, mình vui lắm! 🌟',
      'Gãi tiếp đi, gãi tiếp đi~ 😌',
    ];
    _tapCount++;
    _setPetThought(lines[_tapCount % lines.length]);
    _jumpController.forward(from: 0);
  }

  int _tapCount = 0;

  /// Đi sang phòng tương ứng (nếu đang ở phòng khác) rồi mới làm hành động.
  Future<void> _goRoomThenAct(RoomType type) async {
    if (_busy) return;
    final idx = kRooms.indexWhere((r) => r.type == type);
    if (idx < 0) return;
    if (idx != _roomIndex) {
      await _pageController.animateToPage(idx,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      if (!mounted) return;
      setState(() => _roomIndex = idx);
    }
    _handleRoomAction(type);
  }

  /// Hoạt động vui chơi/học cùng pet (xem [PetActivityCatalog]).
  Future<void> _doPetActivity(PetActivityDef a) async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _busy) return;
    if (pet.energy < a.minEnergy) {
      _setPetThought('Mình hơi mệt rồi, cho mình nghỉ một chút nhé…');
      return;
    }
    if (pet.hunger < a.minHunger) {
      _setPetThought('Bụng mình đói rồi, cho mình ăn trước nhé… 🍽️');
      return;
    }
    _idleTimer?.cancel();
    _thoughtTimer?.cancel();
    setState(() {
      _busy = true;
      _activity = PetActivity.playing;
      _petThought = a.startThought;
    });
    if (a.anim == 'spin') {
      _hopController.repeat(reverse: true);
      _spinController.repeat();
    } else if (a.anim == 'hop') {
      _hopController.repeat(reverse: true);
    }
    for (var i = 0; i < a.seconds; i++) {
      if (a.anim == 'pose') _jumpController.forward(from: 0);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
    _hopController.stop();
    _spinController.stop();
    _spinController.value = 0;
    try {
      await _firestoreService.petActivity(pet.id,
          hunger: a.hunger,
          energy: a.energy,
          happiness: a.happiness,
          hp: a.hp,
          exp: a.exp);
      await _firestoreService.addPetAffection(
          pet.id, FirestoreService.playAffectionGain);
      _setPetThought(a.doneThought);
    } catch (e) {
      _setPetThought('Mình chưa làm được lúc này, thử lại nhé.');
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = PetActivity.idle;
        });
      }
      _registerInteraction();
    }
  }

  void _openActivitiesSheet() {
    final pet = context.read<PetProvider>().pet;
    if (pet == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => PetActivitiesSheet(pet: pet, onPick: _doPetActivity),
    );
  }

  void _openMenuSheet() {
    final pet = context.read<PetProvider>().pet;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        void go(Widget page) {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 12),
                const Text('Menu',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    MenuTile(
                        icon: const EmojiIcon('🛒', size: 38),
                        label: tr('Cửa hàng'),
                        onTap: () => go(const ShopScreen())),
                    MenuTile(
                        icon: const EmojiIcon('🎮', size: 38),
                        label: tr('Mini game'),
                        onTap: () => go(const MiniGameHubScreen())),
                    MenuTile(
                        icon: const EmojiIcon('🏆', size: 38),
                        label: tr('Bảng xếp hạng'),
                        onTap: () => go(const LeaderboardScreen())),
                    MenuTile(
                        icon: const EmojiIcon('👕', size: 38),
                        label: tr('Phòng đổi skin'),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _openWardrobe();
                        }),
                    MenuTile(
                        icon: const EmojiIcon('🏠', size: 38),
                        label: tr('Đổi nhà'),
                        onTap: () => go(const ShopScreen(
                            initialCategory: ItemCategory.house))),
                    if (!widget.teacherMode)
                      MenuTile(
                          icon: const Icon(Icons.collections_bookmark_rounded,
                              size: 34, color: AppColors.primary),
                          label: tr('Thư viện Pet'),
                          onTap: () => go(const PetLibraryScreen())),
                    if (!widget.teacherMode)
                      MenuTile(
                          icon: const EmojiIcon('🎭', size: 38),
                          label: tr('Hộp mù Skin'),
                          onTap: () => go(const SkinBoxScreen())),
                    if (!widget.teacherMode && pet != null)
                      MenuTile(
                          icon: const Icon(Icons.favorite_rounded,
                              size: 34, color: Color(0xFFFF6B8A)),
                          label: tr('Thân thiết'),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _showAffectionSheet(pet);
                          }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setPetThought(String text,
      {Duration visibleFor = const Duration(seconds: 4)}) {
    if (!mounted) return;
    _thoughtTimer?.cancel();
    setState(() => _petThought = text);
    _thoughtTimer = Timer(visibleFor, () {
      if (mounted) setState(() => _petThought = null);
    });
  }

  Future<void> _playWithPet() async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _busy) return;
    if (pet.energy <= 15) {
      _setPetThought('Mình hơi mệt rồi, cho mình nghỉ một chút nhé…');
      return;
    }
    _idleTimer?.cancel();
    setState(() {
      _busy = true;
      _activity = PetActivity.playing;
      _petThought = 'Chơi với mình nhé! 🎾';
    });
    _thoughtTimer?.cancel();
    _hopController.repeat(reverse: true);
    _spinController.repeat();
    await Future.delayed(const Duration(seconds: 3));
    _hopController.stop();
    _spinController.stop();
    _spinController.value = 0;
    if (!mounted) return;
    try {
      await _firestoreService.playWithPet(pet.id);
      await _firestoreService.addPetAffection(
          pet.id, FirestoreService.playAffectionGain);
      _setPetThought('Vui quá! Cảm ơn bạn đã chơi cùng mình! ✨');
    } catch (e) {
      _setPetThought('Mình chưa chơi được lúc này, thử lại nhé.');
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = PetActivity.idle;
        });
      }
      _registerInteraction();
    }
  }

  Future<void> _useToilet() async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _busy) return;
    if (pet.toiletNeed < 20) {
      _setPetThought('Mình chưa cần đi vệ sinh đâu! 😊');
      return;
    }
    _idleTimer?.cancel();
    setState(() {
      _busy = true;
      _activity = PetActivity.toileting;
      _petThought = 'Mình đi vệ sinh một chút nhé… 🚽';
    });
    _thoughtTimer?.cancel();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      await _firestoreService.useToilet(pet.id);
      _setPetThought('Thoải mái hơn nhiều rồi! 🌟');
    } catch (e) {
      _setPetThought('Có lỗi khi thực hiện, thử lại nhé.');
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = PetActivity.idle;
        });
      }
      _registerInteraction();
    }
  }

  void _onPetDragStart() {
    if (_busyActivities.contains(_activity)) {
      return;
    }
    setState(() => _activity = PetActivity.dragging);
  }

  void _onPetDragUpdate(Offset delta, double worldW, double worldH) {
    if (_activity != PetActivity.dragging) return;
    // QUAN TRỌNG: tính trên _petPos của State (luôn mới nhất), không phải
    // giá trị petPos được truyền qua props xuống widget con — vì khi kéo
    // nhanh, nhiều sự kiện onPanUpdate có thể tới trước khi widget kịp
    // build lại, khiến props bị "cũ" và làm pet theo chuột chậm/lag.
    setState(() {
      final dx = ((_petPos.dx * worldW) + delta.dx).clamp(40.0, worldW - 40.0) /
          worldW;
      final dy = ((_petPos.dy * worldH) + delta.dy).clamp(80.0, worldH - 40.0) /
          worldH;
      _petPos = Offset(dx, dy);
    });
  }

  void _onPetDragEnd() {
    if (_activity != PetActivity.dragging) return;
    setState(() => _activity = PetActivity.idle);
    _squashController.forward(from: 0); // rơi bịch kiểu slime
    _registerInteraction();
  }

  // ---------- 3 hành động chăm sóc theo phòng ----------

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _ambientThought(PetModel pet) {
    if (pet.toiletNeed >= 70) return 'Mình muốn đi vệ sinh… 🚽';
    if (pet.hunger <= 35) return 'Bụng mình réo rồi… 🍽️';
    if (pet.hygiene <= 35) return 'Mình cần được tắm… 🫧';
    if (pet.energy <= 30) {
      return _isNight
          ? 'Mình buồn ngủ quá… 🌙'
          : 'Mình hơi mệt, muốn chơi nhẹ thôi…';
    }
    if (pet.playfulness <= 35) return 'Chơi với mình một chút nhé! 🎾';
    return _isNight
        ? 'Tối nay thật yên tĩnh… ✨'
        : 'Mình đang nhìn ngắm căn nhà! ☀️';
  }

  /// Mở bàn ăn (chiếm 1/4 màn hình phía dưới, làm mờ nền phía sau) — thay
  /// cho việc tự động ăn ngay như trước đây. Học sinh cần kéo món ăn đã
  /// mua từ bàn lên khu vực pet để cho ăn (xem [_feedWithFood]).
  void _openFoodTable() {
    setState(() {
      _showFoodTable = true;
      _foodPageStart = 0;
    });
  }

  void _closeFoodTable() {
    setState(() => _showFoodTable = false);
  }

  /// Cho pet ăn 1 món cụ thể đã kéo thả tới khu vực pet — mỗi món hồi No
  /// bụng & cộng EXP khác nhau theo đúng giá trị đã mua ở Cửa hàng.
  Future<void> _feedWithFood(FoodTemplate food) async {
    final auth = context.read<AuthProvider>();
    final pet = context.read<PetProvider>().pet;
    final student = auth.currentStudent;
    if (pet == null || student == null || _busy) return;

    final owned = student.foodInventory[food.id] ?? 0;
    if (owned < 1) {
      _showMessage('Bạn đã hết "${food.name}" rồi, hãy mua thêm ở Cửa hàng!');
      return;
    }

    setState(() {
      _busy = true;
      _activity = PetActivity.eating;
      _showCrumbs = true;
    });
    _idleTimer?.cancel();
    _eatController.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 2200));
    _eatController.stop();
    _eatController.value = 0;
    if (!mounted) return;

    try {
      final success = await _firestoreService.feedPetWithFood(
        studentId: student.uid,
        petId: pet.id,
        foodId: food.id,
        hungerRestore: food.hungerRestore,
        expReward: food.expReward,
      );
      if (success) {
        // Gọi refreshCurrentStudent() thay vì tự cập nhật foodInventory
        // cục bộ — vừa lấy đúng số liệu mới nhất từ Firestore (kể cả
        // petLevel nếu vừa lên cấp), vừa tự kiểm tra thành tựu mới luôn
        // (xem AuthProvider.refreshCurrentStudent).
        await auth.refreshCurrentStudent();
        await _firestoreService.addPetAffection(
            pet.id, FirestoreService.feedAffectionGain);
        _showMessage(
            'Pet đã ăn "${food.name}" ngon lành! +${food.expReward} EXP 🍽️');
      } else {
        _showMessage('Bạn đã hết "${food.name}" rồi!');
      }
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = PetActivity.idle;
          _showCrumbs = false;
        });
      }
      _registerInteraction();
    }
  }

  /// Mở "cảnh tắm" (che mờ nền, pet phóng to nổi bật) — thay cho việc tắm
  /// xong ngay chỉ bằng 1 nút bấm như trước. Học sinh cần kéo xà phòng
  /// chà lên pet đủ [_bathRequiredScrubs] lần cho nổi bọt, rồi kéo vòi
  /// nước xịt để rửa sạch — giống hệt cách tắm cho thú cưng trong Talking
  /// Tom (xem [_onSoapScrub], [_onHoseRinse]).
  void _openBathScene() {
    setState(() {
      _showBathScene = true;
      _soapScrubCount = 0;
      _bathRinsing = false;
    });
  }

  void _closeBathScene() {
    setState(() => _showBathScene = false);
  }

  /// Kéo xà phòng thả lên pet — mỗi lần cộng 1 nấc bọt, tới khi đủ
  /// [_bathRequiredScrubs] thì vòi nước mới dùng được.
  void _onSoapScrub() {
    if (_soapScrubCount >= _bathRequiredScrubs || _bathRinsing) return;
    setState(() => _soapScrubCount++);
    _bathController.forward(from: 0); // bọt "phù" lên 1 nhịp mỗi lần chà
  }

  /// Kéo vòi nước thả lên pet khi đã đủ bọt — xịt rửa sạch rồi mới thật
  /// sự ghi nhận lượt tắm (cộng chỉ số + điểm Thân thiết).
  Future<void> _onHoseRinse() async {
    if (_soapScrubCount < _bathRequiredScrubs || _bathRinsing) return;
    final pet = context.read<PetProvider>().pet;
    if (pet == null) return;

    setState(() => _bathRinsing = true);
    _bathController.repeat();
    await Future.delayed(const Duration(milliseconds: 1300));
    _bathController.stop();
    _bathController.value = 0;
    if (!mounted) return;

    try {
      await _firestoreService.bathePet(pet.id);
      await _firestoreService.addPetAffection(
          pet.id, FirestoreService.batheAffectionGain);
      _jumpController.forward(from: 0);
      _showMessage('Pet sạch sẽ thơm tho rồi! 🛁 +${FirestoreService.batheAffectionGain} Thân thiết');
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() {
          _showBathScene = false;
          _bathRinsing = false;
          _soapScrubCount = 0;
        });
      }
      _registerInteraction();
    }
  }

  Future<void> _sleep() async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _busy) return;

    if (!_isNight) {
      _setPetThought('Ban ngày mình chưa buồn ngủ. Tối mình sẽ ngủ nhé! ☀️');
      _showMessage(
          'Pet chỉ có thể ngủ vào buổi tối của giờ game (19:00–05:00).');
      return;
    }

    if (pet.energy >= 100) {
      _showMessage('Pet đã đầy Năng lượng, không cần ngủ nữa!');
      return;
    }

    setState(() {
      _busy = true;
      _activity = PetActivity.sleeping;
      _petThought = 'Zzz… Đến giờ ngủ rồi… 🌙';
    });
    _thoughtTimer?.cancel();
    _idleTimer?.cancel();
    _sleepController.repeat(reverse: true);
    await Future.delayed(const Duration(seconds: 15));
    _sleepController.stop();
    _sleepController.value = 0;
    if (!mounted) return;

    try {
      await _firestoreService.sleepPet(pet.id);
      await _firestoreService.addPetAffection(
          pet.id, FirestoreService.sleepAffectionGain);
      if (mounted) {
        // Ngủ có thể cộng EXP đủ để pet lên cấp → refresh để cập nhật
        // petLevel mới nhất và tự kiểm tra thành tựu liên quan.
        await context.read<AuthProvider>().refreshCurrentStudent();
      }
      if (mounted) {
        setState(() {
          _wakeGameAtMorning();
          _petThought = 'Chào buổi sáng! Mình đã ngủ đủ rồi! ☀️';
        });
      }
      _showMessage(
          'Pet đã thức dậy lúc 05:00, Năng lượng đã hồi 100! +10 EXP ☀️');
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _activity = PetActivity.idle;
        });
      _registerInteraction();
    }
  }

  /// Bấm nút hành động của 1 phòng: cho pet DI CHUYỂN tới đúng phòng đang
  /// xem (nếu đang ở phòng khác thì coi như "đi qua" phòng đó — dùng lại
  /// đúng cơ chế dịch chuyển phòng + đi tới 1 điểm bất kỳ đã có sẵn cho
  /// việc đi dạo tự do), rồi mới thực hiện hành động (ăn/tắm/ngủ).
  void _handleRoomAction(RoomType type) {
    if (_busy) return;
    if (_activity == PetActivity.sleeping || _activity == PetActivity.eating) {
      return;
    }
    _idleTimer?.cancel();

    void runAction() {
      switch (type) {
        case RoomType.bedroom:
          _sleep();
          break;
        case RoomType.bathroom:
          _openBathScene();
          break;
        case RoomType.dining:
          _openFoodTable();
          break;
      }
    }

    final targetRoomIndex = _roomIndex; // phòng đang xem trên màn hình
    final alreadyThere =
        _petRoomIndex == targetRoomIndex && _activity == PetActivity.idle;
    if (alreadyThere) {
      runAction();
      return;
    }

    if (_petRoomIndex != targetRoomIndex) {
      // "Đi qua" phòng khác: mỗi phòng là 1 world riêng nên việc chuyển
      // _petRoomIndex chính là bước pet sang phòng đó.
      setState(() => _petRoomIndex = targetRoomIndex);
    }
    _beginWalkTo(_randomSpot(), onArrive: runAction);
  }

  void _openWardrobe() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SkinRoomSheet(),
    );
  }

  void _showAffectionSheet(PetModel pet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const FriendshipSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pet = context.watch<PetProvider>().pet;
    final student = auth.currentStudent;
    if (pet == null || student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final house = HouseCatalog.byId(pet.currentHouseId);
    final ownedFoods = FoodCatalog.all
        .where((f) => (student.foodInventory[f.id] ?? 0) > 0)
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(house.name, style: const TextStyle(color: Colors.white)),
            Text(
              '${_isNight ? '🌙 Buổi tối' : '☀️ Buổi sáng'} · $_gameTimeLabel',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        // Các lối tắt khác (cửa hàng, skin, đổi nhà...) đã gom vào nút Menu ở
        // bảng điều khiển phía dưới cho gọn.
        actions: widget.teacherMode
            ? const []
            : [
                IconButton(
                  icon: const Icon(Icons.favorite_rounded,
                      color: Color(0xFFFF6B8A)),
                  tooltip: tr('Thân thiết'),
                  onPressed: () => _showAffectionSheet(pet),
                ),
              ],
      ),
      body: Stack(
        children: [
          // Popup mở khoá khi đạt mốc Thân thiết mới (widget vô hình).
          const FriendshipCelebrationListener(),
          PageView.builder(
            controller: _pageController,
            itemCount: kRooms.length,
            onPageChanged: (i) => setState(() => _roomIndex = i),
            itemBuilder: (context, index) {
              final room = kRooms[index];
              return _RoomView(
                key: ValueKey(room.type),
                pet: pet,
                room: room,
                backgroundAsset: roomBackgroundAsset(house.id, room.type),
                petThought: _petThought ?? _ambientThought(pet),
                showPet: _petRoomIndex == index &&
                    !_showFoodTable &&
                    !_showBathScene,
                activity: _activity,
                petPos: _petPos,
                walkFrom: _walkFrom,
                walkTo: _walkTo,
                facingRight: _facingRight,
                idleBobController: _idleBobController,
                walkController: _walkController,
                squashController: _squashController,
                jumpController: _jumpController,
                sleepController: _sleepController,
                eatController: _eatController,
                hopController: _hopController,
                spinController: _spinController,
                bigJumpController: _bigJumpController,
                bathController: _bathController,
                onPetTap: _onPetTap,
                onPetDragStart: _onPetDragStart,
                onPetDragUpdate: _onPetDragUpdate,
                onPetDragEnd: _onPetDragEnd,
              );
            },
          ),
          if (_isNight)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: Color(0x220D1B52)),
              ),
            ),
          if (widget.teacherMode) ...[
            Positioned(
              top: 58,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: _TeacherCurrencyBar(student: student),
                ),
              ),
            ),
          ],
          if (_showFoodTable) ...[
            // Làm mờ toàn bộ khung cảnh phía sau khi ngồi vào bàn ăn.
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withValues(alpha: 0.25)),
                ),
              ),
            ),
            // Khu vực thả đồ ăn cho pet — kéo món ăn từ bàn lên vùng này.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: MediaQuery.of(context).size.height * 0.25,
              child: DragTarget<FoodTemplate>(
                onAcceptWithDetails: (details) {
                  setState(() => _showPoof = true);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) setState(() => _showPoof = false);
                  });
                  _feedWithFood(details.data);
                },
                builder: (context, candidateData, rejectedData) =>
                    const SizedBox.expand(),
              ),
            ),
            // Pet "trồi lên" từ dưới bàn, phóng to, đứng nổi bật ngay khu
            // vực phía trên bàn ăn — mọi hiệu ứng khi ăn (vụn bánh, poof...)
            // đều hiển thị ngay trên pet này thay vì neo cố định cuối màn.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: MediaQuery.of(context).size.height * 0.25,
              child: IgnorePointer(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: const ValueKey('feed-spotlight-rise'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutBack,
                    builder: (context, t, child) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 90),
                        child: Transform.scale(
                          scale: 0.55 + 0.45 * t,
                          child: child,
                        ),
                      ),
                    ),
                    child: _FeedingSpotlightPet(
                      pet: pet,
                      isEating: _activity == PetActivity.eating,
                      idleBobController: _idleBobController,
                      eatController: _eatController,
                      showCrumbs: _showCrumbs,
                      showPoof: _showPoof,
                    ),
                  ),
                ),
              ),
            ),
            // Bàn ăn — chiếm 1/4 chiều cao màn hình, hiện tối đa 3 món/lượt.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.25,
              child: _FoodTablePanel(
                ownedFoods: ownedFoods,
                pageStart: _foodPageStart,
                onPageLeft: ownedFoods.isEmpty || _foodPageStart <= 0
                    ? null
                    : () => setState(
                        () => _foodPageStart = max(0, _foodPageStart - 3)),
                onPageRight: ownedFoods.isEmpty ||
                        _foodPageStart + 3 >= ownedFoods.length
                    ? null
                    : () => setState(() => _foodPageStart += 3),
                onClose: _closeFoodTable,
                onGoShopping: () {
                  _closeFoodTable();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const ShopScreen(initialCategory: ItemCategory.food),
                    ),
                  );
                },
              ),
            ),
          ],
          if (_showBathScene) ...[
            // Làm mờ toàn bộ khung cảnh phía sau khi bước vào cảnh tắm.
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withValues(alpha: 0.25)),
                ),
              ),
            ),
            // Khu vực thả xà phòng/vòi nước lên pet.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: MediaQuery.of(context).size.height * 0.22,
              child: DragTarget<String>(
                onAcceptWithDetails: (details) {
                  if (details.data == 'soap') {
                    _onSoapScrub();
                  } else if (details.data == 'hose') {
                    _onHoseRinse();
                  }
                },
                builder: (context, candidateData, rejectedData) =>
                    const SizedBox.expand(),
              ),
            ),
            // Pet phóng to nổi bật, hiện rõ số bọt xà phòng đã chà + hiệu
            // ứng xịt nước khi rửa.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: MediaQuery.of(context).size.height * 0.22,
              child: IgnorePointer(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: const ValueKey('bath-spotlight-rise'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutBack,
                    builder: (context, t, child) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 90),
                        child: Transform.scale(
                          scale: 0.55 + 0.45 * t,
                          child: child,
                        ),
                      ),
                    ),
                    child: _BathSpotlightPet(
                      pet: pet,
                      idleBobController: _idleBobController,
                      bathController: _bathController,
                      soapCount: _soapScrubCount,
                      requiredScrubs: _bathRequiredScrubs,
                      isRinsing: _bathRinsing,
                    ),
                  ),
                ),
              ),
            ),
            // Khay dụng cụ — xà phòng và vòi nước, chiếm gần 1/4 màn hình.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.22,
              child: _BathToolsPanel(
                soapCount: _soapScrubCount,
                requiredScrubs: _bathRequiredScrubs,
                soapReady: _soapScrubCount < _bathRequiredScrubs,
                hoseReady:
                    _soapScrubCount >= _bathRequiredScrubs && !_bathRinsing,
                onClose: _closeBathScene,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: PetCareDock(
        pet: pet,
        roomIndex: _roomIndex,
        busy: _busy,
        onRoom: (i) => _pageController.animateToPage(i,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut),
        onFeed: () => _goRoomThenAct(RoomType.dining),
        onBathe: () => _goRoomThenAct(RoomType.bathroom),
        onSleep: () => _goRoomThenAct(RoomType.bedroom),
        onToilet: _useToilet,
        onPlay: _playWithPet,
        onActivities: _openActivitiesSheet,
        onMenu: _openMenuSheet,
      ),
    );
  }
}

/// Nội dung 1 phòng: nền được vẽ RỘNG HƠN khung nhìn (để kéo camera xem
/// phần ngoài khung), pet sprite tương tác (chạm/kéo) nếu pet đang ở
/// đúng phòng này.
class _RoomView extends StatefulWidget {
  final PetModel pet;
  final RoomInfo room;
  final String backgroundAsset;
  final String? petThought;
  final bool showPet;
  final PetActivity activity;
  final Offset petPos;
  final Offset walkFrom;
  final Offset walkTo;
  final bool facingRight;
  final AnimationController idleBobController;
  final AnimationController squashController;
  final AnimationController jumpController;
  final AnimationController walkController;
  final AnimationController sleepController;
  final AnimationController eatController;
  final AnimationController hopController;
  final AnimationController spinController;
  final AnimationController bigJumpController;
  final AnimationController bathController;
  final VoidCallback onPetTap;
  final VoidCallback onPetDragStart;
  final void Function(Offset delta, double worldW, double worldH)
      onPetDragUpdate;
  final VoidCallback onPetDragEnd;

  const _RoomView({
    super.key,
    required this.pet,
    required this.room,
    required this.backgroundAsset,
    required this.petThought,
    required this.showPet,
    required this.activity,
    required this.petPos,
    required this.walkFrom,
    required this.walkTo,
    required this.facingRight,
    required this.idleBobController,
    required this.squashController,
    required this.jumpController,
    required this.walkController,
    required this.sleepController,
    required this.eatController,
    required this.hopController,
    required this.spinController,
    required this.bigJumpController,
    required this.bathController,
    required this.onPetTap,
    required this.onPetDragStart,
    required this.onPetDragUpdate,
    required this.onPetDragEnd,
  });

  @override
  State<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<_RoomView> {
  // Camera cho phép kéo ngang xem phần nền không vừa khung hình.
  double _cameraX = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportW = constraints.maxWidth;
        final viewportH = constraints.maxHeight;
        // Màn ngang/rộng (desktop, toàn màn hình) đã thấy đủ khung cảnh nên
        // không cần "world" rộng hơn để kéo xem thêm — dùng đúng bằng khung
        // hình để nền không bị phóng to bất thường. Chỉ màn dọc (mobile) hẹp
        // mới mở rộng thêm 55% để có thể kéo camera qua trái/phải.
        final isWide = viewportW >= viewportH;
        final bgW = isWide ? viewportW : viewportW * 1.55;
        final maxCameraShift = bgW - viewportW;

        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) {
              setState(() {
                _cameraX =
                    (_cameraX - details.delta.dx).clamp(0.0, maxCameraShift);
              });
            },
            child: Stack(
              children: [
                Positioned(
                  left: -_cameraX,
                  top: 0,
                  width: bgW,
                  height: viewportH,
                  child: _RoomWorld(
                    pet: widget.pet,
                    room: widget.room,
                    backgroundAsset: widget.backgroundAsset,
                    petThought: widget.petThought,
                    showPet: widget.showPet,
                    activity: widget.activity,
                    petPos: widget.petPos,
                    walkFrom: widget.walkFrom,
                    walkTo: widget.walkTo,
                    facingRight: widget.facingRight,
                    worldWidth: bgW,
                    worldHeight: viewportH,
                    idleBobController: widget.idleBobController,
                    squashController: widget.squashController,
                    jumpController: widget.jumpController,
                    walkController: widget.walkController,
                    sleepController: widget.sleepController,
                    eatController: widget.eatController,
                    hopController: widget.hopController,
                    spinController: widget.spinController,
                    bigJumpController: widget.bigJumpController,
                    bathController: widget.bathController,
                    onPetTap: widget.onPetTap,
                    onPetDragStart: widget.onPetDragStart,
                    onPetDragUpdate: widget.onPetDragUpdate,
                    onPetDragEnd: widget.onPetDragEnd,
                  ),
                ),
                // Gợi ý có thể kéo xem thêm, mờ dần rồi biến mất.
                if (maxCameraShift > 4)
                  Positioned(
                    right: 10,
                    top: viewportH * 0.45,
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1, end: 0),
                        duration: const Duration(seconds: 4),
                        builder: (context, value, child) =>
                            Opacity(opacity: value, child: child),
                        child: const Icon(Icons.swipe_rounded,
                            color: Colors.white70, size: 28),
                      ),
                    ),
                  ),
                // Thanh chỉ số: LUÔN cố định theo khung hình thật (không
                // nằm trong lớp world nên không bị kéo lệch theo camera),
                // và giới hạn chiều rộng tối đa để không bị giãn to trên
                // màn hình rộng.
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                  child: _MiniStat(
                                      icon: Icons.restaurant_rounded,
                                      value: widget.pet.hunger,
                                      color: AppColors.secondary)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _MiniStat(
                                      icon: Icons.bolt_rounded,
                                      value: widget.pet.energy,
                                      color: AppColors.info)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _MiniStat(
                                      icon: Icons.sentiment_satisfied_alt_rounded,
                                      value: widget.pet.happiness,
                                      color: AppColors.success)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _MiniStat(
                                      icon: Icons.clean_hands_rounded,
                                      value: widget.pet.hygiene,
                                      color: AppColors.gold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Toàn bộ nội dung 1 "thế giới phòng" (rộng hơn khung nhìn): ảnh nền,
/// lớp phủ tối, thanh chỉ số, và pet sprite với đầy đủ animation.
class _RoomWorld extends StatelessWidget {
  final PetModel pet;
  final RoomInfo room;
  final String backgroundAsset;
  final String? petThought;
  final bool showPet;
  final PetActivity activity;
  final Offset petPos;
  final Offset walkFrom;
  final Offset walkTo;
  final bool facingRight;
  final double worldWidth;
  final double worldHeight;
  final AnimationController idleBobController;
  final AnimationController squashController;
  final AnimationController jumpController;
  final AnimationController walkController;
  final AnimationController sleepController;
  final AnimationController eatController;
  final AnimationController hopController;
  final AnimationController spinController;
  final AnimationController bigJumpController;
  final AnimationController bathController;
  final VoidCallback onPetTap;
  final VoidCallback onPetDragStart;
  final void Function(Offset delta, double worldW, double worldH)
      onPetDragUpdate;
  final VoidCallback onPetDragEnd;

  const _RoomWorld({
    required this.pet,
    required this.room,
    required this.backgroundAsset,
    required this.petThought,
    required this.showPet,
    required this.activity,
    required this.petPos,
    required this.walkFrom,
    required this.walkTo,
    required this.facingRight,
    required this.worldWidth,
    required this.worldHeight,
    required this.idleBobController,
    required this.squashController,
    required this.jumpController,
    required this.walkController,
    required this.sleepController,
    required this.eatController,
    required this.hopController,
    required this.spinController,
    required this.bigJumpController,
    required this.bathController,
    required this.onPetTap,
    required this.onPetDragStart,
    required this.onPetDragUpdate,
    required this.onPetDragEnd,
  });

  static const _petSize = 110.0;
  bool get _isDirty => pet.hygiene < 40;

  // Bọt xà phòng trắng bao TRỌN quanh người pet khi tắm (dx/dy tính từ tâm
  // ô pet 110x110, dy đo từ mép trên).
  static const _foamSpots = [
    _FoamSpot(-32, 70, 48, 0.85),
    _FoamSpot(-5, 85, 58, 0.9),
    _FoamSpot(28, 68, 46, 0.85),
    _FoamSpot(-40, 40, 34, 0.75),
    _FoamSpot(38, 38, 32, 0.75),
    _FoamSpot(0, 20, 40, 0.8),
    _FoamSpot(-18, 95, 36, 0.8),
    _FoamSpot(18, 98, 38, 0.8),
    _FoamSpot(-45, 60, 28, 0.7),
    _FoamSpot(45, 58, 26, 0.7),
  ];

  // Bong bóng nổi lên phía trên đầu khi tắm — nhiều & lệch pha để lúc nào
  // cũng có vài bong bóng đang bay.
  static const _bubbleSpots = [
    _BubbleSpot(-16, 14, 16, 0.0),
    _BubbleSpot(30, 4, 12, 0.33),
    _BubbleSpot(6, 30, 20, 0.66),
    _BubbleSpot(-34, -6, 14, 0.15),
    _BubbleSpot(20, -14, 18, 0.5),
    _BubbleSpot(44, 20, 10, 0.8),
    _BubbleSpot(-46, 24, 12, 0.42),
    _BubbleSpot(0, -20, 22, 0.9),
  ];

  // Vệt bẩn (nâu) rải trên người khi pet dơ (hygiene < 40).
  static const _dirtSpots = [
    _DirtSpot(-30, 40, 14, 0.38),
    _DirtSpot(20, 60, 18, 0.34),
    _DirtSpot(-10, 90, 12, 0.36),
    _DirtSpot(35, 30, 10, 0.3),
    _DirtSpot(-40, 70, 10, 0.32),
    _DirtSpot(6, 15, 9, 0.3),
  ];

  // Ruồi bay vòng quanh vài điểm cố định trên người khi pet dơ.
  static const _flySpots = [
    _FlySpot(92, 8, 8, 0, 15),
    _FlySpot(-8, 52, 10, 2.1, 13),
    _FlySpot(60, 96, 7, 4.2, 12),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(backgroundAsset, fit: BoxFit.cover),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 140,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black45, Colors.transparent],
              ),
            ),
          ),
        ),
        if (showPet)
          AnimatedBuilder(
            animation: Listenable.merge([
              idleBobController,
              squashController,
              jumpController,
              walkController,
              sleepController,
              eatController,
              hopController,
              spinController,
              bigJumpController,
              bathController,
            ]),
            builder: (context, _) => _buildPet(petThought),
          ),
      ],
    );
  }

  /// 1 bong bóng xà phòng nổi lên và mờ dần theo pha [t] (0..1, lặp lại).
  /// [dx] lệch ngang so với tâm pet, [baseTop] là độ cao bắt đầu (âm = phía
  /// trên đầu pet).
  Widget _soapBubble(double t,
      {required double dx, required double baseTop, required double size}) {
    final rise = t * 42;
    double opacity;
    if (t < 0.15) {
      opacity = t / 0.15;
    } else if (t > 0.75) {
      opacity = (1 - t) / 0.25;
    } else {
      opacity = 1.0;
    }
    return Positioned(
      left: _petSize / 2 + dx,
      top: baseTop - rise,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text('🫧', style: TextStyle(fontSize: size)),
      ),
    );
  }

  Widget _buildPet(String? petThought) {
    // 1) Vị trí hiện tại theo hoạt động.
    Offset pos = petPos;
    if (activity == PetActivity.walking) {
      final t = Curves.easeInOut.transform(walkController.value);
      pos = Offset.lerp(walkFrom, walkTo, t)!;
    }
    final left = pos.dx * worldWidth - _petSize / 2;
    final top = pos.dy * worldHeight - _petSize / 2;

    // 2) translate dọc (bập bênh / bước chân / nhảy).
    double liftY = 0;
    switch (activity) {
      case PetActivity.idle:
      case PetActivity.turning:
      case PetActivity.spinning:
        liftY = sin(idleBobController.value * pi) * 5;
        break;
      case PetActivity.walking:
        liftY = sin(walkController.value * pi * 6).abs() * 8;
        break;
      case PetActivity.hopping:
      case PetActivity.bigJump:
      case PetActivity.bathing:
      case PetActivity.dragging:
      case PetActivity.sleeping:
      case PetActivity.eating:
      case PetActivity.toileting:
        liftY = 0;
        break;
      case PetActivity.playing:
        liftY = sin(hopController.value * pi) * 12;
        break;
    }
    // Nhảy nhẹ tại chỗ (đứng yên, không đổi vị trí ngang) khi rảnh.
    final hopT = activity == PetActivity.hopping ? hopController.value : 0.0;
    final hopLift = sin(hopT * pi) * 16;
    // Nhảy 1 đoạn cao tại chỗ khi rảnh (parabol lên rồi xuống, cao hơn hẳn).
    final bigJumpT =
        activity == PetActivity.bigJump ? bigJumpController.value : 0.0;
    final bigJumpLift = sin(bigJumpT * pi) * 55;
    // Cú nhảy khi chạm vào: parabol lên rồi xuống.
    final jumpT = jumpController.value;
    final jumpLift = sin(jumpT * pi) * 26;

    // 3) Bóp méo kiểu slime (squash & stretch).
    double scaleX = 1, scaleY = 1;
    if (activity == PetActivity.dragging) {
      scaleX = 0.92;
      scaleY = 1.08;
    }
    // Rơi bịch xuống sau khi thả tay: dẹt ngang rồi nảy lại bình thường.
    final squashT = squashController.value;
    if (squashT > 0 && squashT < 1) {
      final bounce = sin(squashT * pi); // 0 -> 1 -> 0
      scaleX *= 1 + bounce * 0.45;
      scaleY *= 1 - bounce * 0.35;
    }
    // Lắc chân khi nhảy (chạm vào pet).
    if (jumpT > 0 && jumpT < 1) {
      final wobble = sin(jumpT * pi);
      scaleX *= 1 - wobble * 0.12;
      scaleY *= 1 + wobble * 0.18;
    }
    // Lắc nhẹ khi nhảy tại chỗ lúc rảnh.
    if (hopT > 0 && hopT < 1) {
      final wobble = sin(hopT * pi);
      scaleX *= 1 - wobble * 0.08;
      scaleY *= 1 + wobble * 0.1;
    }
    // Vươn người rõ hơn khi nhảy 1 đoạn cao lúc rảnh.
    if (bigJumpT > 0 && bigJumpT < 1) {
      final wobble = sin(bigJumpT * pi);
      scaleX *= 1 - wobble * 0.15;
      scaleY *= 1 + wobble * 0.22;
    }
    // Thở phập phồng khi ngủ.
    if (activity == PetActivity.sleeping) {
      final breathe = sin(sleepController.value * pi);
      scaleX = 1.16;
      scaleY = 0.62 + breathe * 0.05;
    }
    // Nhai nhóp nhép khi ăn.
    if (activity == PetActivity.eating) {
      final chew = eatController.value;
      scaleX = 1 + chew * 0.08;
      scaleY = 1 - chew * 0.08;
    }
    // Rùng mình lắc nhẹ khi đang được kỳ cọ tắm rửa.
    final bathT = activity == PetActivity.bathing ? bathController.value : 0.0;
    if (bathT > 0) {
      final scrub = sin(bathT * pi * 2 * 3); // lắc qua lại vài lần / vòng lặp
      scaleX *= 1 + scrub * 0.05;
      scaleY *= 1 - scrub * 0.03;
    }

    // Ảnh gốc trong assets/pets vẽ pet quay mặt sang TRÁI theo mặc định,
    // nên khi facingRight = true (đang đi/quay sang phải) phải LẬT ảnh lại.
    final flip = facingRight ? -1.0 : 1.0;

    Widget sprite = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(scaleX * flip, scaleY),
      child: Image.asset(pet.idleAsset, fit: BoxFit.contain),
    );

    // Xoay vòng tại chỗ kiểu mèo đuổi đuôi.
    if (activity == PetActivity.spinning) {
      sprite = Transform.rotate(
        angle: spinController.value * 2 * pi,
        alignment: Alignment.center,
        child: sprite,
      );
    }

    // Lắc lư nhẹ như đang được kỳ cọ khi tắm.
    if (activity == PetActivity.bathing) {
      sprite = Transform.rotate(
        angle: sin(bathT * pi * 2 * 3) * 0.08,
        alignment: Alignment.center,
        child: sprite,
      );
    }

    if (activity == PetActivity.sleeping) {
      sprite = Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          sprite,
          Positioned(
            top: -22,
            child: Opacity(
              opacity: (0.4 + sleepController.value * 0.6).clamp(0.0, 1.0),
              child: const Text('💤', style: TextStyle(fontSize: 22)),
            ),
          ),
        ],
      );
    }

    if (activity == PetActivity.playing) {
      sprite = Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          sprite,
          const Positioned(
            top: -20,
            child: Text('🎾', style: TextStyle(fontSize: 21)),
          ),
        ],
      );
    }

    if (activity == PetActivity.toileting) {
      sprite = Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          sprite,
          const Positioned(
            top: -20,
            child: Text('🚽', style: TextStyle(fontSize: 20)),
          ),
        ],
      );
    }

    if (activity == PetActivity.eating) {
      sprite = Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          sprite,
          const Positioned(
            top: -18,
            child: Text('🍗', style: TextStyle(fontSize: 20)),
          ),
        ],
      );
    }

    if (activity == PetActivity.playing) {
      final pulse = 1 + sin(hopController.value * pi) * 0.05;
      sprite = Transform.scale(scale: pulse, child: sprite);
    }

    if (activity == PetActivity.bathing) {
      final pulse = 1 + sin(bathT * pi * 2 * 3) * 0.06;
      sprite = Stack(
        clipBehavior: Clip.none,
        children: [
          // Bọt xà phòng trắng bao TRỌN quanh người, phồng nhẹ theo nhịp kỳ cọ.
          for (final f in _foamSpots)
            Positioned(
              left: _petSize / 2 + f.dx - (f.size * pulse) / 2,
              top: f.dy - (f.size * pulse) / 2,
              child: Container(
                width: f.size * pulse,
                height: f.size * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: f.opacity),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: f.opacity * 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          sprite,
          // Bong bóng nổi lên phía trên, dày đặc hơn hẳn.
          for (final b in _bubbleSpots)
            _soapBubble(
              (bathT + b.phase) % 1.0,
              dx: b.dx,
              baseTop: b.baseTop,
              size: b.size,
            ),
        ],
      );
    }

    String? moodEmoji;
    if (activity == PetActivity.playing) {
      moodEmoji = '😍';
    } else if (activity == PetActivity.toileting) {
      moodEmoji = '😌';
    } else if (activity != PetActivity.sleeping &&
        activity != PetActivity.eating &&
        activity != PetActivity.bathing) {
      if (pet.toiletNeed >= 70) {
        moodEmoji = '😣';
      } else if (pet.hunger <= 35 || pet.energy <= 30) {
        moodEmoji = '😟';
      } else if (pet.hygiene <= 35) {
        moodEmoji = '😵';
      } else if (pet.playfulness <= 35) {
        moodEmoji = '🥺';
      } else if (pet.happiness >= 80) {
        moodEmoji = '😊';
      }
    }
    if (moodEmoji != null) {
      sprite = Stack(
        clipBehavior: Clip.none,
        children: [
          sprite,
          Positioned(
            top: -22,
            left: _petSize / 2 - 13,
            child: Text(moodEmoji, style: const TextStyle(fontSize: 22)),
          ),
        ],
      );
    }

    if (_isDirty && activity != PetActivity.sleeping) {
      // Mức độ dơ (0..1) — hygiene càng thấp thì đốm bẩn/lớp phủ càng đậm.
      final dirtSeverity = ((40 - pet.hygiene) / 40).clamp(0.0, 1.0);
      sprite = Stack(
        clipBehavior: Clip.none,
        children: [
          // Phủ 1 lớp màu nâu xỉn lên lông để nhìn rõ là đang dơ, không chỉ
          // dựa vào icon ruồi/bụi.
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFF6B4A2A)
                  .withValues(alpha: 0.25 + dirtSeverity * 0.25),
              BlendMode.srcATop,
            ),
            child: sprite,
          ),
          // Các vệt bẩn rải trên người.
          for (final d in _dirtSpots)
            Positioned(
              left: _petSize / 2 + d.dx - d.size / 2,
              top: d.dy - d.size / 2,
              child: Container(
                width: d.size,
                height: d.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF5B3A1E).withValues(alpha: d.opacity),
                ),
              ),
            ),
          // Ruồi bay vòng quanh nhiều điểm khác nhau trên người.
          for (final f in _flySpots)
            Positioned(
              left: f.baseLeft +
                  cos(idleBobController.value * pi * 2 + f.phase) * f.radius,
              top: f.baseTop +
                  sin(idleBobController.value * pi * 2 + f.phase) * f.radius,
              child: Text('🪰', style: TextStyle(fontSize: f.size)),
            ),
          // Bụi bốc lên ở 2 bên.
          Positioned(
            left: -8,
            top: 26 - sin(idleBobController.value * pi * 2) * 5,
            child: const Text('💨', style: TextStyle(fontSize: 13)),
          ),
          Positioned(
            right: -12,
            top: 64 + cos(idleBobController.value * pi * 2) * 5,
            child: const Text('💨', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }

    if (petThought != null && petThought!.isNotEmpty) {
      sprite = Stack(
        clipBehavior: Clip.none,
        children: [
          sprite,
          Positioned(
            left: -108,
            bottom: _petSize - 10,
            child: IgnorePointer(
              child: _PetThoughtBubble(text: petThought!),
            ),
          ),
          Positioned(
            left: 8,
            bottom: _petSize - 22,
            child: IgnorePointer(
              child: _ThoughtDot(size: 10),
            ),
          ),
          Positioned(
            left: 19,
            bottom: _petSize - 31,
            child: IgnorePointer(
              child: _ThoughtDot(size: 6),
            ),
          ),
        ],
      );
    }

    return Positioned(
      left: left,
      top: top - jumpLift - liftY - hopLift - bigJumpLift,
      width: _petSize,
      height: _petSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPetTap,
        onPanStart: (_) => onPetDragStart(),
        onPanUpdate: (details) =>
            onPetDragUpdate(details.delta, worldWidth, worldHeight),
        onPanEnd: (_) => onPetDragEnd(),
        child: sprite,
      ),
    );
  }
}

/// 1 đốm bẩn (vệt nâu) cố định trên người pet khi dơ.
class _DirtSpot {
  final double dx, dy, size, opacity;
  const _DirtSpot(this.dx, this.dy, this.size, this.opacity);
}

/// 1 con ruồi bay vòng quanh 1 điểm cố định trên người pet khi dơ.
class _FlySpot {
  final double baseLeft, baseTop, radius, phase, size;
  const _FlySpot(
      this.baseLeft, this.baseTop, this.radius, this.phase, this.size);
}

/// 1 mảng bọt xà phòng trắng (tĩnh, hơi phồng theo nhịp) bao quanh pet.
class _FoamSpot {
  final double dx, dy, size, opacity;
  const _FoamSpot(this.dx, this.dy, this.size, this.opacity);
}

/// 1 bong bóng xà phòng nổi lên và biến mất, lệch pha với các bong bóng khác.
class _BubbleSpot {
  final double dx, baseTop, size, phase;
  const _BubbleSpot(this.dx, this.baseTop, this.size, this.phase);
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  const _MiniStat(
      {required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$value',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

/// Bàn ăn — hiện tối đa 3 món đồ ăn đã mua cùng lúc, bấm mũi tên trái/phải
/// để xem các món còn lại. Kéo 1 món lên phía trên (khu vực pet) để cho ăn
/// — món ăn sẽ đi theo đúng vị trí con trỏ chuột trong lúc kéo (hành vi có
/// sẵn của [Draggable]), giống cách cho ăn trong game Talking Tom.
class _FoodTablePanel extends StatelessWidget {
  final List<FoodTemplate> ownedFoods;
  final int pageStart;
  final VoidCallback? onPageLeft;
  final VoidCallback? onPageRight;
  final VoidCallback onClose;
  final VoidCallback onGoShopping;

  const _FoodTablePanel({
    required this.ownedFoods,
    required this.pageStart,
    required this.onPageLeft,
    required this.onPageRight,
    required this.onClose,
    required this.onGoShopping,
  });

  @override
  Widget build(BuildContext context) {
    final visible = ownedFoods.skip(pageStart).take(3).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF3E2723), // màu gỗ bàn ăn
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('🍽️ Bàn ăn',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    onPressed: onClose,
                    tooltip: tr('Đóng bàn ăn'),
                  ),
                ],
              ),
              Expanded(
                child: ownedFoods.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Bạn chưa có đồ ăn nào!',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: onGoShopping,
                              child: const Text('Mua đồ ăn ở Cửa hàng 🛒'),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left,
                                color: Colors.white),
                            onPressed: onPageLeft,
                          ),
                          Expanded(
                            child: Row(
                              children: List.generate(3, (i) {
                                if (i >= visible.length)
                                  return const Expanded(child: SizedBox());
                                return Expanded(
                                    child: _FoodSlot(food: visible[i]));
                              }),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right,
                                color: Colors.white),
                            onPressed: onPageRight,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodSlot extends StatelessWidget {
  final FoodTemplate food;
  const _FoodSlot({required this.food});

  @override
  Widget build(BuildContext context) {
    final content = _FoodSlotContent(food: food);
    return Center(
      child: Draggable<FoodTemplate>(
        data: food,
        feedback: Material(
          color: Colors.transparent,
          child: Image.asset(food.assetPath, width: 76, height: 76),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: content),
        child: content,
      ),
    );
  }
}

class _FoodSlotContent extends StatelessWidget {
  final FoodTemplate food;
  const _FoodSlotContent({required this.food});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(food.assetPath, width: 56, height: 56, fit: BoxFit.contain),
        const SizedBox(height: 4),
        Text(
          food.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Khay dụng cụ tắm — 2 món kéo-thả: xà phòng (chà nổi bọt) và vòi nước
/// (xịt rửa, chỉ dùng được khi đã đủ bọt). Không dùng ảnh riêng (chưa có
/// asset), dùng emoji cho gọn và không lo thiếu file ảnh.
class _BathToolsPanel extends StatelessWidget {
  final int soapCount;
  final int requiredScrubs;
  final bool soapReady;
  final bool hoseReady;
  final VoidCallback onClose;

  const _BathToolsPanel({
    required this.soapCount,
    required this.requiredScrubs,
    required this.soapReady,
    required this.hoseReady,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B4965), // xanh nước biển, gợi nhà tắm
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    soapReady
                        ? '🧼 Kéo xà phòng chà lên pet ($soapCount/$requiredScrubs)'
                        : '🚿 Đủ bọt rồi! Kéo vòi nước xịt rửa nào',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    onPressed: onClose,
                    tooltip: tr('Đóng'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BathTool(
                      emoji: '🧼',
                      label: 'Xà phòng',
                      data: 'soap',
                      enabled: soapReady,
                    ),
                    _BathTool(
                      emoji: '🚿',
                      label: 'Vòi nước',
                      data: 'hose',
                      enabled: hoseReady,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1 dụng cụ kéo-thả (xà phòng hoặc vòi nước) trong khay tắm. Khi chưa
/// dùng được ([enabled] = false) thì hiển thị mờ đi và không kéo được,
/// tránh học sinh xịt nước trước khi đủ bọt.
class _BathTool extends StatelessWidget {
  final String emoji;
  final String label;
  final String data;
  final bool enabled;

  const _BathTool({
    required this.emoji,
    required this.label,
    required this.data,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );

    if (!enabled) {
      return Opacity(opacity: 0.3, child: content);
    }

    return Draggable<String>(
      data: data,
      feedback: Material(
        color: Colors.transparent,
        child: Text(emoji, style: const TextStyle(fontSize: 56)),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: content),
      child: content,
    );
  }
}

/// Pet phóng to nổi bật trong cảnh tắm — hiện lớp bọt xà phòng tăng dần
/// theo số lần đã chà, và hiệu ứng nước bắn tung toé khi đang xịt rửa.
class _BathSpotlightPet extends StatelessWidget {
  final PetModel pet;
  final Animation<double> idleBobController;
  final Animation<double> bathController;
  final int soapCount;
  final int requiredScrubs;
  final bool isRinsing;

  const _BathSpotlightPet({
    required this.pet,
    required this.idleBobController,
    required this.bathController,
    required this.soapCount,
    required this.requiredScrubs,
    required this.isRinsing,
  });

  static const _size = 260.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([idleBobController, bathController]),
      builder: (context, _) {
        final bob = sin(idleBobController.value * pi) * 8;
        // Mỗi lần chà xà phòng, bathController chạy 1 nhịp 0→1 khiến bọt
        // "phù" phồng lên rồi lắng xuống nhẹ — pop hiệu ứng cho vui mắt.
        final popScale = isRinsing ? 1.0 : 1 + sin(bathController.value * pi) * 0.15;
        return SizedBox(
          width: _size,
          height: _size + 40,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, -bob),
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child:
                      Image.asset(pet.idleAsset, fit: BoxFit.contain),
                ),
              ),
              // Bọt xà phòng — số lượng bong bóng tăng dần theo soapCount,
              // mờ dần đi khi đang xịt rửa (isRinsing).
              if (soapCount > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: isRinsing ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 900),
                      child: Transform.scale(
                        scale: popScale,
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4,
                            children: List.generate(
                              soapCount * 3,
                              (i) => Text(
                                '🫧',
                                style: TextStyle(
                                    fontSize: 16 + (i % 3) * 6.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Hiệu ứng nước xịt khi đang rửa.
              if (isRinsing)
                const Positioned(
                  top: -6,
                  child: Text('💦💦💦', style: TextStyle(fontSize: 28)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Hiệu ứng vụn đồ ăn rơi xuống khi pet đang nhai — tự chạy 1 lần khi được
/// dựng lên, không cần AnimationController riêng.
/// Pet phóng to hiển thị nổi bật khi ngồi vào bàn ăn — thay cho việc chỉ
/// nhìn thấy pet mờ nhạt phía sau lớp blur. Có nhịp bập bênh nhẹ lúc rảnh,
/// và lắc nhóp nhép + hiệu ứng vụn bánh/poof ngay trên người khi đang ăn.
class _FeedingSpotlightPet extends StatelessWidget {
  final PetModel pet;
  final bool isEating;
  final Animation<double> idleBobController;
  final Animation<double> eatController;
  final bool showCrumbs;
  final bool showPoof;

  const _FeedingSpotlightPet({
    required this.pet,
    required this.isEating,
    required this.idleBobController,
    required this.eatController,
    required this.showCrumbs,
    required this.showPoof,
  });

  static const _size = 260.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([idleBobController, eatController]),
      builder: (context, _) {
        final bob = isEating
            ? 0.0
            : sin(idleBobController.value * pi) * 8; // bập bênh khi rảnh
        final chew = isEating ? eatController.value : 0.0;
        final scaleX = 1 + chew * 0.08;
        final scaleY = 1 - chew * 0.08;
        return SizedBox(
          width: _size,
          height: _size + 40,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, -bob),
                child: Transform.scale(
                  scaleX: scaleX,
                  scaleY: scaleY,
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child:
                        Image.asset(pet.idleAsset, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (isEating)
                const Positioned(
                  top: -6,
                  child: Text('🍗', style: TextStyle(fontSize: 32)),
                ),
              if (showCrumbs)
                const Positioned(bottom: 30, child: _CrumbEffect()),
              if (showPoof) const Positioned(top: 40, child: _PoofEffect()),
            ],
          ),
        );
      },
    );
  }
}

class _CrumbEffect extends StatelessWidget {
  const _CrumbEffect();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1200),
        builder: (context, t, child) {
          return Opacity(
            opacity: 1 - t,
            child: Transform.translate(
              offset: Offset(0, t * 36),
              child: const Text('🍞 ✨ 🍞', style: TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }
}

/// Hiệu ứng "biến mất" khi món ăn được đưa cho pet thành công.
class _PoofEffect extends StatelessWidget {
  const _PoofEffect();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (context, t, child) {
          return Opacity(
            opacity: 1 - t,
            child: Transform.scale(
              scale: 0.6 + t * 0.8,
              child: const Text('💨 ✨', style: TextStyle(fontSize: 30)),
            ),
          );
        },
      ),
    );
  }
}

/// Thanh tiền tệ nhỏ dành riêng cho Nhà pet giáo viên.
/// Chỉ giữ emoji và số để không che phần căn phòng phía sau.
class _TeacherCurrencyBar extends StatelessWidget {
  final StudentModel student;

  const _TeacherCurrencyBar({required this.student});

  @override
  Widget build(BuildContext context) {
    final gemText = student.gemInfinite ? '∞' : '${student.gem}';
    final coinText = student.coinInfinite ? '∞' : '${student.coin}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeacherCurrencyPill(
            icon: '💎',
            value: gemText,
            color: const Color(0xFF59C3E3),
          ),
          const SizedBox(width: 5),
          _TeacherCurrencyPill(
            icon: '🪙',
            value: coinText,
            color: const Color(0xFFFFB84D),
          ),
        ],
      ),
    );
  }
}

class _TeacherCurrencyPill extends StatelessWidget {
  final String icon;
  final String value;
  final Color color;

  const _TeacherCurrencyPill({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmojiIcon(icon, size: 22),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cột tiện ích icon-only dành cho giáo viên.
/// Cả Phòng đổi skin và Đổi nhà được đặt cùng cột với ba tiện ích chính.
class _TeacherQuickMenu extends StatelessWidget {
  final VoidCallback onWardrobe;
  final VoidCallback onChangeHouse;

  const _TeacherQuickMenu({
    required this.onWardrobe,
    required this.onChangeHouse,
  });

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeacherIconButton(
            emoji: '🛒',
            tooltip: tr('Cửa hàng'),
            onTap: () => _open(context, const ShopScreen()),
          ),
          const SizedBox(height: 7),
          _TeacherIconButton(
            emoji: '🎮',
            tooltip: tr('Mini game — chơi để kiếm xu'),
            onTap: () => _open(context, const MiniGameHubScreen()),
          ),
          const SizedBox(height: 7),
          _TeacherIconButton(
            emoji: '🏆',
            tooltip: tr('Bảng xếp hạng'),
            onTap: () => _open(context, const LeaderboardScreen()),
          ),
          const SizedBox(height: 7),
          _TeacherIconButton(
            emoji: '👕',
            tooltip: tr('Phòng đổi skin'),
            onTap: onWardrobe,
          ),
          const SizedBox(height: 7),
          _TeacherIconButton(
            emoji: '🏠',
            tooltip: tr('Đổi nhà'),
            onTap: onChangeHouse,
          ),
        ],
      ),
    );
  }
}

class _TeacherIconButton extends StatelessWidget {
  final String emoji;
  final String tooltip;
  final VoidCallback onTap;

  const _TeacherIconButton({
    required this.emoji,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: EmojiIcon(emoji, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

class _PetThoughtBubble extends StatelessWidget {
  final String text;

  const _PetThoughtBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(text),
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF333344),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Icon thanh chọn phòng / nút hành động theo loại phòng (Material icons đồng
/// bộ, vì icon.zip không có icon giường/bồn tắm/bàn ăn).
IconData _roomIcon(RoomType type) {
  switch (type) {
    case RoomType.bedroom:
      return Icons.bed_rounded;
    case RoomType.bathroom:
      return Icons.bathtub_rounded;
    case RoomType.dining:
      return Icons.restaurant_rounded;
  }
}

IconData _roomActionIcon(RoomType type) {
  switch (type) {
    case RoomType.bedroom:
      return Icons.bedtime_rounded;
    case RoomType.bathroom:
      return Icons.shower_rounded;
    case RoomType.dining:
      return Icons.restaurant_menu_rounded;
  }
}

class _HouseQuickActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  const _HouseQuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black12,
        disabledForegroundColor: Colors.black38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _ThoughtDot extends StatelessWidget {
  final double size;

  const _ThoughtDot({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}