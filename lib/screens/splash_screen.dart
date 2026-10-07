import 'package:flutter/material.dart' hide Text;
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'complete_profile_screen.dart';
import 'login_screen.dart';
import 'pet_selection_screen.dart';
import 'student_home_screen.dart';
import 'teacher_home_screen.dart';

/// Màn hình khởi động: hiện logo PetMath rồi điều hướng theo trạng thái đăng nhập.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const _SplashBody();
          case AuthStatus.unauthenticated:
            return const LoginScreen();
          case AuthStatus.authenticated:
            if (auth.currentTeacher != null) {
              return const TeacherHomeScreen();
            }
            // Tài khoản học sinh tạo TRƯỚC khi có Khối lớp/Tỉnh-Xã/Trường sẽ
            // chưa có `grade` — bắt buộc bổ sung 1 lần trước khi vào app,
            // vì Khối lớp giờ quyết định môn học/bài tập/BXH sẽ thấy.
            if (auth.currentStudent?.grade == null) {
              return const CompleteProfileScreen();
            }
            final hasPet = auth.currentStudent?.petId != null;
            return hasPet
                ? const StudentHomeScreen()
                : const PetSelectionScreen();
        }
      },
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/ui/ic_mascot.png', height: 130),
            const SizedBox(height: 16),
            Text('PetMath',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Learn · Play · Grow',
                style: TextStyle(color: Colors.white70, letterSpacing: 1.2)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
