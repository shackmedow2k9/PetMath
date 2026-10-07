import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../models/assignment_model.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/score_utils.dart';
import 'exam_screen.dart';

/// Học sinh xem danh sách bài tập được Giáo viên giao cho lớp mình, và bấm
/// vào để làm (dùng đúng bộ câu hỏi giáo viên đã chọn, khác với "Làm bài"
/// random ở MathThptScreen).
class StudentAssignmentsScreen extends StatelessWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent!;
    final firestoreService = FirestoreService();

    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(title: const Text('Bài tập được giao')),
      body: student.classId == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Bạn chưa ở lớp nào nên chưa có bài được giao.\n'
                  'Vào Hồ sơ > Lớp học của tôi để nhập mã lớp giáo viên cung cấp.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : StreamBuilder<List<AssignmentModel>>(
              stream:
                  firestoreService.watchStudentAssignments(student.classId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Không tải được bài tập: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  );
                }
                final assignments = snapshot.data ?? [];
                if (assignments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Lớp bạn chưa có bài tập nào được giao.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: assignments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final a = assignments[index];
                    final myResult = a.results[student.uid];
                    return _AssignmentCard(
                      assignment: a,
                      myResult: myResult,
                      onTap: () async {
                        final questions = await firestoreService
                            .fetchQuestionsByIds(a.questionIds);
                        if (questions.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Bài tập này chưa có câu hỏi.')),
                            );
                          }
                          return;
                        }
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExamScreen(
                                subject: a.subject,
                                presetQuestions: questions,
                                assignmentId: a.id,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final AssignmentResult? myResult;
  final VoidCallback onTap;

  const _AssignmentCard(
      {required this.assignment, required this.myResult, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = myResult != null;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: done
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.12),
          child: Icon(done ? Icons.check_circle : Icons.assignment_outlined,
              color: done ? AppColors.success : AppColors.primary),
        ),
        title: Text(assignment.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${assignment.questionIds.length} câu'
          '${assignment.dueDate != null ? ' · Hạn ${assignment.dueDate!.day}/${assignment.dueDate!.month}' : ''}',
        ),
        trailing: done
            ? Text(
                myResult!.maxScore > 0
                    ? '${formatVnScore(myResult!.score)}/${formatVnScore(myResult!.maxScore)}'
                    : '${myResult!.correctCount}/${myResult!.totalQuestions}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.success))
            : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}
