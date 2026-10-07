import 'package:cloud_firestore/cloud_firestore.dart';
import 'crop_catalog.dart';

/// Model học sinh - vai trò thấp nhất trong 4 quyền: Admin > Nhà sản xuất > Giáo viên > Học sinh
class StudentModel {
  final String uid;
  final String fullName;
  final String email;
  final String? classId;
  final String? schoolId;
  final String? petId;
  final int coin;
  final int gem;
  // Cờ "vô hạn" do admin/giáo viên đặt qua mã ẩn trong hộp thoại Thưởng/Phạt
  // — khi bật, số dư Coin/Gem hiển thị dấu ♾ thay vì con số, và mọi kiểm
  // tra "đủ tiền để mua" đều coi như luôn đủ (xem [hasEnoughCoin]/
  // [hasEnoughGem]). Số coin/gem thật trong Firestore vẫn được giữ nguyên
  // phía dưới, không bị xoá — chỉ ẩn đi khi đang bật vô hạn.
  final bool coinInfinite;
  final bool gemInfinite;
  final int totalExp;
  // Tổng số câu đã làm ĐÚNG (cộng dồn qua mọi lần nộp bài) — dùng để xét
  // các mốc thành tích theo số câu đã làm đúng (xem AchievementCatalog),
  // tách riêng khỏi totalExp vì totalExp có thể đổi công thức tính EXP/câu
  // trong tương lai mà không ảnh hưởng tới mốc thành tích này.
  final int totalCorrectAnswers;
  // Sao chép (denormalize) từ PetModel.level lên đây mỗi khi pet lên cấp,
  // để bảng xếp hạng có thể orderBy trực tiếp trên collection `students`
  // (Firestore không hỗ trợ join, không thể orderBy theo field của 1
  // collection khác) mà không cần đọc thêm collection `pets`.
  final int petLevel;
  final DateTime? petLevelUpAt;
  // PetMath: được hiện trên bảng xếp hạng hay không. Bật tự động khi pet đạt
  // mức Thân thiết V (xem FirestoreService._applyAffectionGain). Học sinh cũ
  // chưa có field → false (ẩn) cho tới khi đạt mức V.
  final bool showOnLeaderboard;
  final int streakDays;
  final DateTime? lastStudyDate;
  // Đánh dấu ngày gần nhất đã "xử lý" xong cảnh báo nguy cơ mất streak (đã
  // hỏi dùng Kim cương giữ streak hay chưa) — để không hỏi lại nhiều lần
  // trong cùng 1 ngày. Không ảnh hưởng tới cách tính streak thực tế.
  final DateTime? lastStreakCheckDate;
  final DateTime? lastSpinDate;
  final List<String> badgeIds;
  final List<String> unlockedFish;
  final List<String> inventoryItemIds; // vật phẩm đã mua ở Cửa hàng
  final int cipherTickets; // Vé giải mật mã, mua ở Cửa hàng (10 Coin/vé)
  final Map<String, int> foodInventory; // đồ ăn đã mua: foodId -> số lượng
  final DateTime createdAt;
  // Tuỳ chọn BẬT/TẮT từng loại thông báo ĐẨY (push, qua Firebase Cloud
  // Messaging — xem NotificationService/functions/index.js). Mặc định bật
  // hết nếu học sinh chưa từng chỉnh.
  final Map<String, bool> notificationPrefs;
  // FCM token của thiết bị đang đăng nhập gần nhất — Cloud Functions dùng
  // field này để biết gửi thông báo đẩy vào máy nào (xem
  // NotificationService.registerForStudent). Null nếu chưa từng cấp
  // quyền thông báo hoặc đang ở phiên bản app cũ chưa hỗ trợ.
  final String? fcmToken;

  // ---------- CÂU CÁ (cần câu, mồi câu, sổ kỷ lục) ----------
  // Cấp cần câu hiện có (0 = Cần tre mặc định), xem [kRodTiers] trong
  // fish_data.dart. Cần cao cấp hơn: may mắn hơn (dễ ra cá hiếm), thanh
  // giật cần rộng hơn (dễ bắt hơn), tốn ít Năng lượng hơn mỗi lượt câu.
  final int fishingRodTier;
  // Số lượt "Mồi câu may mắn" đang có — mỗi lượt câu tự động dùng 1 mồi
  // (nếu có) để tăng thêm cơ hội ra cá hiếm cho riêng lượt câu đó.
  final int baitCharges;
  // Kỷ lục cân nặng (kg) NẶNG NHẤT đã từng câu được, theo từng loài cá:
  // fishId -> cân nặng (kg).
  final Map<String, double> fishRecords;

  // Địa chỉ hành chính (theo cơ cấu 2 cấp Tỉnh -> Xã/Phường từ 01/07/2025)
  final int? provinceCode;
  final String? provinceName;
  final int? wardCode;
  final String? wardName;
  final String? schoolName;

  // Khối lớp (1-12) — null nghĩa là tài khoản được tạo TRƯỚC khi có tính
  // năng này, dùng làm dấu hiệu để hiện màn "Bổ sung thông tin" 1 lần duy
  // nhất (xem CompleteProfileScreen/SplashScreen). Sau khi nhập, không
  // bao giờ còn null nữa nên màn đó không hiện lại.
  final int? grade;

  // ---------- NÔNG TRẠI (mini game trồng Hoa & Trái cây kiểu Hay Day) ----------
  // Các ô đất ĐANG trồng cây: key = chỉ số ô đất (dạng String), value =
  // {cropId, plantedAt, growAccumSeconds, lastWateredAt, lastFertilizedAt,
  // lastCareUpdateAt} — xem [FarmPlotState.fromMap]. Ô đất trống (chưa
  // trồng, đã thu hoạch, hoặc cây chết đã dọn) không xuất hiện ở đây.
  final Map<String, dynamic> farmPlots;
  // Số ô đất đã mở khoá (mặc định [kFarmFreePlots], tối đa [kFarmMaxPlots]
  // — xem [FirestoreService.unlockFarmPlot]).
  final int farmPlotsUnlocked;

  static const defaultNotificationPrefs = {
    'streak': true, // nhắc giữ streak nếu sau 6 tiếng mỗi ngày chưa học
    'levelUp': true, // thông báo khi pet lên cấp
    'achievement': true, // thông báo khi mở khoá thành tích/huy hiệu
    'update': true, // tin tức/cập nhật chung của app (gửi qua topic)
  };

  StudentModel({
    required this.uid,
    required this.fullName,
    required this.email,
    this.classId,
    this.schoolId,
    this.petId,
    this.coin = 0,
    this.gem = 0,
    this.coinInfinite = false,
    this.gemInfinite = false,
    this.totalExp = 0,
    this.totalCorrectAnswers = 0,
    this.petLevel = 1,
    this.petLevelUpAt,
    this.showOnLeaderboard = false,
    this.streakDays = 0,
    this.lastStudyDate,
    this.lastStreakCheckDate,
    this.lastSpinDate,
    this.badgeIds = const [],
    this.unlockedFish = const [],
    this.inventoryItemIds = const [],
    this.cipherTickets = 0,
    this.foodInventory = const {},
    required this.createdAt,
    this.notificationPrefs = defaultNotificationPrefs,
    this.fcmToken,
    this.fishingRodTier = 0,
    this.baitCharges = 0,
    this.fishRecords = const {},
    this.provinceCode,
    this.provinceName,
    this.wardCode,
    this.wardName,
    this.schoolName,
    this.grade,
    this.farmPlots = const {},
    this.farmPlotsUnlocked = kFarmFreePlots,
  });

  factory StudentModel.fromMap(String uid, Map<String, dynamic> map) {
    return StudentModel(
      uid: uid,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      classId: map['classId'],
      schoolId: map['schoolId'],
      petId: map['petId'],
      coin: map['coin'] ?? 0,
      gem: map['gem'] ?? 0,
      coinInfinite: map['coinInfinite'] ?? false,
      gemInfinite: map['gemInfinite'] ?? false,
      totalExp: map['totalExp'] ?? 0,
      totalCorrectAnswers: map['totalCorrectAnswers'] ?? 0,
      petLevel: map['petLevel'] ?? 1,
      petLevelUpAt: (map['petLevelUpAt'] as Timestamp?)?.toDate(),
      showOnLeaderboard: map['showOnLeaderboard'] ?? false,
      streakDays: map['streakDays'] ?? 0,
      lastStudyDate: (map['lastStudyDate'] as Timestamp?)?.toDate(),
      lastStreakCheckDate: (map['lastStreakCheckDate'] as Timestamp?)?.toDate(),
      lastSpinDate: (map['lastSpinDate'] as Timestamp?)?.toDate(),
      badgeIds: List<String>.from(map['badgeIds'] ?? []),
      unlockedFish: List<String>.from(map['unlockedFish'] ?? []),
      inventoryItemIds: List<String>.from(map['inventory'] ?? []),
      cipherTickets: map['cipherTickets'] ?? 0,
      foodInventory: Map<String, int>.from(map['foodInventory'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationPrefs: map['notificationPrefs'] != null
          ? Map<String, bool>.from(map['notificationPrefs'])
          : defaultNotificationPrefs,
      fcmToken: map['fcmToken'],
      fishingRodTier: map['fishingRodTier'] ?? 0,
      baitCharges: map['baitCharges'] ?? 0,
      fishRecords: map['fishRecords'] != null
          ? Map<String, double>.from(
              (map['fishRecords'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ),
            )
          : {},
      provinceCode: map['provinceCode'],
      provinceName: map['provinceName'],
      wardCode: map['wardCode'],
      wardName: map['wardName'],
      schoolName: map['schoolName'],
      grade: map['grade'],
      farmPlots: map['farmPlots'] != null
          ? Map<String, dynamic>.from(map['farmPlots'])
          : {},
      farmPlotsUnlocked: map['farmPlotsUnlocked'] ?? kFarmFreePlots,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'classId': classId,
      'schoolId': schoolId,
      'petId': petId,
      'coin': coin,
      'gem': gem,
      'coinInfinite': coinInfinite,
      'gemInfinite': gemInfinite,
      'totalExp': totalExp,
      'totalCorrectAnswers': totalCorrectAnswers,
      'petLevel': petLevel,
      'petLevelUpAt':
          petLevelUpAt != null ? Timestamp.fromDate(petLevelUpAt!) : null,
      'showOnLeaderboard': showOnLeaderboard,
      'streakDays': streakDays,
      'lastStudyDate':
          lastStudyDate != null ? Timestamp.fromDate(lastStudyDate!) : null,
      'lastStreakCheckDate': lastStreakCheckDate != null
          ? Timestamp.fromDate(lastStreakCheckDate!)
          : null,
      'lastSpinDate':
          lastSpinDate != null ? Timestamp.fromDate(lastSpinDate!) : null,
      'badgeIds': badgeIds,
      'unlockedFish': unlockedFish,
      'inventory': inventoryItemIds,
      'cipherTickets': cipherTickets,
      'foodInventory': foodInventory,
      'createdAt': Timestamp.fromDate(createdAt),
      'notificationPrefs': notificationPrefs,
      'fcmToken': fcmToken,
      'fishingRodTier': fishingRodTier,
      'baitCharges': baitCharges,
      'fishRecords': fishRecords,
      'role': 'student',
      'provinceCode': provinceCode,
      'provinceName': provinceName,
      'wardCode': wardCode,
      'wardName': wardName,
      'schoolName': schoolName,
      'grade': grade,
      'farmPlots': farmPlots,
      'farmPlotsUnlocked': farmPlotsUnlocked,
    };
  }

  StudentModel copyWith({
    String? fullName,
    String? classId,
    int? coin,
    int? gem,
    bool? coinInfinite,
    bool? gemInfinite,
    int? totalExp,
    int? totalCorrectAnswers,
    int? petLevel,
    DateTime? petLevelUpAt,
    bool? showOnLeaderboard,
    int? streakDays,
    DateTime? lastStudyDate,
    DateTime? lastStreakCheckDate,
    DateTime? lastSpinDate,
    String? petId,
    List<String>? badgeIds,
    List<String>? unlockedFish,
    List<String>? inventoryItemIds,
    int? cipherTickets,
    Map<String, int>? foodInventory,
    Map<String, bool>? notificationPrefs,
    int? fishingRodTier,
    int? baitCharges,
    Map<String, double>? fishRecords,
    int? grade,
    int? provinceCode,
    String? provinceName,
    int? wardCode,
    String? wardName,
    String? schoolName,
    Map<String, dynamic>? farmPlots,
    int? farmPlotsUnlocked,
  }) {
    return StudentModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      classId: classId ?? this.classId,
      schoolId: schoolId,
      petId: petId ?? this.petId,
      coin: coin ?? this.coin,
      gem: gem ?? this.gem,
      coinInfinite: coinInfinite ?? this.coinInfinite,
      gemInfinite: gemInfinite ?? this.gemInfinite,
      totalExp: totalExp ?? this.totalExp,
      totalCorrectAnswers: totalCorrectAnswers ?? this.totalCorrectAnswers,
      petLevel: petLevel ?? this.petLevel,
      petLevelUpAt: petLevelUpAt ?? this.petLevelUpAt,
      showOnLeaderboard: showOnLeaderboard ?? this.showOnLeaderboard,
      streakDays: streakDays ?? this.streakDays,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      lastStreakCheckDate: lastStreakCheckDate ?? this.lastStreakCheckDate,
      lastSpinDate: lastSpinDate ?? this.lastSpinDate,
      badgeIds: badgeIds ?? this.badgeIds,
      unlockedFish: unlockedFish ?? this.unlockedFish,
      inventoryItemIds: inventoryItemIds ?? this.inventoryItemIds,
      cipherTickets: cipherTickets ?? this.cipherTickets,
      foodInventory: foodInventory ?? this.foodInventory,
      createdAt: createdAt,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      fishingRodTier: fishingRodTier ?? this.fishingRodTier,
      baitCharges: baitCharges ?? this.baitCharges,
      fishRecords: fishRecords ?? this.fishRecords,
      provinceCode: provinceCode ?? this.provinceCode,
      provinceName: provinceName ?? this.provinceName,
      wardCode: wardCode ?? this.wardCode,
      wardName: wardName ?? this.wardName,
      schoolName: schoolName ?? this.schoolName,
      grade: grade ?? this.grade,
      farmPlots: farmPlots ?? this.farmPlots,
      farmPlotsUnlocked: farmPlotsUnlocked ?? this.farmPlotsUnlocked,
    );
  }

  // ---------- COIN / GEM VÔ HẠN ----------

  /// true nếu đủ [cost] Coin để mua/tiêu — LUÔN true khi [coinInfinite].
  bool hasEnoughCoin(int cost) => coinInfinite || coin >= cost;

  /// true nếu đủ [cost] Gem để mua/tiêu — LUÔN true khi [gemInfinite].
  bool hasEnoughGem(int cost) => gemInfinite || gem >= cost;

  /// Chuỗi hiển thị số dư Coin: dấu ♾ nếu đang vô hạn, số bình thường nếu
  /// không.
  String get coinDisplay => coinInfinite ? '∞' : '$coin';

  /// Chuỗi hiển thị số dư Gem: dấu ♾ nếu đang vô hạn, số bình thường nếu
  /// không.
  String get gemDisplay => gemInfinite ? '∞' : '$gem';

  // ---------- STREAK (tính toán, không lưu DB) ----------

  /// Số ngày (lịch, không tính giờ) đã trôi qua kể từ lần học gần nhất.
  /// 0 = đã học hôm nay rồi. 1 = hôm nay CHƯA học nhưng streak vẫn còn
  /// (vẫn kịp học hôm nay để nối tiếp). 2 = đã bỏ lỡ ĐÚNG 1 ngày, có thể
  /// dùng Kim cương để cứu streak. >=3 = bỏ lỡ từ 2 ngày trở lên, streak
  /// coi như đã mất, không cứu được nữa.
  int get daysSinceLastStudy {
    if (lastStudyDate == null) return 99;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last =
        DateTime(lastStudyDate!.year, lastStudyDate!.month, lastStudyDate!.day);
    return today.difference(last).inDays;
  }

  /// true = đã hoàn thành ít nhất 1 bài tập hôm nay -> lửa streak màu ĐỎ.
  /// false = hôm nay chưa học -> lửa streak màu XÁM.
  bool get studiedToday => daysSinceLastStudy == 0;

  /// Số ngày streak NÊN hiển thị cho học sinh xem. Khác với [streakDays]
  /// lưu trong Firestore (chỉ thật sự cập nhật khi học sinh làm bài) — số
  /// hiển thị cần phản ánh NGAY streak đã "chết" hay chưa dựa theo số ngày
  /// đã bỏ lỡ, kể cả khi học sinh chưa mở app để làm bài lại.
  int get displayStreak => daysSinceLastStudy >= 2 ? 0 : streakDays;

  /// true = vừa đúng bỏ lỡ 1 ngày, còn kịp dùng Kim cương để giữ streak,
  /// VÀ chưa được hỏi/xử lý trong hôm nay (tránh hỏi lại nhiều lần).
  bool get streakAtRisk {
    if (daysSinceLastStudy != 2) return false;
    if (lastStreakCheckDate == null) return true;
    final now = DateTime.now();
    final checked = lastStreakCheckDate!;
    final isCheckedToday = now.year == checked.year &&
        now.month == checked.month &&
        now.day == checked.day;
    return !isCheckedToday;
  }
}