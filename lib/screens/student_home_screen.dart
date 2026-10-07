import 'package:flutter/material.dart';
import '../widgets/app_background.dart';
import 'package:provider/provider.dart';
import '../widgets/emoji_icon.dart';
import '../l10n/gen/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'pet_home_screen.dart';
import 'math_thpt_screen.dart';
import 'shop_screen.dart';
import 'minigame_hub_screen.dart';
import 'profile_screen.dart';

/// Cổng Học sinh — vỏ điều hướng dạng tab, cùng cấu trúc với
/// [TeacherHomeScreen] (xem file đó) để 2 giao diện "ngang tầm" nhau: mỗi
/// bên đều có 1 thanh tab rõ ràng làm gốc, thay vì học sinh phải mò vào
/// từng icon rời rạc trong PetHomeScreen như trước.
///
/// 5 tab: Nhà pet (trung tâm, cho ăn/chăm sóc), Học tập (đi thẳng vào Toán
/// THPT — PetMath hiện chỉ có 1 môn nên bỏ hẳn bước "Chọn môn học" trung
/// gian), Cửa hàng, Minigame, Hồ sơ. Bảng xếp hạng vẫn vào được từ tab
/// Nhà pet (giữ nguyên lối tắt cũ) nên không cần thêm tab riêng — tránh
/// thanh tab bị rối hơn cả bên Giáo viên.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Đăng ký nhận thông báo đẩy (push) ngay khi vào cổng Học sinh — đây
    // là "gốc" chung cho mọi tab (Nhà pet, Học tập, Cửa hàng...) nên chỉ
    // cần đăng ký 1 lần ở đây, không phụ thuộc tab nào đang mở.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().currentStudent?.uid;
      if (uid != null) {
        NotificationService().registerForStudent(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final grade = context.watch<AuthProvider>().currentStudent?.grade;
    final pages = [
      const PetHomeScreen(),
      MathThptScreen(initialGrade: grade),
      const ShopScreen(),
      const MiniGameHubScreen(),
      const ProfileScreen(),
    ];
    final l10n = AppLocalizations.of(context)!;
    return ScreenScaffold(bg: BgKind.light, 
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          NavigationDestination(
              icon: const NavAssetIcon('assets/ui/ic_home.png'),
              selectedIcon: const NavAssetIcon('assets/ui/ic_home.png', selected: true),
              label: l10n.navPet),
          NavigationDestination(
              icon: const NavAssetIcon('assets/ui/ic_study.png'),
              selectedIcon: const NavAssetIcon('assets/ui/ic_study.png', selected: true),
              label: l10n.navLearn),
          NavigationDestination(
              icon: const NavAssetIcon('assets/ui/ic_coin_book.png'),
              selectedIcon: const NavAssetIcon('assets/ui/ic_coin_book.png', selected: true),
              label: l10n.navShop),
          NavigationDestination(
              icon: const NavAssetIcon('assets/ui/ic_gamepad.png'),
              selectedIcon: const NavAssetIcon('assets/ui/ic_gamepad.png', selected: true),
              label: l10n.navMinigame),
          NavigationDestination(
              icon: const NavAssetIcon('assets/ui/ic_students.png'),
              selectedIcon: const NavAssetIcon('assets/ui/ic_students.png', selected: true),
              label: l10n.navProfile),
        ],
      ),
    );
  }
}
