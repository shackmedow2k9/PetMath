import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/house_decor_catalog.dart';
import '../models/house_quest_catalog.dart';
import '../models/room_data.dart';

/// Ảnh chụp dữ liệu "mở rộng" của Nhà pet: kho nội thất, nội thất đã đặt
/// theo phòng, và tiến độ nhiệm vụ hằng ngày.
class HouseExtras {
  final Set<String> ownedDecor;
  final Map<String, List<PlacedDecor>> placed; // key = RoomType.name
  final String questDate;
  final Map<String, int> questProgress;
  final Set<String> questClaimed;
  final bool bonusClaimed;

  const HouseExtras({
    this.ownedDecor = const {},
    this.placed = const {},
    this.questDate = '',
    this.questProgress = const {},
    this.questClaimed = const {},
    this.bonusClaimed = false,
  });

  int progressOf(String questId) => questProgress[questId] ?? 0;

  bool isDone(HouseQuestDef q) => progressOf(q.id) >= q.target;

  bool isClaimed(HouseQuestDef q) => questClaimed.contains(q.id);

  /// Số nhiệm vụ đã xong nhưng chưa nhận thưởng.
  int get claimableCount =>
      HouseQuestCatalog.all.where((q) => isDone(q) && !isClaimed(q)).length;

  bool get allClaimed => HouseQuestCatalog.all.every(isClaimed);

  bool get bonusReady => allClaimed && !bonusClaimed;

  /// Số "việc cần nhận" hiển thị trên huy hiệu nút Nhiệm vụ.
  int get badgeCount => claimableCount + (bonusReady ? 1 : 0);

  List<PlacedDecor> placedIn(RoomType type) => placed[type.name] ?? const [];

  Set<String> get placedIds => {
        for (final list in placed.values)
          for (final p in list) p.id,
      };

  HouseExtras copyWith({
    Set<String>? ownedDecor,
    Map<String, List<PlacedDecor>>? placed,
    String? questDate,
    Map<String, int>? questProgress,
    Set<String>? questClaimed,
    bool? bonusClaimed,
  }) {
    return HouseExtras(
      ownedDecor: ownedDecor ?? this.ownedDecor,
      placed: placed ?? this.placed,
      questDate: questDate ?? this.questDate,
      questProgress: questProgress ?? this.questProgress,
      questClaimed: questClaimed ?? this.questClaimed,
      bonusClaimed: bonusClaimed ?? this.bonusClaimed,
    );
  }
}

/// Đọc/ghi dữ liệu Nhà pet mở rộng ngay trên hồ sơ học sinh
/// (`students/{uid}`: ownedDecor, houseDecor, houseQuests) — dùng chung quyền
/// ghi sẵn có của học sinh nên không cần collection hay luật mới.
class HouseExtrasService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('students').doc(uid);

  static String todayKey() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  Future<HouseExtras> load(String uid) async {
    final snap = await _ref(uid).get();
    return _parse(snap.data() ?? const {});
  }

  HouseExtras _parse(Map<String, dynamic> data) {
    final owned = <String>{};
    final rawOwned = data['ownedDecor'];
    if (rawOwned is List) {
      for (final v in rawOwned) {
        if (v is String && DecorCatalog.byId(v) != null) owned.add(v);
      }
    }

    final placed = <String, List<PlacedDecor>>{};
    final rawPlaced = data['houseDecor'];
    if (rawPlaced is Map) {
      for (final room in RoomType.values) {
        final list = rawPlaced[room.name];
        if (list is! List) continue;
        final items = <PlacedDecor>[];
        for (final raw in list) {
          final p = PlacedDecor.fromMap(raw);
          // Chỉ giữ món đã sở hữu, và mỗi món chỉ xuất hiện 1 lần.
          if (p != null &&
              owned.contains(p.id) &&
              !items.any((e) => e.id == p.id)) {
            items.add(p);
          }
        }
        placed[room.name] = items;
      }
    }

    final q = _questFrom(data['houseQuests']);
    return HouseExtras(
      ownedDecor: owned,
      placed: placed,
      questDate: q.date,
      questProgress: q.progress,
      questClaimed: q.claimed,
      bonusClaimed: q.bonusClaimed,
    );
  }

  /// Trạng thái nhiệm vụ chuẩn hoá về HÔM NAY: lưu của ngày khác thì coi
  /// như làm mới từ đầu.
  _QuestState _questFrom(Object? raw) {
    final today = todayKey();
    if (raw is! Map || raw['date'] != today) {
      return _QuestState(today, {}, {}, false);
    }
    final progress = <String, int>{};
    final rawProgress = raw['progress'];
    if (rawProgress is Map) {
      rawProgress.forEach((k, v) {
        final def = HouseQuestCatalog.byId('$k');
        if (def != null && v is num) {
          progress[def.id] = v.toInt().clamp(0, def.target).toInt();
        }
      });
    }
    final claimed = <String>{};
    final rawClaimed = raw['claimed'];
    if (rawClaimed is List) {
      for (final v in rawClaimed) {
        if (v is String && HouseQuestCatalog.byId(v) != null) claimed.add(v);
      }
    }
    return _QuestState(today, progress, claimed, raw['bonusClaimed'] == true);
  }

  Map<String, dynamic> _questToMap(_QuestState s) => {
        'date': s.date,
        'progress': s.progress,
        'claimed': s.claimed.toList(),
        'bonusClaimed': s.bonusClaimed,
      };

  // ---------- Nội thất ----------

  /// Lưu danh sách nội thất đã đặt của 1 phòng.
  Future<void> savePlaced(
      String uid, RoomType room, List<PlacedDecor> items) async {
    await _ref(uid).update({
      'houseDecor.${room.name}': items.map((e) => e.toMap()).toList(),
    });
  }

  /// Mua 1 món nội thất. Trả về false nếu đã sở hữu hoặc không đủ Coin.
  /// [coinInfinite]: tài khoản Coin vô hạn thì không trừ số dư thật.
  Future<bool> buyDecor(String uid, DecorTemplate decor,
      {required bool coinInfinite}) {
    final ref = _ref(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? const <String, dynamic>{};
      final owned = data['ownedDecor'];
      if (owned is List && owned.contains(decor.id)) return false;
      final coin = ((data['coin'] ?? 0) as num).toInt();
      if (!coinInfinite && coin < decor.priceCoin) return false;
      tx.update(ref, {
        if (!coinInfinite) 'coin': FieldValue.increment(-decor.priceCoin),
        'ownedDecor': FieldValue.arrayUnion([decor.id]),
      });
      return true;
    });
  }

  // ---------- Nhiệm vụ ----------

  /// Cộng tiến độ cho nhiệm vụ [questId] (tối đa bằng mục tiêu).
  Future<void> bumpQuest(String uid, String questId, {int by = 1}) async {
    final def = HouseQuestCatalog.byId(questId);
    if (def == null || by <= 0) return;
    final ref = _ref(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final s = _questFrom((snap.data() ?? const {})['houseQuests']);
      final next =
          ((s.progress[questId] ?? 0) + by).clamp(0, def.target).toInt();
      if (next == (s.progress[questId] ?? 0)) return;
      s.progress[questId] = next;
      tx.update(ref, {'houseQuests': _questToMap(s)});
    });
  }

  /// Nhận thưởng 1 nhiệm vụ đã xong. Trả về số Coin nhận được (0 nếu chưa
  /// thể nhận hoặc đã nhận rồi).
  Future<int> claimQuest(String uid, String questId) {
    final def = HouseQuestCatalog.byId(questId);
    if (def == null) return Future.value(0);
    final ref = _ref(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final s = _questFrom((snap.data() ?? const {})['houseQuests']);
      if ((s.progress[questId] ?? 0) < def.target) return 0;
      if (s.claimed.contains(questId)) return 0;
      s.claimed.add(questId);
      tx.update(ref, {
        'houseQuests': _questToMap(s),
        'coin': FieldValue.increment(def.rewardCoin),
      });
      return def.rewardCoin;
    });
  }

  /// Mở Rương thưởng cuối ngày (cần đã nhận đủ thưởng mọi nhiệm vụ).
  Future<int> claimBonus(String uid) {
    final ref = _ref(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final s = _questFrom((snap.data() ?? const {})['houseQuests']);
      final allClaimed =
          HouseQuestCatalog.all.every((q) => s.claimed.contains(q.id));
      if (!allClaimed || s.bonusClaimed) return 0;
      s.bonusClaimed = true;
      tx.update(ref, {
        'houseQuests': _questToMap(s),
        'coin': FieldValue.increment(HouseQuestCatalog.bonusCoin),
      });
      return HouseQuestCatalog.bonusCoin;
    });
  }
}

class _QuestState {
  final String date;
  final Map<String, int> progress;
  final Set<String> claimed;
  bool bonusClaimed;

  _QuestState(this.date, this.progress, this.claimed, this.bonusClaimed);
}
