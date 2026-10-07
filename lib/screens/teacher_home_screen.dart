import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/teacher_model.dart';
import '../models/class_model.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/class_card.dart';
import '../widgets/emoji_icon.dart';
import '../widgets/language_menu_button.dart';
import '../widgets/pet_blob_frame.dart';
import 'login_screen.dart';
import 'house_interior_screen.dart';
import 'pet_selection_screen.dart';
import 'ai_tutor_screen.dart';
import 'teacher_class_detail_screen.dart';
import 'teacher_classes_screen.dart';
import 'teacher_question_bank_screen.dart';

/// Cổng Giáo viên — theo Giai đoạn 3 của lộ trình phát triển: "Xây dựng
/// cổng giáo viên, bảng điều khiển, quản lý lớp học và bài kiểm tra".
/// Cùng ngôn ngữ thiết kế với giao diện Học sinh (gradient tím, thẻ bo
/// tròn, chip kính mờ...) nhưng tiết chế hơn cho phù hợp vai trò Giáo viên.
/// 4 tab: Lớp học (dashboard/quản lý lớp/giao bài/thưởng phạt), Ngân hàng
/// câu hỏi (giáo viên tự tạo bài học), Nhà pet (giáo viên tự nuôi pet của
/// riêng mình, đầy đủ chức năng như học sinh), Tài khoản.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final teacher = auth.currentTeacher;
    if (teacher == null) {
      // Không nên xảy ra (SplashScreen chỉ điều hướng vào đây khi đã có
      // currentTeacher), nhưng phòng hờ tránh crash nếu bị mất dữ liệu.
      return const ScreenScaffold(bg: BgKind.light, body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      TeacherClassesScreen(teacherId: teacher.uid),
      TeacherQuestionBankScreen(teacherId: teacher.uid),
      _TeacherPetTab(teacher: teacher),
      _TeacherAccountTab(teacher: teacher),
    ];
    final l10n = AppLocalizations.of(context)!;

    return ScreenScaffold(bg: BgKind.light, 
      extendBodyBehindAppBar: true,
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          NavigationDestination(
              icon: const NavAssetIcon('assets/ui/ic_book_cap.png'),
              selectedIcon: const NavAssetIcon('assets/ui/ic_book_cap.png',
                  selected: true),
              label: l10n.navClasses),
          NavigationDestination(
              icon: const NavAssetIcon('assets/ui/ic_exam_checklist.png'),
              selectedIcon: const NavAssetIcon(
                  'assets/ui/ic_exam_checklist.png',
                  selected: true),
              label: l10n.navQuestions),
          NavigationDestination(
              icon: const NavAssetIcon('assets/ui/ic_home.png'),
              selectedIcon:
                  const NavAssetIcon('assets/ui/ic_home.png', selected: true),
              label: l10n.navPet),
          NavigationDestination(
              icon: const NavAssetIcon('assets/ui/ic_students.png'),
              selectedIcon: const NavAssetIcon('assets/ui/ic_students.png',
                  selected: true),
              label: l10n.navAccount),
        ],
      ),
    );
  }
}

/// Banner gradient tím dùng chung ở đầu mỗi tab của Cổng giáo viên — tương
/// đương vai trò của _TopBar phía Học sinh, giữ cảm giác đồng bộ 2 giao
/// diện dù nội dung khác nhau. Bo góc lớn + đổ bóng sâu để nổi khối như
/// banner hero của các dashboard luyện thi hiện đại.
class TeacherHeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final Widget? trailing;

  /// Chỉ trang Lớp học bật bóng đèn mở Gia sư AI; các trang khác ẩn đi.
  final bool showAiTutor;

  const TeacherHeroHeader({
    super.key,
    this.showAiTutor = false,
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 60, 22, 26),
      decoration: BoxDecoration(
        gradient: AppGradients.heroPrimary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(children: [
        // Bóng đèn: chạm để mở bảng Gia sư AI (các hình sách/bánh răng đã bỏ).
        if (showAiTutor)
        Positioned(
          right: 0,
          top: 0,
          child: Tooltip(
            message: tr('Gia sư AI'),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AiTutorScreen(
                    questionText: tr('Em muốn hỏi gia sư AI điều gì?'),
                    options: const [],
                    isExamOrAssignment: false,
                    hasSubmitted: true,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset('assets/ui/ic_idea.png',
                    width: 52, height: 52),
              ),
            ),
          ),
        ),
        Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: chips),
          ],
        ],
      ),
      ]),
    );
  }
}

/// Chip kính mờ (glass) dùng trong [TeacherHeroHeader] — cùng phong cách
/// _Chip/_StreakChip ở PetHomeScreen phía Học sinh.
class TeacherHeroChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const TeacherHeroChip(
      {super.key,
      required this.icon,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ],
      ),
    );
  }
}

/// Tab "Nhà pet" — cho phép Giáo viên tự nuôi 1 pet CỦA RIÊNG MÌNH với đầy
/// đủ tính năng như học sinh (cho ăn, lên cấp, Cửa hàng, Minigame, BXH...)
/// bằng cách dùng trực tiếp [HouseInteriorScreen] — không đi qua màn hình
/// trung tâm của học sinh. [AuthProvider.loadTeacherPetProfile] cung cấp hồ sơ
/// pet riêng cho giáo viên để dùng chung hệ thống xu, kim cương và mini game.
class _TeacherPetTab extends StatefulWidget {
  final TeacherModel teacher;
  const _TeacherPetTab({required this.teacher});

  @override
  State<_TeacherPetTab> createState() => _TeacherPetTabState();
}

class _TeacherPetTabState extends State<_TeacherPetTab> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    // Chỉ tải/tạo hồ sơ nếu chưa có, hoặc hồ sơ đang giữ không phải của
    // giáo viên hiện tại (phòng trường hợp đăng xuất rồi đăng nhập tài
    // khoản giáo viên khác trong cùng phiên app).
    if (auth.currentStudent == null ||
        auth.currentStudent!.uid != widget.teacher.uid) {
      await auth.loadTeacherPetProfile();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final hasPet = context.watch<AuthProvider>().currentStudent?.petId != null;
    return hasPet
        ? const HouseInteriorScreen(teacherMode: true)
        : const PetSelectionScreen();
  }
}

class _TeacherAccountTab extends StatelessWidget {
  final TeacherModel teacher;
  const _TeacherAccountTab({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    // Bố cục giống Hồ sơ của học sinh: tiêu đề giữa, ảnh trong khung blob, tên,
    // email, hàng chỉ số, rồi danh sách. Khác ở chỗ chỉ số là số lớp đang quản
    // lí và danh sách là các lớp đang quản lí (thay cho "Lớp học của tôi").
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: StreamBuilder<List<ClassModel>>(
              stream: firestoreService.watchTeacherClasses(teacher.uid),
              builder: (context, snapshot) {
                final classes = snapshot.data ?? const <ClassModel>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text('Hồ sơ của tôi',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: PetBlobFrame(
                          width: 170, petAsset: 'assets/ui/ic_mascot.png'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(teacher.fullName,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    Center(
                      child: Text(teacher.email,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ),
                    if (teacher.schoolName != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${teacher.schoolName} · ${teacher.wardName ?? ''}, ${teacher.provinceName ?? ''}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                              iconAsset: 'assets/ui/ic_book_cap.png',
                              value: '${classes.length}',
                              label: 'Lớp đang quản lí'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TotalStudentsCard(classes: classes),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                        classes.isEmpty
                            ? 'Lớp đang quản lí'
                            : 'Lớp đang quản lí (${classes.length})',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (classes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                            'Chưa có lớp nào — vào tab Lớp học để tạo lớp đầu tiên.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      for (var i = 0; i < classes.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClassCard(
                            klass: classes[i],
                            colorIndex: i,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TeacherClassDetailScreen(
                                    klass: classes[i], teacherId: teacher.uid),
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 16),
                    const LanguageMenuButton(),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _confirmTeacherLogout(context),
                      icon: const Icon(Icons.logout, color: AppColors.danger),
                      label: Text(AppLocalizations.of(context)!.logout,
                          style: const TextStyle(color: AppColors.danger)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Tổng số học sinh của tất cả lớp đang quản lí.
class _TotalStudentsCard extends StatelessWidget {
  final List<ClassModel> classes;
  const _TotalStudentsCard({required this.classes});

  Future<int> _total() async {
    final service = FirestoreService();
    var sum = 0;
    for (final c in classes) {
      sum += await service.countClassStudents(c.id);
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      key: ValueKey(classes.map((c) => c.id).join(',')),
      future: _total(),
      builder: (context, snap) => _StatCard(
          iconAsset: 'assets/ui/ic_students.png',
          value: snap.hasData ? '${snap.data}' : '…',
          label: 'Học sinh'),
    );
  }
}

Future<void> _confirmTeacherLogout(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.logoutConfirmTitle),
      content: Text(l10n.logoutConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.logout,
              style: const TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

/// Ô chỉ số kiểu Hồ sơ học sinh: nền pastel, icon ở trên, số, nhãn.
class _StatCard extends StatelessWidget {
  final String iconAsset;
  final String value;
  final String label;

  const _StatCard(
      {required this.iconAsset, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF0FF), Color(0xFFF3EAFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6DEF7)),
      ),
      child: Column(
        children: [
          Image.asset(iconAsset, width: 38, height: 38),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
