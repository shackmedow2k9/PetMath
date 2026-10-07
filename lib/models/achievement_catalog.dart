import 'student_model.dart';

/// Định nghĩa 1 thành tựu/huy hiệu: điều kiện mở khoá được tính THUẦN từ
/// dữ liệu học sinh hiện có (không cần đọc thêm collection nào khác) để
/// [FirestoreService.checkAndAwardAchievements] có thể chạy nhanh, gọi
/// lại nhiều lần vẫn an toàn (idempotent).
class AchievementDef {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(StudentModel student) isUnlocked;

  const AchievementDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.isUnlocked,
  });
}

/// Toàn bộ thành tựu có trong app, gộp theo 4 nhóm: Streak (chăm chỉ mỗi
/// ngày), Học tập (số câu làm đúng), Thú cưng (cấp độ pet), Sưu tầm
/// (cá câu được). Thêm thành tựu mới: chỉ cần thêm 1 [AchievementDef] vào
/// danh sách bên dưới — không cần sửa gì ở FirestoreService hay UI.
class AchievementCatalog {
  static final List<AchievementDef> all = [
    // ---------- Streak ----------
    AchievementDef(
      id: 'streak_3',
      emoji: '🔥',
      title: 'Bền bỉ',
      description: 'Giữ streak học tập 3 ngày liên tiếp',
      isUnlocked: (s) => s.streakDays >= 3,
    ),
    AchievementDef(
      id: 'streak_7',
      emoji: '🔥',
      title: 'Chăm chỉ',
      description: 'Giữ streak học tập 7 ngày liên tiếp',
      isUnlocked: (s) => s.streakDays >= 7,
    ),
    AchievementDef(
      id: 'streak_14',
      emoji: '🌟',
      title: 'Kiên trì',
      description: 'Giữ streak học tập 14 ngày liên tiếp',
      isUnlocked: (s) => s.streakDays >= 14,
    ),
    AchievementDef(
      id: 'streak_30',
      emoji: '👑',
      title: 'Huyền thoại streak',
      description: 'Giữ streak học tập 30 ngày liên tiếp',
      isUnlocked: (s) => s.streakDays >= 30,
    ),

    // ---------- Học tập (số câu làm đúng cộng dồn) ----------
    AchievementDef(
      id: 'answers_10',
      emoji: '📘',
      title: 'Khởi động',
      description: 'Làm đúng 10 câu hỏi',
      isUnlocked: (s) => s.totalCorrectAnswers >= 10,
    ),
    AchievementDef(
      id: 'answers_50',
      emoji: '📗',
      title: 'Chăm học',
      description: 'Làm đúng 50 câu hỏi',
      isUnlocked: (s) => s.totalCorrectAnswers >= 50,
    ),
    AchievementDef(
      id: 'answers_200',
      emoji: '📙',
      title: 'Học giỏi',
      description: 'Làm đúng 200 câu hỏi',
      isUnlocked: (s) => s.totalCorrectAnswers >= 200,
    ),
    AchievementDef(
      id: 'answers_500',
      emoji: '🎓',
      title: 'Bậc thầy tri thức',
      description: 'Làm đúng 500 câu hỏi',
      isUnlocked: (s) => s.totalCorrectAnswers >= 500,
    ),

    // ---------- Thú cưng ----------
    AchievementDef(
      id: 'petlevel_5',
      emoji: '🐾',
      title: 'Pet đang lớn',
      description: 'Pet đạt cấp độ 5',
      isUnlocked: (s) => s.petLevel >= 5,
    ),
    AchievementDef(
      id: 'petlevel_10',
      emoji: '🐾',
      title: 'Pet trưởng thành',
      description: 'Pet đạt cấp độ 10',
      isUnlocked: (s) => s.petLevel >= 10,
    ),
    AchievementDef(
      id: 'petlevel_20',
      emoji: '✨',
      title: 'Pet siêu cấp',
      description: 'Pet đạt cấp độ 20',
      isUnlocked: (s) => s.petLevel >= 20,
    ),

    // ---------- Sưu tầm ----------
    AchievementDef(
      id: 'fish_5',
      emoji: '🐟',
      title: 'Ngư dân tập sự',
      description: 'Sưu tầm được 5 loài cá',
      isUnlocked: (s) => s.unlockedFish.length >= 5,
    ),
    AchievementDef(
      id: 'fish_15',
      emoji: '🐠',
      title: 'Nhà sưu tầm cá',
      description: 'Sưu tầm được 15 loài cá',
      isUnlocked: (s) => s.unlockedFish.length >= 15,
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final def in all) {
      if (def.id == id) return def;
    }
    return null;
  }
}
