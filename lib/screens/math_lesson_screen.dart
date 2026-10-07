import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import '../data/math_practice_catalog.dart';
import '../data/math_formula_catalog.dart';
import '../data/math_tex_formula_catalog.dart';
import '../data/math_study_content.dart';
import '../data/math_solution_catalog.dart';
import '../widgets/math_visuals.dart';
import '../widgets/math_3d_visuals.dart';
import '../widgets/math_formula_widget.dart';
import '../models/math_lesson_model.dart';
import '../theme/app_theme.dart';
import 'exam_screen.dart';

class MathLessonScreen extends StatelessWidget {
  final MathLessonData lesson;

  const MathLessonScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final visual = MathVisualCatalog.forLesson(lesson.id);
    final visual3d = Math3DConfig.forLesson(lesson.id);

    return ScreenScaffold(bg: BgKind.light, 
      appBar: AppBar(title: Text('Toán ${lesson.grade}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildSection(
              icon: Icons.flag_outlined,
              title: 'Mục tiêu bài học',
              child: _bulletList(lesson.objectives),
            ),
            _buildSection(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Tóm tắt lý thuyết',
              child: Text(lesson.overview,
                  style: const TextStyle(height: 1.5, fontSize: 14)),
            ),
            _buildSection(
              icon: Icons.menu_book_rounded,
              title: 'Ý chính cần nhớ',
              child: _bulletList(lesson.keyPoints),
            ),
            if (visual != null)
              _buildSection(
                icon: Icons.insights_rounded,
                title: 'Hình minh họa trực quan',
                child: MathVisualCard(config: visual),
              ),
            if (visual3d != null)
              _buildSection(
                icon: Icons.view_in_ar_outlined,
                title: 'Mô hình hình học 3D theo tham số',
                child: Parametric3DCard(config: visual3d),
              ),
            _buildSection(
              icon: Icons.functions_rounded,
              title: 'Hệ thống công thức đầy đủ',
              child: MathFormulaList(
                formulas: MathTexFormulaCatalog.forLesson(lesson.id),
              ),
            ),
            _buildSection(
              icon: Icons.checklist_rounded,
              title: 'Tự kiểm tra trước khi luyện tập',
              child: _bulletList(lesson.checkpoints),
            ),
            ...MathStudyContent.forLesson(lesson.id)
                .map((section) => _buildDetailedSection(section)),
            _buildSolutionMethods(),
            _buildWatermark(),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExamScreen(
                    subject: 'Toán',
                    grade: lesson.grade,
                    topic: lesson.title,
                    presetQuestions:
                        MathPracticeCatalog.questionsForLesson(lesson.id),
                    displayTitle: 'Luyện tập ${lesson.title}',
                  ),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Bắt đầu luyện tập chuyên đề'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF302C68), Color(0xFF6758DA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LỚP ${lesson.grade} · ${lesson.unit.toUpperCase()}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Text(lesson.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.12,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('Học liệu nguyên bản PetMath · đọc xong rồi luyện ngay',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78), fontSize: 13)),
          const SizedBox(height: 12),
          Text('PETMATH • HỌC LIỆU TOÁN THPT',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }

  Widget _formulaList(List<String> formulas) {
    return Column(
      children: formulas
          .asMap()
          .entries
          .map((entry) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key + 1}.',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(entry.value,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle,
                          size: 6, color: AppColors.secondary),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(item,
                            style: const TextStyle(height: 1.4, fontSize: 13))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _numberedList(List<String> items) {
    return Column(
      children: items
          .asMap()
          .entries
          .map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.info.withValues(alpha: 0.13),
                      child: Text('${entry.key + 1}',
                          style: const TextStyle(
                              color: AppColors.info,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(entry.value,
                            style: const TextStyle(height: 1.4, fontSize: 13))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildDetailedSection(MathStudySection section) {
    return _buildSection(
      icon: Icons.auto_stories_rounded,
      title: section.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.explanation,
              style: const TextStyle(height: 1.5, fontSize: 14)),
          if (section.keyIdeas.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Điểm cần nhớ',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _bulletList(section.keyIdeas),
          ],
        ],
      ),
    );
  }

  Widget _buildSolutionMethods() {
    final methods = MathSolutionCatalog.forLesson(lesson.id);
    if (methods.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      icon: Icons.route_rounded,
      title: 'Phương pháp giải theo dạng bài',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: methods
            .map(
              (method) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FF),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.13),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    Text(method.whenToUse,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 11),
                    ...method.steps.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 11,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.12),
                                  child: Text('${entry.key + 1}',
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900)),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(entry.value,
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.45)),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildWatermark() {
    return Opacity(
      opacity: 0.58,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('PETMATH • HỌC LIỆU TOÁN THPT',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }
}
