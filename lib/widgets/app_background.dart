import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Các nền hoa văn học đường (icon.zip) — mỗi màn hình dùng đúng loại nền
/// theo ảnh minh họa (model_all):
///  • [cream]    : kem ấm — Mini Game, Hồ sơ, game chữ, cài đặt
///  • [light]    : xanh nhạt/kem — Cửa hàng, Toán THPT, Bảng xếp hạng, Nhà
///  • [lavender] : tím lavender — bài tập, lớp học, giải mật mã, lật thẻ, giáo viên
///  • [blue]     : dải xanh có hoa văn (dùng cho header)
enum BgKind {
  cream('assets/ui/bg_pattern_cream.jpg'),
  light('assets/ui/bg_pattern_light.jpg'),
  lavender('assets/ui/bg_pattern_lavender.jpg'),
  blue('assets/ui/bg_pattern_blue.jpg');

  final String asset;
  const BgKind(this.asset);
}

/// Vẽ nền hoa văn phía sau [child].
class AppBackground extends StatelessWidget {
  final Widget child;
  final String asset;
  const AppBackground({
    super.key,
    required this.child,
    this.asset = 'assets/ui/bg_pattern_light.jpg',
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: DecorationImage(
          image: AssetImage(asset),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          // Thiếu ảnh nền thì vẫn còn màu nền, không crash.
          onError: (_, __) {},
        ),
      ),
      child: child,
    );
  }
}

/// `Scaffold` có sẵn nền hoa văn theo [bg]. Dùng thay `Scaffold` ở mọi màn
/// hình để mỗi màn có đúng nền của nó (thay vì một nền chung cho cả app).
class ScreenScaffold extends StatelessWidget {
  final BgKind bg;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;

  /// true → thanh tiêu đề nền màu chính của app, chữ/icon trắng (cả phần
  /// TabBar bên dưới nếu có).
  final bool headerStrip;

  const ScreenScaffold({
    super.key,
    this.bg = BgKind.light,
    this.appBar,
    this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
    this.headerStrip = false,
  });

  static const Color _stripForeground = Colors.white;

  PreferredSizeWidget? _styledAppBar() {
    final a = appBar;
    if (!headerStrip || a is! AppBar) return a;
    // Thanh tiêu đề nền màu chính, chữ/icon trắng (cả TabBar bên dưới).
    return PreferredSize(
      preferredSize: a.preferredSize,
      child: ColoredBox(
        color: AppColors.primary,
        child: AppBar(
          title: a.title,
          actions: a.actions,
          leading: a.leading,
          bottom: a.bottom,
          centerTitle: a.centerTitle ?? true,
          automaticallyImplyLeading: a.automaticallyImplyLeading,
          backgroundColor: Colors.transparent,
          foregroundColor: _stripForeground,
          iconTheme: const IconThemeData(color: _stripForeground),
          actionsIconTheme: const IconThemeData(color: _stripForeground),
          titleTextStyle: const TextStyle(
              color: _stripForeground,
              fontSize: 18,
              fontWeight: FontWeight.bold),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      asset: bg.asset,
      child: Scaffold(
        // Mặc định trong suốt để thấy nền; màn nào truyền màu riêng (vd màn
        // nền tối) thì dùng màu đó và che nền hoa văn.
        backgroundColor: backgroundColor ?? Colors.transparent,
        appBar: _styledAppBar(),
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
      ),
    );
  }
}

/// Hiệu ứng chuyển trang (mờ dần) kèm nền mặc định cho những trang chưa dùng
/// [ScreenScaffold].
class PatternPageTransitionsBuilder extends PageTransitionsBuilder {
  const PatternPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: AppBackground(child: child),
    );
  }
}
