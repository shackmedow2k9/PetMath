import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/app_background.dart';

/// Bảng màu "sang xịn" kiểu dashboard edtech hiện đại (tham khảo 9Study):
/// xanh dương-tím (indigo) làm chủ đạo thay vì tím pastel trước đây, nền
/// xám-lavender rất nhạt, thẻ trắng nổi bật nhờ đổ bóng mềm thay vì viền.
/// Vẫn giữ đủ ấm áp/thân thiện để hợp với đối tượng học sinh, nhưng độ bão
/// hòa và độ tương phản được nâng lên để trông chuyên nghiệp, đáng tin hơn.
class AppColors {
  static const primary = Color(0xFF6E81E7); // xanh nhạt dưới logo Σ
  static const primaryDeep = Color(0xFF5A6BD6); // đầu đậm của gradient hero
  static const primaryLight = Color(0xFF8A99F2); // đầu sáng của gradient hero
  static const secondary = Color(0xFFFFB84C); // cam ấm - coin, thưởng
  static const success = Color(0xFF12B76A); // xanh lá - đúng bài, HP
  static const danger = Color(0xFFF04438); // đỏ - sai bài, HP thấp
  static const info = Color(0xFF4FACFE); // xanh dương - streak, energy
  static const background = Color(0xFFF5F6FC); // nền trang xám-lavender nhạt
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF0F1FA); // nền phụ trong thẻ (pill, ô nhập)
  static const textPrimary = Color(0xFF1A1B33); // gần đen, hơi ngả navy
  static const textSecondary = Color(0xFF8A8FA3);
  static const border = Color(0xFFE6E8F5);
  static const gold = Color(0xFFFFD93D); // pet hiếm, thành tích

  // Màu accent riêng cho từng môn học — dùng cho card/badge môn học để
  // trang mang cảm giác "mỗi môn một sắc" giống các dashboard luyện thi.
  static const subjectToan = Color(0xFF3B82F6);
  static const subjectVan = Color(0xFF9333EA);
  static const subjectAnh = Color(0xFF14B8A6);
  static const subjectLy = Color(0xFFE0464A);
  static const subjectHoa = Color(0xFF16A34A);
  static const subjectSinh = Color(0xFF65A30D);
  static const subjectSu = Color(0xFF9A6B2E);
  static const subjectDia = Color(0xFF0891B2);
  static const subjectTin = Color(0xFF475569);

  static Color subjectColor(String subject) {
    switch (subject) {
      case 'Toán':
        return subjectToan;
      case 'Ngữ Văn':
        return subjectVan;
      case 'Tiếng Anh':
        return subjectAnh;
      case 'Lý':
        return subjectLy;
      case 'Hóa':
        return subjectHoa;
      case 'Sinh':
        return subjectSinh;
      case 'Lịch sử':
        return subjectSu;
      case 'Địa':
        return subjectDia;
      case 'Tin học':
        return subjectTin;
      default:
        return primary;
    }
  }
}

/// Gradient dùng cho các banner/header nổi bật (Trang chủ, Cổng giáo viên,
/// Tài khoản...) — xanh dương-tím chéo góc, cùng tinh thần với banner hero
/// của 9Study: sáng ở góc trên-trái, đậm dần xuống góc dưới-phải để tạo
/// chiều sâu thay vì một khối màu phẳng.
class AppGradients {
  static const heroPurple = LinearGradient(
    colors: [AppColors.primaryLight, AppColors.primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Alias ngữ nghĩa rõ hơn — dùng dần thay cho heroPurple ở các màn mới.
  static const heroPrimary = heroPurple;
}

/// Bóng đổ mềm, nhiều lớp — dùng thay cho `elevation` phẳng của Material 3
/// mặc định để thẻ trắng nổi khối rõ ràng, "sang" hơn trên nền xám nhạt.
class AppShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.primaryDeep.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> button = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.28),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    return base.copyWith(
      // Trong suốt: nền hoa văn do AppBackground vẽ dưới mỗi trang.
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PatternPageTransitionsBuilder(),
        TargetPlatform.iOS: PatternPageTransitionsBuilder(),
        TargetPlatform.windows: PatternPageTransitionsBuilder(),
        TargetPlatform.macOS: PatternPageTransitionsBuilder(),
        TargetPlatform.linux: PatternPageTransitionsBuilder(),
        TargetPlatform.fuchsia: PatternPageTransitionsBuilder(),
      }),
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.danger,
        surface: AppColors.surface,
      ),
      textTheme: textTheme.copyWith(
        titleLarge: textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        titleMedium: textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
        headlineSmall: textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: AppColors.border, width: 1.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        disabledColor: Colors.transparent,
        labelStyle: const TextStyle(
            color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: AppColors.primaryDeep.withValues(alpha: 0.08),
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceMuted,
      ),
    );
  }
}