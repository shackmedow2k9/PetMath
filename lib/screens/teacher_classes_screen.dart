import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import '../models/class_model.dart';
import '../services/curriculum.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/class_card.dart';
import 'teacher_class_detail_screen.dart';
import 'teacher_home_screen.dart';

/// Tab "Lớp học" của Giáo viên — danh sách lớp do giáo viên này tạo, bấm
/// vào 1 lớp để vào Dashboard (theo dõi học sinh, giao bài, thưởng/phạt).
class TeacherClassesScreen extends StatelessWidget {
  final String teacherId;
  const TeacherClassesScreen({super.key, required this.teacherId});

  Future<void> _createClass(BuildContext context) async {
    final controller = TextEditingController();
    int? grade;
    final result = await showDialog<_NewClassInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Tạo lớp học mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration:  InputDecoration(
                    labelText: tr('Tên lớp'), hintText: tr('VD: Lớp 6A')),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: grade,
                decoration:  InputDecoration(labelText: tr('Khối lớp')),
                items: Curriculum.gradeDropdownItems(),
                onChanged: (v) => setDialogState(() => grade = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty || grade == null) return;
                Navigator.of(dialogContext)
                    .pop(_NewClassInput(controller.text.trim(), grade!));
              },
              child: const Text('Tạo lớp'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await FirestoreService().createClass(
        teacherId: teacherId, name: result.name, grade: result.grade);
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return ScreenScaffold(bg: BgKind.lavender, headerStrip: true, 
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createClass(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Tạo lớp'),
      ),
      body: StreamBuilder<List<ClassModel>>(
        stream: firestoreService.watchTeacherClasses(teacherId),
        builder: (context, snapshot) {
          final classes = snapshot.data ?? [];
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: TeacherHeroHeader(
                    showAiTutor: true,
                    title: 'Lớp học của tôi',
                    subtitle: loading
                        ? 'Đang tải...'
                        : (classes.isEmpty
                            ? 'Chưa có lớp nào — tạo lớp đầu tiên nhé!'
                            : '${classes.length} lớp đang quản lý'),
                    chips: classes.isEmpty
                        ? []
                        : [
                            TeacherHeroChip(
                              icon: Icons.class_rounded,
                              value: '${classes.length}',
                              label: 'lớp',
                            ),
                          ],
                  ),
                ),
                if (snapshot.hasError)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                            'Không tải được danh sách lớp.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 12)),
                      ),
                    ),
                  )
                else if (loading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (classes.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Bấm "Tạo lớp" để bắt đầu — mỗi lớp sẽ có 1 mã mời '
                          'riêng để học sinh tham gia.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    sliver: SliverList.separated(
                      itemCount: classes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final klass = classes[index];
                        return ClassCard(
                          klass: klass,
                          colorIndex: index,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TeacherClassDetailScreen(
                                  klass: klass, teacherId: teacherId),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Kết quả từ dialog "Tạo lớp học mới": tên lớp + khối lớp đã chọn.
class _NewClassInput {
  final String name;
  final int grade;
  _NewClassInput(this.name, this.grade);
}
