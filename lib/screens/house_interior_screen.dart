import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';
import '../l10n/tr.dart';
import '../models/food_catalog.dart';
import '../models/house_catalog.dart';
import '../models/house_decor_catalog.dart';
import '../models/house_quest_catalog.dart';
import '../models/item_model.dart';
import '../models/pet_activity_catalog.dart';
import '../models/pet_model.dart';
import '../models/room_data.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../services/house_extras_service.dart';
import '../theme/app_theme.dart';
import '../widgets/emoji_icon.dart';
import '../widgets/friendship_widgets.dart';
import '../widgets/house/house_ambience.dart';
import '../widgets/house/house_hud.dart';
import '../widgets/house/house_overlays.dart';
import '../widgets/house/house_panels.dart';
import '../widgets/house/house_pet_sprite.dart';
import '../widgets/pet_care_dock.dart' show MenuTile, PetActivitiesSheet;
import '../widgets/skin_room_sheet.dart';
import '../widgets/tr_text.dart';
import 'leaderboard_screen.dart';
import 'minigame_hub_screen.dart';
import 'pet_library_screen.dart';
import 'shop_screen.dart';
import 'skin_box_screen.dart';

/// Nhà của pet (bản mới): 3 phòng (Phòng ngủ / Nhà tắm / Phòng ăn), pet 2D
/// tự đi dạo, chạm để vuốt ve, kéo thả được.
///
/// Điểm mới so với bản cũ:
///  • Giao diện gọn: 1 thẻ trạng thái + dock 6 nút + cột tiện ích bên phải.
///  • Chăm sóc nhanh: banner gợi ý việc cấp bách nhất, bấm là pet làm luôn.
///  • Nhiệm vụ hằng ngày có thưởng Coin + Rương cuối ngày.
///  • Trang trí phòng bằng nội thất (mua bằng Coin, kéo thả sắp xếp).
///  • Thời tiết (nắng/mây/mưa) và ngày–đêm sinh động theo giờ game.
///  • Cơ chế gọn hơn: chạm món để cho ăn; tắm bằng cách xoa lên pet.
class HouseInteriorScreen extends StatefulWidget {
  final bool teacherMode;

  const HouseInteriorScreen({super.key, this.teacherMode = false});

  @override
  State<HouseInteriorScreen> createState() => _HouseInteriorScreenState();
}

class _HouseInteriorScreenState extends State<HouseInteriorScreen>
    with TickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _extrasService = HouseExtrasService();
  final _random = Random();
  final ValueNotifier<HouseExtras> _extras =
      ValueNotifier<HouseExtras>(const HouseExtras());
  final ValueNotifier<double> _sleepProgress = ValueNotifier<double>(0);

  late final AnimationController _bob; // thở/bập bênh nhẹ
  late final AnimationController _loop; // nhịp hành động lặp
  late final AnimationController _jump; // nhảy khi chạm
  late final AnimationController _squash; // nảy bịch khi thả tay
  late final AnimationController _sky; // mây, mưa, sao

  // ---------- Trạng thái nhà ----------
  int _roomIndex = 0;
  bool _busy = false;
  HousePetActivity _activity = HousePetActivity.idle;
  Offset _petPos = const Offset(0.5, 0.62); // tỉ lệ 0..1 trong sân khấu phòng
  bool _facingRight = true;
  Duration _walkDuration = Duration.zero;
  Size _stage = Size.zero;
  String? _thought;
  String? _uid;

  // Bảng/lớp phủ đang mở.
  bool _showFoodTray = false;
  bool _showBath = false;
  double _bathProgress = 0;
  bool _bathRinsing = false;
  bool _decorMode = false;
  bool _sleeping = false;

  // Bộ đếm/Timer.
  Timer? _idleTimer;
  Timer? _walkTimer;
  Timer? _thoughtTimer;
  Timer? _clockTimer;
  Timer? _refreshTimer;
  int _token = 0; // hủy các việc rảnh rỗi đang dở khi có hành động mới
  int _sleepToken = 0;
  int _tapCount = 0;
  int _patBuffer = 0;
  final Set<int> _visitedRooms = {0};
  bool _roomsQuestSent = false;
  bool _refreshingPet = false;

  // ---------- Đồng hồ game: 1 ngày game (24 giờ) = 15 phút thật ----------
  static const Duration _gameDurationPerDay = Duration(hours: 24);
  static const int _gameSpeed = 96;
  static final DateTime _gameEpoch = DateTime(2026, 1, 1);
  Duration _gameTimeOffset = Duration.zero;
  DateTime _gameNow = DateTime.now();
  HouseWeather _weather = HouseWeatherInfo.now();

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
    var forward = morningMicros - currentPosition;
    if (forward <= 0) forward += dayMicros;
    _gameTimeOffset += Duration(microseconds: forward);
    _gameNow = _gameClockFromReal(DateTime.now());
  }

  bool get _isNight => _gameNow.hour >= 19 || _gameNow.hour < 5;
  double get _hourFraction => _gameNow.hour + _gameNow.minute / 60.0;
  String get _gameTimeLabel =>
      '${_gameNow.hour.toString().padLeft(2, '0')}:${_gameNow.minute.toString().padLeft(2, '0')}';
  RoomInfo get _room => kRooms[_roomIndex];

  // ---------- Vòng đời ----------

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _loop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _jump = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _squash = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _sky = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat();

    _gameNow = _gameClockFromReal(DateTime.now());
    _extras.addListener(_onExtrasChanged);
    _restartIdleTimer();

    _clockTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final next = _gameClockFromReal(DateTime.now());
      final w = HouseWeatherInfo.now();
      if (next.minute != _gameNow.minute ||
          next.hour != _gameNow.hour ||
          w != _weather) {
        setState(() {
          _gameNow = next;
          _weather = w;
        });
      }
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted || _refreshingPet) return;
      _refreshingPet = true;
      try {
        await context.read<PetProvider>().refreshPetNow();
      } finally {
        _refreshingPet = false;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Mở thẳng từ cổng giáo viên thì tự kết nối hồ sơ pet.
      final petId = context.read<AuthProvider>().currentStudent?.petId;
      if (petId != null) context.read<PetProvider>().watchPet(petId);
      _loadExtras();
    });
  }

  @override
  void dispose() {
    _flushPats();
    _idleTimer?.cancel();
    _walkTimer?.cancel();
    _thoughtTimer?.cancel();
    _clockTimer?.cancel();
    _refreshTimer?.cancel();
    _extras.removeListener(_onExtrasChanged);
    _extras.dispose();
    _sleepProgress.dispose();
    _bob.dispose();
    _loop.dispose();
    _jump.dispose();
    _squash.dispose();
    _sky.dispose();
    super.dispose();
  }

  void _onExtrasChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadExtras() async {
    final uid = context.read<AuthProvider>().currentStudent?.uid;
    if (uid == null) return;
    _uid = uid;
    try {
      final ex = await _extrasService.load(uid);
      if (mounted) _extras.value = ex;
    } catch (_) {
      // Không tải được nội thất/nhiệm vụ thì nhà vẫn chơi bình thường.
    }
  }

  /// Chỉ làm mới phần nhiệm vụ (giữ nguyên nội thất đang chỉnh ở máy này).
  Future<void> _refreshQuests() async {
    final uid = _uid;
    if (uid == null || !mounted) return;
    try {
      final fresh = await _extrasService.load(uid);
      if (!mounted) return;
      _extras.value = _extras.value.copyWith(
        questDate: fresh.questDate,
        questProgress: fresh.questProgress,
        questClaimed: fresh.questClaimed,
        bonusClaimed: fresh.bonusClaimed,
      );
    } catch (_) {}
  }

  void _bump(String questId, {int by = 1}) {
    final uid = _uid;
    if (uid == null) return;
    _extrasService
        .bumpQuest(uid, questId, by: by)
        .then((_) => _refreshQuests())
        .catchError((Object _) {});
  }

  void _flushPats() {
    final uid = _uid;
    if (uid == null || _patBuffer <= 0) return;
    final n = _patBuffer;
    _patBuffer = 0;
    _extrasService
        .bumpQuest(uid, HouseQuestCatalog.pat, by: n)
        .catchError((Object _) {});
  }

  // ---------- Tiện ích chung ----------

  void _setActivity(HousePetActivity a) {
    if (!mounted) return;
    setState(() => _activity = a);
    const looping = {
      HousePetActivity.walking,
      HousePetActivity.hopping,
      HousePetActivity.spinning,
      HousePetActivity.eating,
      HousePetActivity.playing,
    };
    if (looping.contains(a)) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
      _loop.value = 0;
    }
  }

  void _setThought(String text,
      {Duration visibleFor = const Duration(seconds: 4)}) {
    if (!mounted) return;
    _thoughtTimer?.cancel();
    setState(() => _thought = text);
    _thoughtTimer = Timer(visibleFor, () {
      if (mounted) setState(() => _thought = null);
    });
  }

  void _showMessage(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 190),
      duration: const Duration(seconds: 3),
    ));
  }

  bool get _overlayOpen => _showFoodTray || _showBath || _sleeping;

  // ---------- Pet đi dạo / chơi một mình ----------

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 7), _tryWander);
  }

  Offset _randomSpot() => Offset(
        0.14 + _random.nextDouble() * 0.72,
        0.38 + _random.nextDouble() * 0.46,
      );

  void _tryWander() {
    if (!mounted) return;
    if (_activity != HousePetActivity.idle ||
        _busy ||
        _decorMode ||
        _overlayOpen) {
      _restartIdleTimer();
      return;
    }
    final pet = context.read<PetProvider>().pet;
    final roll = _random.nextInt(10);
    if (roll < 3 && pet != null) {
      _setThought(_ambientThought(pet));
      _restartIdleTimer();
    } else if (roll < 7) {
      _walkTo(_randomSpot());
    } else if (roll < 8) {
      _timedIdleAction(HousePetActivity.hopping,
          Duration(milliseconds: 700 * (1 + _random.nextInt(3))));
    } else if (roll < 9) {
      _timedIdleAction(
          HousePetActivity.spinning, Duration(seconds: 1 + _random.nextInt(2)));
    } else {
      _turnAround();
    }
  }

  /// Đi bộ tới [target]; chạy [onArrive] khi tới nơi (dùng cho "đi tới
  /// phòng rồi mới ăn/tắm/ngủ").
  void _walkTo(Offset target, {VoidCallback? onArrive}) {
    if (!mounted) return;
    ++_token;
    _walkTimer?.cancel();
    final dx = (target.dx - _petPos.dx) * _stage.width;
    final dy = (target.dy - _petPos.dy) * _stage.height;
    final dist = sqrt(dx * dx + dy * dy);
    final ms = (500 + dist * 3.2).clamp(500.0, 3200.0).round();
    setState(() {
      _facingRight = target.dx >= _petPos.dx;
      _walkDuration = Duration(milliseconds: ms);
      _petPos = target;
    });
    _setActivity(HousePetActivity.walking);
    _walkTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _walkDuration = Duration.zero);
      _setActivity(HousePetActivity.idle);
      if (onArrive != null) {
        onArrive();
      } else {
        _restartIdleTimer();
      }
    });
  }

  Future<void> _timedIdleAction(HousePetActivity a, Duration d) async {
    final t = ++_token;
    _setActivity(a);
    await Future.delayed(d);
    if (!mounted || t != _token) return;
    _setActivity(HousePetActivity.idle);
    _restartIdleTimer();
  }

  Future<void> _turnAround() async {
    final t = ++_token;
    final times = 1 + _random.nextInt(3);
    for (var i = 0; i < times; i++) {
      if (!mounted || t != _token) return;
      setState(() => _facingRight = !_facingRight);
      await Future.delayed(const Duration(milliseconds: 450));
    }
    if (!mounted || t != _token) return;
    _restartIdleTimer();
  }

  // ---------- Chạm / kéo thả pet ----------

  void _onPetTap() {
    if (_busy || _activity != HousePetActivity.idle || _decorMode) return;
    _restartIdleTimer();
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
    _setThought(lines[_tapCount % lines.length]);
    _jump.forward(from: 0);
    _patBuffer++;
    if (_patBuffer >= 5) _flushPats();
  }

  void _onDragStart() {
    if (_activity != HousePetActivity.idle || _busy || _decorMode) return;
    _idleTimer?.cancel();
    _walkDuration = Duration.zero;
    _setActivity(HousePetActivity.dragging);
  }

  void _onDragUpdate(Offset delta) {
    if (_activity != HousePetActivity.dragging || _stage.isEmpty) return;
    setState(() {
      _petPos = Offset(
        (_petPos.dx + delta.dx / _stage.width).clamp(0.08, 0.92).toDouble(),
        (_petPos.dy + delta.dy / _stage.height).clamp(0.2, 0.95).toDouble(),
      );
    });
  }

  void _onDragEnd() {
    if (_activity != HousePetActivity.dragging) return;
    _setActivity(HousePetActivity.idle);
    _squash.forward(from: 0);
    _restartIdleTimer();
  }

  // ---------- Đổi phòng & đi tới phòng rồi mới làm ----------

  void _selectRoom(int i) {
    if (i == _roomIndex || _sleeping || _showBath) return;
    _walkTimer?.cancel();
    ++_token;
    setState(() {
      _roomIndex = i;
      _petPos = _randomSpot();
      _walkDuration = Duration.zero;
      _showFoodTray = false;
    });
    if (_activity == HousePetActivity.walking ||
        _activity == HousePetActivity.hopping ||
        _activity == HousePetActivity.spinning) {
      _setActivity(HousePetActivity.idle);
    }
    _visitedRooms.add(i);
    if (!_roomsQuestSent && _visitedRooms.length >= kRooms.length) {
      _roomsQuestSent = true;
      _bump(HouseQuestCatalog.rooms, by: kRooms.length);
    }
    _restartIdleTimer();
  }

  /// Sang phòng [type] (nếu đang ở phòng khác), đi bộ tới 1 điểm rồi làm
  /// [action].
  void _goRoomThenAct(RoomType type, VoidCallback action, {Offset? spot}) {
    if (_busy || _sleeping) return;
    if (_decorMode) {
      _showMessage('Bấm "Xong" để thoát chế độ trang trí trước nhé!');
      return;
    }
    if (_activity == HousePetActivity.dragging) return;
    final idx = kRooms.indexWhere((r) => r.type == type);
    if (idx < 0) return;
    _idleTimer?.cancel();
    if (idx != _roomIndex) _selectRoom(idx);
    _walkTo(spot ?? _randomSpot(), onArrive: action);
  }

  // ---------- Ăn ----------

  void _onFeedPressed() => _goRoomThenAct(
        RoomType.dining,
        () {
          if (mounted) setState(() => _showFoodTray = true);
        },
        spot: const Offset(0.5, 0.36),
      );

  Future<void> _feed(FoodTemplate food) async {
    final auth = context.read<AuthProvider>();
    final pet = context.read<PetProvider>().pet;
    final student = auth.currentStudent;
    if (pet == null || student == null || _busy) return;
    if ((student.foodInventory[food.id] ?? 0) < 1) {
      _showMessage('Bạn đã hết "${food.name}" rồi, hãy mua thêm ở Cửa hàng!');
      return;
    }
    setState(() {
      _busy = true;
      _showFoodTray = false;
    });
    _idleTimer?.cancel();
    _setActivity(HousePetActivity.eating);
    _setThought('Ngon quá đi! 😋', visibleFor: const Duration(seconds: 3));
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    try {
      final ok = await _firestoreService.feedPetWithFood(
        studentId: student.uid,
        petId: pet.id,
        foodId: food.id,
        hungerRestore: food.hungerRestore,
        expReward: food.expReward,
      );
      if (ok) {
        await auth.refreshCurrentStudent();
        await _firestoreService.addPetAffection(
            pet.id, FirestoreService.feedAffectionGain);
        _bump(HouseQuestCatalog.feed);
        _showMessage('Pet đã ăn "${food.name}" ngon lành! +${food.expReward} EXP 🍽️');
      } else {
        _showMessage('Bạn đã hết "${food.name}" rồi!');
      }
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      _endBusy();
    }
  }

  void _endBusy() {
    if (!mounted) return;
    setState(() => _busy = false);
    _setActivity(HousePetActivity.idle);
    _restartIdleTimer();
  }

  // ---------- Tắm: xoa lên pet cho nổi bọt, rồi xả nước ----------

  void _onBathePressed() => _goRoomThenAct(RoomType.bathroom, () {
        if (!mounted) return;
        setState(() {
          _showBath = true;
          _bathProgress = 0;
          _bathRinsing = false;
        });
      });

  void _onScrub(double distance) {
    if (_bathRinsing || _bathProgress >= 1) return;
    setState(() => _bathProgress =
        (_bathProgress + distance / 700).clamp(0.0, 1.0).toDouble());
    if (_bathProgress >= 1) _rinse();
  }

  Future<void> _rinse() async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _bathRinsing) return;
    setState(() => _bathRinsing = true);
    _loop.repeat();
    await Future.delayed(const Duration(milliseconds: 1400));
    _loop.stop();
    _loop.value = 0;
    if (!mounted) return;
    try {
      await _firestoreService.bathePet(pet.id);
      await _firestoreService.addPetAffection(
          pet.id, FirestoreService.batheAffectionGain);
      _bump(HouseQuestCatalog.bathe);
      _jump.forward(from: 0);
      _setThought('Thơm tho sạch sẽ rồi! 🫧');
      _showMessage('Pet sạch sẽ thơm tho rồi! 🛁 +${FirestoreService.batheAffectionGain} Thân thiết');
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() {
          _showBath = false;
          _bathRinsing = false;
          _bathProgress = 0;
        });
      }
      _restartIdleTimer();
    }
  }

  void _closeBath() {
    if (_bathRinsing) return;
    setState(() {
      _showBath = false;
      _bathProgress = 0;
    });
    _restartIdleTimer();
  }

  // ---------- Ngủ ----------

  void _onSleepPressed() => _goRoomThenAct(RoomType.bedroom, _sleep);

  Future<void> _sleep() async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _busy) return;
    if (!_isNight) {
      _setThought('Ban ngày mình chưa buồn ngủ. Tối mình sẽ ngủ nhé! ☀️');
      _showMessage('Pet chỉ có thể ngủ vào buổi tối của giờ game (19:00–05:00).');
      _restartIdleTimer();
      return;
    }
    if (pet.energy >= 100) {
      _showMessage('Pet đã đầy Năng lượng, không cần ngủ nữa!');
      _restartIdleTimer();
      return;
    }
    final token = ++_sleepToken;
    _idleTimer?.cancel();
    _thoughtTimer?.cancel();
    setState(() {
      _busy = true;
      _sleeping = true;
      _thought = null;
    });
    _sleepProgress.value = 0;
    _setActivity(HousePetActivity.sleeping);
    const steps = 150; // 150 x 100ms = 15 giây
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || token != _sleepToken) return; // bị hủy ("Dậy thôi")
      _sleepProgress.value = i / steps;
    }
    try {
      await _firestoreService.sleepPet(pet.id);
      await _firestoreService.addPetAffection(
          pet.id, FirestoreService.sleepAffectionGain);
      if (mounted) {
        await context.read<AuthProvider>().refreshCurrentStudent();
      }
      if (mounted) {
        setState(() => _wakeGameAtMorning());
        _setThought('Chào buổi sáng! Mình đã ngủ đủ rồi! ☀️');
      }
      _showMessage('Pet đã thức dậy lúc 05:00, Năng lượng đã hồi 100! +10 EXP ☀️');
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted && token == _sleepToken) {
        setState(() => _sleeping = false);
        _endBusy();
      }
    }
  }

  /// "Dậy thôi": hủy giấc ngủ giữa chừng (không được hồi Năng lượng).
  void _wakeEarly() {
    if (!_sleeping) return;
    _sleepToken++;
    _sleepProgress.value = 0;
    setState(() => _sleeping = false);
    _setThought('Mình chưa ngủ đủ giấc… 🥱');
    _endBusy();
  }

  // ---------- Vệ sinh / Chơi / Hoạt động ----------

  Future<void> _useToilet() async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _busy || _sleeping) return;
    if (_decorMode) {
      _showMessage('Bấm "Xong" để thoát chế độ trang trí trước nhé!');
      return;
    }
    if (pet.toiletNeed < 20) {
      _setThought('Mình chưa cần đi vệ sinh đâu! 😊');
      return;
    }
    _idleTimer?.cancel();
    setState(() => _busy = true);
    _setActivity(HousePetActivity.toileting);
    _setThought('Mình đi vệ sinh một chút nhé… 🚽',
        visibleFor: const Duration(seconds: 3));
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      await _firestoreService.useToilet(pet.id);
      _setThought('Thoải mái hơn nhiều rồi! 🌟');
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      _endBusy();
    }
  }

  Future<void> _playWithPet() async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _busy || _sleeping) return;
    if (_decorMode) {
      _showMessage('Bấm "Xong" để thoát chế độ trang trí trước nhé!');
      return;
    }
    if (pet.energy <= 15) {
      _setThought('Mình hơi mệt rồi, cho mình nghỉ một chút nhé…');
      return;
    }
    _idleTimer?.cancel();
    setState(() => _busy = true);
    _setActivity(HousePetActivity.playing);
    _setThought('Chơi với mình nhé! 🎾', visibleFor: const Duration(seconds: 3));
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    try {
      await _firestoreService.playWithPet(pet.id);
      await _firestoreService.addPetAffection(
          pet.id, FirestoreService.playAffectionGain);
      _bump(HouseQuestCatalog.play);
      _setThought('Vui quá! Cảm ơn bạn đã chơi cùng mình! ✨');
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      _endBusy();
    }
  }

  Future<void> _doPetActivity(PetActivityDef a) async {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _busy || _sleeping) return;
    if (pet.energy < a.minEnergy) {
      _setThought('Mình hơi mệt rồi, cho mình nghỉ một chút nhé…');
      return;
    }
    if (pet.hunger < a.minHunger) {
      _setThought('Bụng mình đói rồi, cho mình ăn trước nhé… 🍽️');
      return;
    }
    _idleTimer?.cancel();
    setState(() => _busy = true);
    _setActivity(a.anim == 'spin'
        ? HousePetActivity.spinning
        : HousePetActivity.playing);
    _setThought(a.startThought, visibleFor: Duration(seconds: a.seconds));
    for (var i = 0; i < a.seconds; i++) {
      if (a.anim == 'pose') _jump.forward(from: 0);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
    try {
      await _firestoreService.petActivity(pet.id,
          hunger: a.hunger,
          energy: a.energy,
          happiness: a.happiness,
          hp: a.hp,
          exp: a.exp);
      await _firestoreService.addPetAffection(
          pet.id, FirestoreService.playAffectionGain);
      _bump(HouseQuestCatalog.play);
      _setThought(a.doneThought);
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    } finally {
      _endBusy();
    }
  }

  void _openActivitiesSheet() {
    final pet = context.read<PetProvider>().pet;
    if (pet == null || _busy || _sleeping) return;
    if (_decorMode) {
      _showMessage('Bấm "Xong" để thoát chế độ trang trí trước nhé!');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      // PetActivitiesSheet tự đóng khi chọn, nên không pop thêm ở đây.
      builder: (_) => PetActivitiesSheet(pet: pet, onPick: _doPetActivity),
    );
  }

  // ---------- Chăm sóc nhanh ----------

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
    if (_weather == HouseWeather.rain) {
      return 'Trời mưa rồi, ở trong nhà thật ấm áp ☔';
    }
    if (_isNight) return 'Tối nay thật yên tĩnh… ✨';
    if (_weather == HouseWeather.sunny) return 'Hôm nay nắng đẹp quá! ☀️';
    return 'Mình đang nhìn ngắm căn nhà! 🏠';
  }

  /// Việc nên làm NGAY: nhu cầu cấp bách nhất, nếu không có thì nhắc nhận
  /// thưởng nhiệm vụ. null = không cần gợi ý.
  _QuickCare? _quickCare(PetModel pet) {
    final options = <_QuickCare>[];
    if (pet.toiletNeed >= 70) {
      options.add(_QuickCare(pet.toiletNeed.toDouble(), '🚽',
          'Pet buồn vệ sinh', 'Đi ngay', true, _useToilet));
    }
    if (pet.hunger <= 35) {
      options.add(_QuickCare((100 - pet.hunger).toDouble(), '🍗',
          'Pet đang đói', 'Cho ăn', true, _onFeedPressed));
    }
    if (pet.hygiene <= 35) {
      options.add(_QuickCare((100 - pet.hygiene).toDouble(), '🫧',
          'Pet đang dơ', 'Tắm ngay', true, _onBathePressed));
    }
    if (pet.energy <= 30 && _isNight) {
      options.add(_QuickCare((100 - pet.energy).toDouble(), '🌙',
          'Pet buồn ngủ', 'Đi ngủ', true, _onSleepPressed));
    }
    if (pet.playfulness <= 35) {
      options.add(_QuickCare((100 - pet.playfulness).toDouble(), '🎾',
          'Pet muốn chơi', 'Chơi ngay', true, _playWithPet));
    }
    if (options.isNotEmpty) {
      options.sort((a, b) => b.score.compareTo(a.score));
      return options.first;
    }
    if (_extras.value.badgeCount > 0) {
      return _QuickCare(0, '🎁', 'Có thưởng nhiệm vụ đang chờ', 'Nhận',
          false, _openQuests);
    }
    return null;
  }

  // ---------- Nhiệm vụ ----------

  void _openQuests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HouseQuestSheet(
        extras: _extras,
        onClaim: _claimQuest,
        onClaimBonus: _claimBonus,
      ),
    );
  }

  Future<void> _claimQuest(String id) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final coin = await _extrasService.claimQuest(uid, id);
      if (coin > 0) {
        if (mounted) await context.read<AuthProvider>().refreshCurrentStudent();
        await _refreshQuests();
        _showMessage('Nhận thưởng nhiệm vụ: +$coin 🪙');
      }
    } catch (e) {
      _showMessage('Chưa nhận được thưởng: $e');
    }
  }

  Future<void> _claimBonus() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final coin = await _extrasService.claimBonus(uid);
      if (coin > 0) {
        if (mounted) await context.read<AuthProvider>().refreshCurrentStudent();
        await _refreshQuests();
        _jump.forward(from: 0);
        _showMessage('Mở Rương thưởng cuối ngày: +$coin 🪙 🎉');
      }
    } catch (e) {
      _showMessage('Chưa mở được rương: $e');
    }
  }

  // ---------- Trang trí nội thất ----------

  void _toggleDecor() {
    if (_busy || _sleeping || _overlayOpen) return;
    _idleTimer?.cancel();
    setState(() => _decorMode = !_decorMode);
    if (!_decorMode) _restartIdleTimer();
  }

  void _setPlaced(RoomType type, List<PlacedDecor> list) {
    final map = Map<String, List<PlacedDecor>>.from(_extras.value.placed);
    map[type.name] = list;
    _extras.value = _extras.value.copyWith(placed: map);
  }

  void _saveRoomDecor(RoomType type) {
    final uid = _uid;
    if (uid == null) return;
    _extrasService
        .savePlaced(uid, type, _extras.value.placedIn(type))
        .catchError((Object _) {
      _showMessage('Chưa lưu được cách sắp xếp nội thất, thử lại nhé.');
    });
  }

  void _placeDecor(DecorTemplate d) {
    final type = _room.type;
    final current = _extras.value.placedIn(type);
    if (current.length >= DecorCatalog.maxPerRoom) {
      _showMessage('Phòng đã đầy, hãy cất bớt đồ nhé!');
      return;
    }
    if (_extras.value.placedIds.contains(d.id)) return;
    final p = PlacedDecor(
      id: d.id,
      x: 0.3 + _random.nextDouble() * 0.4,
      y: 0.5 + _random.nextDouble() * 0.3,
    );
    _setPlaced(type, [...current, p]);
    _saveRoomDecor(type);
  }

  void _removeDecor(String id) {
    final type = _room.type;
    _setPlaced(type,
        _extras.value.placedIn(type).where((e) => e.id != id).toList());
    _saveRoomDecor(type);
  }

  void _moveDecor(String id, Offset delta) {
    if (_stage.isEmpty) return;
    final type = _room.type;
    _setPlaced(type, [
      for (final p in _extras.value.placedIn(type))
        if (p.id == id)
          p.moved(
            (p.x + delta.dx / _stage.width).clamp(0.05, 0.95).toDouble(),
            (p.y + delta.dy / _stage.height).clamp(0.12, 0.95).toDouble(),
          )
        else
          p,
    ]);
  }

  Future<void> _buyDecor(DecorTemplate d) async {
    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent;
    if (student == null) return;
    if (!student.hasEnoughCoin(d.priceCoin)) {
      _showMessage('Bạn chưa đủ Coin để mua "${d.name}" rồi 🪙');
      return;
    }
    try {
      final ok = await _extrasService.buyDecor(student.uid, d,
          coinInfinite: student.coinInfinite);
      if (!mounted) return;
      if (ok) {
        _extras.value = _extras.value
            .copyWith(ownedDecor: {..._extras.value.ownedDecor, d.id});
        await auth.refreshCurrentStudent();
        _showMessage('Đã mua "${d.name}"! Vào tab Kho để đặt vào phòng 🎉');
      } else {
        _showMessage('Không mua được "${d.name}" (đã có hoặc không đủ Coin).');
      }
    } catch (e) {
      _showMessage('Có lỗi xảy ra: $e');
    }
  }

  // ---------- Menu & tiện ích ----------

  void _openWardrobe() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SkinRoomSheet(),
    );
  }

  void _openAffection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const FriendshipSheet(),
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
                            _openAffection();
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

  // ---------- Dựng giao diện ----------

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pet = context.watch<PetProvider>().pet;
    final student = auth.currentStudent;
    if (pet == null || student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _uid = student.uid;
    final house = HouseCatalog.byId(pet.currentHouseId);
    final media = MediaQuery.of(context);
    final topReserve = media.padding.top + 150;
    final bottomReserve = media.padding.bottom + 152;
    final ownedFoods = FoodCatalog.all
        .where((f) => (student.foodInventory[f.id] ?? 0) > 0)
        .toList();
    final coinText = student.coinInfinite ? '∞' : '${student.coin}';
    final ex = _extras.value;
    final quick = (_busy || _overlayOpen || _decorMode) ? null : _quickCare(pet);
    final canPop = Navigator.of(context).canPop();
    final weatherIcon = _isNight ? '🌙' : _weather.emoji;

    return PopScope(
      canPop: !_decorMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _decorMode) setState(() => _decorMode = false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const FriendshipCelebrationListener(),
            // 1) Nền phòng.
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Image.asset(
                  roomBackgroundAsset(house.id, _room.type),
                  key: ValueKey('${house.id}-${_room.type.name}'),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            // 2) Ngày/đêm + thời tiết.
            Positioned.fill(
              child: HouseAmbience(
                hour: _hourFraction,
                weather: _weather,
                tick: _sky,
              ),
            ),
            // 3) Sân khấu: nội thất + pet, sắp theo chiều sâu.
            Positioned(
              left: 0,
              right: 0,
              top: topReserve,
              bottom: bottomReserve,
              child: LayoutBuilder(builder: (context, c) {
                _stage = Size(c.maxWidth, c.maxHeight);
                return _buildStage(pet, ex, c.maxWidth, c.maxHeight);
              }),
            ),
            // 4) Thanh trên: quay lại, tên nhà, menu + thẻ trạng thái.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (canPop)
                                HouseGlassButton(
                                  icon: Icons.arrow_back_rounded,
                                  tooltip: tr('Quay lại'),
                                  onTap: () => Navigator.of(context).maybePop(),
                                )
                              else
                                const SizedBox(width: 44),
                              Expanded(
                                child: Center(
                                  child: HouseTitleChip(
                                    title: house.name,
                                    subtitle:
                                        '$weatherIcon ${_isNight ? 'Đêm' : _weather.label} · $_gameTimeLabel',
                                  ),
                                ),
                              ),
                              HouseGlassButton(
                                icon: Icons.apps_rounded,
                                tooltip: 'Menu',
                                onTap: _openMenuSheet,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          HouseNeedsCard(
                            pet: pet,
                            trailing: HouseCoinPill(text: coinText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 5) Cột tiện ích bên phải.
            Positioned(
              right: 12,
              top: topReserve + 6,
              child: Column(
                children: [
                  if (!widget.teacherMode) ...[
                    HouseGlassButton(
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFFFF6B8A),
                      tooltip: tr('Thân thiết'),
                      onTap: _openAffection,
                    ),
                    const SizedBox(height: 10),
                  ],
                  HouseGlassButton(
                    emoji: '📋',
                    tooltip: tr('Nhiệm vụ hằng ngày'),
                    badge: ex.badgeCount,
                    onTap: _openQuests,
                  ),
                  const SizedBox(height: 10),
                  HouseGlassButton(
                    emoji: '🪑',
                    tooltip: tr('Trang trí phòng'),
                    onTap: _toggleDecor,
                  ),
                  const SizedBox(height: 10),
                  HouseGlassButton(
                    emoji: '👕',
                    tooltip: tr('Phòng đổi skin'),
                    onTap: _openWardrobe,
                  ),
                ],
              ),
            ),
            // 6) Banner chăm sóc nhanh.
            if (quick != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomReserve + 8,
                child: Center(
                  child: HouseQuickBanner(
                    emoji: quick.emoji,
                    title: quick.title,
                    actionLabel: quick.action,
                    urgent: quick.urgent,
                    onTap: quick.onTap,
                  ),
                ),
              ),
            // 7) Dock / khay đồ ăn / khay trang trí.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.25), end: Offset.zero)
                      .animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _decorMode
                    ? HouseDecorPanel(
                        key: const ValueKey('decor'),
                        room: _room,
                        extras: ex,
                        placedInRoom: ex.placedIn(_room.type).length,
                        coinText: coinText,
                        canAfford: student.hasEnoughCoin,
                        onPlace: _placeDecor,
                        onBuy: _buyDecor,
                        onDone: _toggleDecor,
                      )
                    : _showFoodTray
                        ? HouseFoodTray(
                            key: const ValueKey('food'),
                            foods: ownedFoods,
                            inventory: student.foodInventory,
                            onFeed: _feed,
                            onShop: () {
                              setState(() => _showFoodTray = false);
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const ShopScreen(
                                    initialCategory: ItemCategory.food),
                              ));
                            },
                            onClose: () {
                              setState(() => _showFoodTray = false);
                              _restartIdleTimer();
                            },
                          )
                        : HouseDock(
                            key: const ValueKey('dock'),
                            pet: pet,
                            roomIndex: _roomIndex,
                            busy: _busy,
                            onRoom: _selectRoom,
                            onFeed: _onFeedPressed,
                            onBathe: _onBathePressed,
                            onSleep: _onSleepPressed,
                            onToilet: _useToilet,
                            onPlay: _playWithPet,
                            onActivities: _openActivitiesSheet,
                          ),
              ),
            ),
            // 8) Cảnh tắm và lớp phủ ngủ.
            if (_showBath)
              Positioned.fill(
                child: HouseBathScene(
                  pet: pet,
                  bob: _bob,
                  loop: _loop,
                  jump: _jump,
                  squash: _squash,
                  progress: _bathProgress,
                  rinsing: _bathRinsing,
                  onScrub: _onScrub,
                  onClose: _closeBath,
                ),
              ),
            if (_sleeping)
              Positioned.fill(
                child: HouseSleepOverlay(
                  progress: _sleepProgress,
                  onWake: _wakeEarly,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStage(PetModel pet, HouseExtras ex, double w, double h) {
    final petSize = (w * 0.4).clamp(110.0, 168.0).toDouble();
    final layers = <(double, Widget)>[];

    for (final p in ex.placedIn(_room.type)) {
      final def = DecorCatalog.byId(p.id);
      if (def == null) continue;
      layers.add((
        p.y,
        Positioned(
          key: ValueKey('decor-${p.id}'),
          left: p.x * w - def.size / 2 - 12,
          top: p.y * h - def.size - 4,
          child: _DecorItem(
            decor: def,
            editing: _decorMode,
            onDrag: (d) => _moveDecor(p.id, d),
            onDragEnd: () => _saveRoomDecor(_room.type),
            onRemove: () => _removeDecor(p.id),
          ),
        ),
      ));
    }

    if (!_showBath) {
      layers.add((
        _petPos.dy,
        AnimatedPositioned(
          key: const ValueKey('pet'),
          duration: _walkDuration,
          curve: Curves.easeInOut,
          left: _petPos.dx * w - petSize / 2,
          top: _petPos.dy * h - petSize * 0.92,
          width: petSize,
          height: petSize,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('pet-pop-$_roomIndex'),
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (context, s, child) => Transform.scale(
              scale: s,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onPetTap,
                    onPanStart: (_) => _onDragStart(),
                    onPanUpdate: (d) => _onDragUpdate(d.delta),
                    onPanEnd: (_) => _onDragEnd(),
                    child: HousePetSprite(
                      pet: pet,
                      activity: _activity,
                      facingRight: _facingRight,
                      size: petSize,
                      bob: _bob,
                      loop: _loop,
                      jump: _jump,
                      squash: _squash,
                    ),
                  ),
                ),
                if (_thought != null && !_sleeping)
                  Positioned(
                    left: petSize / 2 - 100,
                    bottom: petSize * 0.92,
                    width: 200,
                    child: IgnorePointer(child: _ThoughtBubble(text: _thought!)),
                  ),
              ],
            ),
          ),
        ),
      ));
    }

    layers.sort((a, b) => a.$1.compareTo(b.$1));
    return Stack(
      clipBehavior: Clip.none,
      children: [for (final l in layers) l.$2],
    );
  }
}

/// Việc gợi ý của banner "Chăm sóc nhanh".
class _QuickCare {
  final double score;
  final String emoji;
  final String title;
  final String action;
  final bool urgent;
  final VoidCallback onTap;

  const _QuickCare(
      this.score, this.emoji, this.title, this.action, this.urgent, this.onTap);
}

/// 1 món nội thất trong phòng; ở chế độ trang trí thì kéo được và có nút ✕.
class _DecorItem extends StatelessWidget {
  final DecorTemplate decor;
  final bool editing;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;
  final VoidCallback onRemove;

  const _DecorItem({
    required this.decor,
    required this.editing,
    required this.onDrag,
    required this.onDragEnd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: editing
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85), width: 1.5),
                color: Colors.white.withValues(alpha: 0.12),
              )
            : null,
        child: Text(decor.emoji,
            style: TextStyle(fontSize: decor.size, height: 1.05)),
      ),
    );
    if (!editing) return IgnorePointer(child: body);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) => onDrag(d.delta),
      onPanEnd: (_) => onDragEnd(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bong bóng suy nghĩ của pet.
class _ThoughtBubble extends StatelessWidget {
  final String text;

  const _ThoughtBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 3),
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
        const SizedBox(height: 2),
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
      ],
    );
  }
}
