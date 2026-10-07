import 'package:flutter/material.dart' hide Text;
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../widgets/emoji_icon.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../l10n/gen/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../models/pet_model.dart';
import '../models/pet_family_catalog.dart';
import '../models/student_model.dart';
import '../models/house_catalog.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/friendship_widgets.dart';
import '../widgets/pet_blob_frame.dart';
import '../widgets/stat_bar.dart';
import '../widgets/interactive_pet_avatar.dart';
import 'math_thpt_screen.dart';
import 'shop_screen.dart';
import 'minigame_hub_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'house_interior_screen.dart';
import 'ai_tutor_screen.dart';

/// Màn hình trung tâm: "Nhà của thú cưng".
/// Từ đây học sinh có thể: Làm bài, Vào Cửa hàng, Chơi Mini game, Xem BXH.
class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({super.key});

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  final _firestoreService = FirestoreService();
  bool _streakDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final petId = auth.currentStudent?.petId;
      if (petId != null) {
        context.read<PetProvider>().watchPet(petId);
      }
      _maybeShowStreakRiskDialog();
    });
  }

  /// Nếu học sinh vừa bỏ lỡ ĐÚNG 1 ngày học (streak đang nguy cơ mất), hỏi
  /// xem có muốn dùng Kim cương để giữ streak lại không — tự động hỏi 1 lần
  /// mỗi ngày khi mở màn hình này (xem [StudentModel.streakAtRisk]).
  Future<void> _maybeShowStreakRiskDialog() async {
    if (_streakDialogShown || !mounted) return;
    final student = context.read<AuthProvider>().currentStudent;
    if (student == null || !student.streakAtRisk) return;
    _streakDialogShown = true;
    await _showStreakRiskDialog(student);
  }

  /// Bấm tay vào chip lửa: nếu đang nguy cơ mất streak thì hỏi lại (kể cả
  /// đã tự động hỏi rồi), ngược lại chỉ hiển thị thông tin streak hiện tại.
  Future<void> _onTapStreakChip() async {
    final student = context.read<AuthProvider>().currentStudent;
    if (student == null) return;
    if (student.streakAtRisk) {
      await _showStreakRiskDialog(student);
      return;
    }
    final msg = student.studiedToday
        ? 'Bạn đã học hôm nay rồi, streak đang là ${student.displayStreak} ngày! 🔥'
        : 'Streak hiện tại: ${student.displayStreak} ngày. Học 1 bài hôm nay để tiếp tục streak nhé!';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _showStreakRiskDialog(StudentModel student) async {
    final auth = context.read<AuthProvider>();
    final canAfford =
        student.hasEnoughGem(FirestoreService.streakFreezeGemCost);

    final useFreeze = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Bạn sắp mất streak! 🔥'),
        content: Text(
          'Bạn đã bỏ lỡ 1 ngày học. Dùng ${FirestoreService.streakFreezeGemCost} 💎 '
          'Kim cương để giữ nguyên streak ${student.streakDays} ngày, '
          'hoặc streak sẽ về 0.'
          '${canAfford ? '' : '\n\n(Bạn đang không đủ Kim cương.)'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Bỏ qua (mất streak)'),
          ),
          FilledButton(
            onPressed: canAfford ? () => Navigator.of(context).pop(true) : null,
            child: const Text('Dùng Kim cương'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    try {
      if (useFreeze == true) {
        await _firestoreService.useStreakFreeze(student);
        auth.currentStudent = student.copyWith(
          gem: student.gem - FirestoreService.streakFreezeGemCost,
          lastStudyDate: DateTime.now().subtract(const Duration(days: 1)),
          lastStreakCheckDate: DateTime.now(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã giữ streak thành công! 🔥')),
          );
        }
      } else {
        await _firestoreService.acknowledgeStreakLoss(student.uid);
        auth.currentStudent =
            student.copyWith(lastStreakCheckDate: DateTime.now());
      }
      auth.notifyListeners();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Có lỗi xảy ra: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final petProvider = context.watch<PetProvider>();
    final pet = petProvider.pet;
    final student = auth.currentStudent;

    if (pet == null || student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FriendshipCelebrationListener(),
          // Nền hoa văn kem (icon.zip), giữ nguyên độ sáng — không phủ tối.
          Image.asset('assets/ui/bg_pattern_cream.jpg',
              fit: BoxFit.cover, alignment: Alignment.topCenter),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Ngưỡng máy tính/màn hình rộng: giới hạn & căn giữa nội
                // dung thay vì kéo giãn hết cỡ theo chiều ngang, tránh các
                // thẻ bị phóng to xấu xí khi mở toàn màn hình desktop.
                final isWide = constraints.maxWidth >= 700;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: isWide ? 760 : double.infinity),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TopBar(
                              coin: student.coin,
                              gem: student.gem,
                              student: student,
                              onTapStreak: _onTapStreakChip),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 3, child: _PetHeader(pet: pet)),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: _HouseCard(pet: pet)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: StatBar(
                                  emoji: '🍗',
                                  label: 'No bụng',
                                  value: pet.hunger,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: StatBar(
                                  emoji: '❤️',
                                  label: 'HP',
                                  value: pet.hp,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: StatBar(
                                  emoji: '⚡',
                                  label: 'Năng lượng',
                                  value: pet.energy,
                                  color: AppColors.info,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: StatBar(
                                  emoji: '😊',
                                  label: 'Vui vẻ',
                                  value: pet.happiness,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text('Bạn muốn làm gì?',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 12),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1,
                            children: [
                              _ActionCard(
                                imagePath: 'assets/images/action_lambai.png',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => MathThptScreen(
                                          initialGrade: student.grade)),
                                ),
                              ),
                              _ActionCard(
                                imagePath: 'assets/images/action_cuahang.png',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const ShopScreen()),
                                ),
                              ),
                              _ActionCard(
                                imagePath: 'assets/images/action_minigame.png',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const MiniGameHubScreen()),
                                ),
                              ),
                              _ActionCard(
                                imagePath:
                                    'assets/images/action_bangxephang.png',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const LeaderboardScreen()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Gia sư AI: ẨN HẲN (không build widget) cho tới khi Thân thiết đạt
          // mức I — xem FriendshipInfo.aiTutorUnlocked.
          if (pet.friendship.aiTutorUnlocked)
          Positioned(
            right: 18,
            bottom: 22,
            child: _AiPetBubble(
              pet: pet,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AiTutorScreen(
                    questionText: AppLocalizations.of(context)!.askAiTutorHint,
                    options: const [],
                    isExamOrAssignment: false,
                    hasSubmitted: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiPetBubble extends StatelessWidget {
  final PetModel pet;
  final VoidCallback onTap;

  const _AiPetBubble({required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black38, blurRadius: 12, offset: Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PetBlobFrame(width: 56, petAsset: pet.idleAsset),
              const SizedBox(width: 8),
              const Text('Gia sư AI',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int coin;
  final int gem;
  final StudentModel student;
  final VoidCallback onTapStreak;

  const _TopBar({
    required this.coin,
    required this.gem,
    required this.student,
    required this.onTapStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(emoji: '🪙', value: '$coin', infinite: student.coinInfinite),
        const SizedBox(width: 8),
        _Chip(emoji: '💎', value: '$gem', infinite: student.gemInfinite),
        const Spacer(),
        _StreakChip(student: student, onTap: onTapStreak),
      ],
    );
  }
}

/// Chip streak — ngọn lửa màu ĐỎ nếu hôm nay đã học rồi, màu XÁM nếu hôm
/// nay chưa học (vẫn cần học để giữ/nối tiếp streak). Bấm vào để xem chi
/// tiết hoặc dùng Kim cương giữ streak nếu đang có nguy cơ mất.
class _StreakChip extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;
  const _StreakChip({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flameColor =
        student.studiedToday ? const Color(0xFFFF6B35) : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: student.streakAtRisk
                ? AppColors.gold
                : Colors.black.withValues(alpha: 0.08),
            width: student.streakAtRisk ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_fire_department_rounded,
              color: flameColor, size: 18),
          const SizedBox(width: 6),
          Text('${student.displayStreak} ngày',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary)),
          if (student.streakAtRisk) ...[
            const SizedBox(width: 4),
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.gold, size: 15),
          ],
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String emoji;
  final String value;
  final bool infinite;
  const _Chip(
      {required this.emoji, required this.value, this.infinite = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        EmojiIcon(emoji, size: 20),
        const SizedBox(width: 6),
        if (infinite)
          const Icon(Icons.all_inclusive_rounded,
              size: 16, color: AppColors.gold)
        else
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary)),
      ]),
    );
  }
}

/// Avatar tròn của pet + tên + level + thanh EXP mảnh, căn giữa màn hình.
/// Avatar giờ có animation "thở" liên tục và phản hồi khi chạm vào (xem
/// [InteractivePetAvatar]) — chạm vào TÊN pet để mở Hồ sơ (avatar dành
/// riêng cho tương tác vuốt ve, không điều hướng nữa).
class _PetHeader extends StatefulWidget {
  final PetModel pet;
  const _PetHeader({required this.pet});

  @override
  State<_PetHeader> createState() => _PetHeaderState();
}

class _PetHeaderState extends State<_PetHeader> {
  int? _lastSeenLevel;
  bool _showLevelUp = false;

  @override
  void initState() {
    super.initState();
    _lastSeenLevel = widget.pet.level;
  }

  @override
  void didUpdateWidget(covariant _PetHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastSeenLevel != null && widget.pet.level > _lastSeenLevel!) {
      setState(() => _showLevelUp = true);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _showLevelUp = false);
      });
    }
    _lastSeenLevel = widget.pet.level;
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final percent = (pet.exp / pet.expToNextLevel).clamp(0.0, 1.0).toDouble();
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            InteractivePetAvatar(pet: pet),
            if (_showLevelUp)
              const Positioned(
                top: -6,
                child: _LevelUpBurst(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Chip Thân thiết — chạm để xem các mức, phần thưởng, Thư viện, Hộp mù.
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const FriendshipSheet(),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_rounded,
                    size: 15, color: Color(0xFFFF6B8A)),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)!
                      .friendshipChip(pet.friendship.romanLevel),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(pet.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.textPrimary)),
                    if (pet.isRare) ...[
                      const SizedBox(width: 6),
                      const Text('✨', style: TextStyle(fontSize: 16)),
                    ],
                  ],
                ),
                Text(
                    'Level ${pet.level} | ${pet.exp}/${pet.expToNextLevel} EXP',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 200,
          child: LinearPercentIndicator(
            lineHeight: 6,
            percent: percent,
            progressColor: AppColors.success,
            backgroundColor: Colors.black.withValues(alpha: 0.1),
            barRadius: const Radius.circular(6),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Hiệu ứng ăn mừng khi pet lên level: hào quang toả sáng + chữ "Lên
/// cấp!" hiện lên rồi mờ dần, giống hiệu ứng khi Linh Bảo tăng bậc thân
/// thiết trong Liên Quân Mobile.
class _LevelUpBurst extends StatefulWidget {
  const _LevelUpBurst();

  @override
  State<_LevelUpBurst> createState() => _LevelUpBurstState();
}

class _LevelUpBurstState extends State<_LevelUpBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 0 -> 0.3: hiện + phóng to nhẹ. 0.3 -> 1: giữ rồi mờ dần đi lên.
        final opacity = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
        final scale = 0.6 + (t.clamp(0, 0.3) / 0.3) * 0.5;
        final riseOffset = -20 * (t.clamp(0.3, 1.0) - 0.3) / 0.7;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, riseOffset),
            child: Transform.scale(
              scale: scale,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.gold, Color(0xFFFFE29A)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.6),
                        blurRadius: 16,
                        spreadRadius: 2),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎉', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 4),
                    Text('Lên cấp!',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black87)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ô hiển thị ngôi nhà hiện tại của pet ở Nhà của thú cưng.
/// - Di chuột vào (web/desktop): ảnh nhà phóng to nhẹ.
/// - Bấm vào: mở giao diện Nhà của pet (cho ăn, tắm rửa, thay đồ).
class _HouseCard extends StatefulWidget {
  final PetModel pet;
  const _HouseCard({required this.pet});

  @override
  State<_HouseCard> createState() => _HouseCardState();
}

class _HouseCardState extends State<_HouseCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final house = HouseCatalog.byId(widget.pet.currentHouseId);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HouseInteriorScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          // Bố cục ngang: chữ bên trái, ảnh nhà bên phải cao ngang avatar
          // pet (88) — Row giãn hết chiều rộng được cấp (Expanded ở Row
          // cha) và dàn đều 2 đầu để lấp khoảng trống bên trái hợp lý.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    house.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vào nhà',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              AnimatedScale(
                scale: _hovering ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Image.asset(house.assetPath,
                    height: 88, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTap;

  const _ActionCard({required this.imagePath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(imagePath, fit: BoxFit.cover),
      ),
    );
  }
}
