import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/curriculum.dart';
import '../theme/app_theme.dart';
import 'math_thpt_screen.dart';

/// Màn hình chọn môn học (Toán, Tiếng Anh, Ngữ Văn...) trước khi làm bài.
class SubjectSelectionScreen extends StatelessWidget {
  const SubjectSelectionScreen({super.key});

  // Ảnh minh họa từng môn (thay cho emoji trước đây).
  static const _subjectImages = {
    'Toán': 'assets/images/subject_toan.png',
    'Tiếng Anh': 'assets/images/subject_tienganh.png',
    'Ngữ Văn': 'assets/images/subject_nguvan.png',
    'Lý': 'assets/images/subject_ly.png',
    'Hóa': 'assets/images/subject_hoa.png',
    'Sinh': 'assets/images/subject_sinh.png',
    'Địa': 'assets/images/subject_dia.png',
    'Lịch sử': 'assets/images/subject_lichsu.png',
    'Tin học': 'assets/images/subject_tinhoc.png',
  };

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent;
    final subjects = Curriculum.subjectsForGrade(student?.grade);

    return ScreenScaffold(bg: BgKind.cream, 
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Chọn môn học'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ảnh nền bản đồ kho báu
          Image.asset('assets/images/treasure_map_bg.png', fit: BoxFit.cover),
          // Lớp phủ trắng mờ để chữ/thẻ môn học vẫn dễ đọc trên nền hoa văn
          Container(color: Colors.white.withValues(alpha: 0.25)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      itemCount: subjects.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.95,
                      ),
                      itemBuilder: (context, index) {
                        final subject = subjects[index];
                        return _SubjectCard(
                          subject: subject,
                          imagePath: _subjectImages[subject],
                          isAvailable: subject == 'Toán',
                          onTap: () {
                            if (subject == 'Toán') {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MathThptScreen(
                                      initialGrade: student?.grade),
                                ),
                              );
                            } else {
                              _showComingSoon(context, subject);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String subject) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('$subject đang được phát triển'),
      content: const Text(
          'PetMath đang ưu tiên hoàn thiện trải nghiệm Toán THPT. Các môn học khác sẽ được mở rộng trong những phiên bản tiếp theo.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu')),
      ],
    ),
  );
}

class _SubjectCard extends StatelessWidget {
  final String subject;
  final String? imagePath;
  final bool isAvailable;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.subject,
    required this.imagePath,
    required this.isAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.subjectColor(subject);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAvailable
                ? accent.withValues(alpha: 0.35)
                : Colors.white,
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
                color: (isAvailable ? accent : Colors.black)
                    .withValues(alpha: isAvailable ? 0.16 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imagePath == null
                      ? Container(
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.menu_book,
                              size: 36,
                              color: isAvailable
                                  ? accent
                                  : AppColors.textSecondary),
                        )
                      : Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Image.asset(
                            imagePath!,
                            fit: BoxFit.contain,
                            // Nếu vì lý do gì đó ảnh không tải được (thiếu file,
                            // sai đường dẫn...), hiện icon mặc định thay vì làm
                            // vỡ layout.
                            errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.menu_book,
                                size: 36,
                                color: isAvailable
                                    ? accent
                                    : AppColors.textSecondary),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(subject,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isAvailable ? accent : AppColors.textSecondary)),
            if (!isAvailable)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('Sắp ra mắt',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}