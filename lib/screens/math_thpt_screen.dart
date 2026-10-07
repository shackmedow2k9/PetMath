import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/math_lesson_model.dart';
import '../models/math_progress_model.dart';
import '../providers/auth_provider.dart';
import '../data/math_curriculum_catalog.dart';
import '../data/math_practice_catalog.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'exam_screen.dart';
import 'math_lesson_screen.dart';
import 'student_assignments_screen.dart';

/// Trung tâm học tập riêng cho Toán THPT.
///
/// Màn hình này là lớp điều hướng nội dung: dữ liệu câu hỏi vẫn dùng
/// [ExamScreen] và [FirestoreService], còn tài nguyên ngoài được hiển thị
/// dưới dạng thư viện tham khảo có thể sao chép liên kết.
class MathThptScreen extends StatefulWidget {
  final int? initialGrade;

  const MathThptScreen({super.key, this.initialGrade});

  @override
  State<MathThptScreen> createState() => _MathThptScreenState();
}

class _MathThptScreenState extends State<MathThptScreen> {
  late int _grade = widget.initialGrade != null &&
          widget.initialGrade! >= 10 &&
          widget.initialGrade! <= 12
      ? widget.initialGrade!
      : 10;
  _MathSection _section = _MathSection.study;

  static const _sections = <_MathSection, ({String label, IconData icon})>{
    _MathSection.study: (label: 'Học tập', icon: Icons.auto_stories_rounded),
    _MathSection.practice: (label: 'Luyện tập', icon: Icons.bolt_rounded),
    _MathSection.assignments: (
      label: 'Bài giáo viên giao',
      icon: Icons.assignment_rounded
    ),
    _MathSection.exams: (label: 'Đề kiểm tra', icon: Icons.timer_rounded),
    _MathSection.library: (
      label: 'Thư viện',
      icon: Icons.library_books_rounded
    ),
  };

  @override
  Widget build(BuildContext context) {
    final studentId = context.watch<AuthProvider>().currentStudent?.uid;
    final progressStream = studentId == null
        ? null
        : FirestoreService().watchMathProgress(
            studentId: studentId,
            grade: _grade,
          );

    return StreamBuilder<MathProgressModel>(
      stream: progressStream,
      builder: (context, snapshot) {
        final progress = snapshot.data ??
            (studentId == null
                ? MathProgressModel.empty('', _grade)
                : MathProgressModel.empty(studentId, _grade));

        return ScreenScaffold(bg: BgKind.light, 
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Toán THPT'),
            actions: [
              IconButton(
                tooltip: tr('Mục tiêu hôm nay'),
                onPressed: () => _showGoalDialog(context, progress),
                icon: const Icon(Icons.flag_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHero(context, progress)),
                SliverToBoxAdapter(child: _buildGradeSelector()),
                SliverToBoxAdapter(child: _buildSectionBar()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverToBoxAdapter(
                      child: _buildSectionContent(context, progress)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, MathProgressModel progress) {
    final topicCount = _topicsForGrade(_grade).length;
    final progressValue = progress.progressForTopicCount(topicCount);
    final progressPercent = (progressValue * 100).round();
    final studiedLabel = progress.completedSessions == 0
        ? 'Chưa hoàn thành phiên học nào'
        : '${progress.completedSessions} phiên học đã hoàn thành';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.heroPrimary,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'LỘ TRÌNH THPT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chinh phục Toán $_grade',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Học chắc lý thuyết, luyện đúng trọng tâm, tiến bộ mỗi ngày.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ic_sigma.png (icon.zip) thay cho ô Σ cũ.
              Image.asset('assets/ui/ic_sigma.png',
                  width: 84, height: 84, fit: BoxFit.contain),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$progressPercent%',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            studiedLabel,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          const Text('Khối lớp',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const Spacer(),
          for (final grade in [10, 11, 12])
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text('$grade'),
                selected: _grade == grade,
                onSelected: (_) => setState(() => _grade = grade),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _grade == grade ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide.none,
                backgroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  final _sectionScrollController = ScrollController();

  @override
  void dispose() {
    _sectionScrollController.dispose();
    super.dispose();
  }

  Widget _buildSectionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.card,
        ),
        child: Scrollbar(
          controller: _sectionScrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.separated(
            controller: _sectionScrollController,
            padding: const EdgeInsets.only(bottom: 6),
            scrollDirection: Axis.horizontal,
            itemCount: _sections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = _sections.entries.elementAt(index);
              final selected = _section == entry.key;
              return ChoiceChip(
                avatar: Icon(entry.value.icon,
                    size: 17,
                    color: selected ? Colors.white : AppColors.textSecondary),
                label: Text(entry.value.label),
                selected: selected,
                onSelected: (_) => setState(() => _section = entry.key),
                selectedColor: AppColors.primary,
                backgroundColor: Colors.transparent,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContent(
      BuildContext context, MathProgressModel progress) {
    final streakDays =
        context.watch<AuthProvider>().currentStudent?.displayStreak ?? 0;

    switch (_section) {
      case _MathSection.study:
        return _buildStudy(context, progress);
      case _MathSection.practice:
        return _buildPractice(context, progress, streakDays);
      case _MathSection.assignments:
        return _buildAssignments(context);
      case _MathSection.exams:
        return _buildExams(context);
      case _MathSection.library:
        return _buildLibrary(context);
    }
  }

  Widget _buildStudy(BuildContext context, MathProgressModel progress) {
    final topics = _topicsForGrade(_grade);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Lộ trình học tập',
            'Học theo từng chủ đề, có tóm tắt nhanh và bài luyện ngay sau bài học.'),
        const SizedBox(height: 14),
        if (progress.lastTopic != null && progress.lastTopic!.trim().isNotEmpty)
          _quickStartCard(
            icon: Icons.play_circle_fill_rounded,
            color: AppColors.info,
            title: 'Tiếp tục bài đang học',
            subtitle:
                '${progress.lastTopic} · ${progress.topics[progress.lastTopic]?.sessions ?? 0} phiên đã học',
            buttonText: 'Mở bài học',
            onTap: () {
              final topic = topics.firstWhere(
                (item) => item.title == progress.lastTopic,
                orElse: () => topics.first,
              );
              _showTopicSheet(context, topic);
            },
          ),
        if (progress.lastTopic != null && progress.lastTopic!.trim().isNotEmpty)
          const SizedBox(height: 18),
        ...topics.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _topicCard(context, entry.value, entry.key + 1, progress),
            )),
      ],
    );
  }

  Widget _buildPractice(
      BuildContext context, MathProgressModel progress, int streakDays) {
    final accuracyPercent = (progress.accuracy * 100).round();
    final topics = _topicsForGrade(_grade);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Luyện tập theo chuyên đề',
            'Mỗi chuyên đề có bộ câu hỏi riêng. Chọn một chuyên đề để làm 10 câu ngẫu nhiên đúng phần đang học.'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: _statCard('${progress.totalQuestions}', 'câu đã làm',
                    Icons.edit_note_rounded, AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(
                child: _statCard('$accuracyPercent%', 'độ chính xác',
                    Icons.insights_rounded, AppColors.success)),
            const SizedBox(width: 10),
            Expanded(
                child: _statCard('$streakDays', 'ngày liên tục',
                    Icons.local_fire_department, AppColors.secondary)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Bài tập của khối đang chọn',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...topics.map((topic) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _topicPracticeCard(context, topic, progress),
            )),
      ],
    );
  }

  Widget _topicPracticeCard(
      BuildContext context, _MathTopic topic, MathProgressModel progress) {
    final questionCount =
        MathPracticeCatalog.questionsForLesson(topic.id).length;
    final topicProgress = progress.topics[topic.title];
    final completed = topicProgress?.sessions ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: () =>
          _startExam(context, 'Luyện tập ${topic.title}', topic: topic),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: topic.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.bolt_rounded, color: topic.color, size: 25),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 5),
                  Text(
                    '$questionCount câu ngẫu nhiên · ${completed == 0 ? 'Chưa luyện' : '$completed phiên đã làm'}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill_rounded, color: topic.color, size: 29),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignments(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Bài tập giáo viên giao',
            'Theo dõi hạn nộp và hoàn thành bài tập Toán của lớp bạn.'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_turned_in_rounded,
                    color: AppColors.primary, size: 35),
              ),
              const SizedBox(height: 14),
              const Text('Bài tập của lớp được tập trung ở đây',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 7),
              const Text(
                'Các bài Toán do giáo viên giao sẽ hiển thị hạn nộp, số câu và kết quả của bạn. Những bài chưa có sẽ được cập nhật tự động khi giáo viên giao bài.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const StudentAssignmentsScreen())),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Xem bài tập được giao'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _infoRow(Icons.notifications_active_outlined, 'Bật nhắc hạn nộp',
            'PetMath sẽ nhắc bạn trước ngày hết hạn.'),
        _infoRow(Icons.insights_outlined, 'Theo dõi tiến độ',
            'Kết quả nộp bài được lưu để giáo viên hỗ trợ kịp thời.'),
      ],
    );
  }

  Widget _buildExams(BuildContext context) {
    final exams = [
      _ExamPreset('Kiểm tra 15 phút', 'Hàm số · 10 câu · 15 phút',
          Icons.timer_outlined, AppColors.info),
      _ExamPreset('Đề giữa kỳ tham khảo', 'Tổng hợp $_grade · 20 câu · 45 phút',
          Icons.description_outlined, AppColors.primary),
      _ExamPreset('Đề cuối kỳ tham khảo', 'Bao quát học kỳ · 30 câu · 60 phút',
          Icons.school_outlined, AppColors.secondary),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Phòng đề kiểm tra',
            'Làm thử trong không gian mô phỏng, xem kết quả và rèn tốc độ.'),
        const SizedBox(height: 14),
        // Đề tốt nghiệp THPT chỉ thực sự "vào guồng" ở khối 12 — khối 10/11
        // vẫn thấy để làm quen sớm nhưng ở dạng nhẹ nhàng hơn, tránh gây
        // hiểu lầm là các em phải thi tốt nghiệp ngay từ lớp 10/11.
        _grade == 12
            ? _graduationExamBanner(context)
            : _graduationExamPreviewCard(context),
        const SizedBox(height: 22),
        const Text('Đề luyện theo giai đoạn',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...exams.map((exam) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(19),
                onTap: () => _startExam(context, exam.title),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: exam.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(15)),
                        child: Icon(exam.icon, color: exam.color),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(exam.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 3),
                            Text(exam.subtitle,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            )),
        const SizedBox(height: 8),
        _noticeCard(
            'Mẹo làm đề',
            'Đọc kỹ yêu cầu, đánh dấu câu khó và dành 5 phút cuối để rà soát đáp án.',
            Icons.lightbulb_outline_rounded),
      ],
    );
  }

  /// Banner nổi bật riêng cho đề "Ôn thi tốt nghiệp THPT" — vai trò tương tự
  /// banner "Phòng Thi Ảo" của các dashboard luyện thi: đặt ngay đầu mục để
  /// học sinh vào thẳng đề tổng hợp quan trọng nhất mà không cần cuộn tìm.
  Widget _graduationExamBanner(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => _startExam(context, 'Ôn thi tốt nghiệp THPT'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppGradients.heroPrimary,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.26),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: AppColors.gold, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('PHÒNG THI ẢO',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                  ),
                  const SizedBox(height: 8),
                  const Text('Ôn thi tốt nghiệp THPT',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Tổng hợp 3 khối · 40 câu · 90 phút',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  /// Bản "xem trước" của banner tốt nghiệp — dùng cho khối 10/11. Vẫn bấm
  /// vào làm thử được (đề tổng hợp 3 khối không có gì sai khi luyện sớm),
  /// nhưng thiết kế nhạt màu, ghi rõ "xem trước" thay vì đặt ngang hàng với
  /// banner nổi bật của khối 12 — tránh học sinh mới lớp 10 tưởng mình sắp
  /// phải thi tốt nghiệp.
  Widget _graduationExamPreviewCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _startExam(context, 'Ôn thi tốt nghiệp THPT'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.emoji_events_outlined,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text('Ôn thi tốt nghiệp THPT',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('XEM TRƯỚC',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 8,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đề tổng hợp 3 khối · dành cho khối 12, khối $_grade có thể làm thử sớm.',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildLibrary(BuildContext context) {
    final resources = [
      _ResourceSource(
        name: 'Môn Toán',
        description:
            'SGK, SBT, chuyên đề và đề thi Toán 10, 11, 12 theo từng bộ sách.',
        url: 'https://montoan.com.vn/thpt-trung-hoc-pho-thong',
        color: AppColors.primary,
        icon: Icons.menu_book_rounded,
      ),
      _ResourceSource(
        name: 'Tài liệu Môn Toán',
        description:
            'Kho chuyên đề, lý thuyết, đề giữa kỳ, đề học kỳ và bài tập chọn lọc.',
        url: 'https://tailieumontoan.com/tai-lieu-toan-thpt-1',
        color: AppColors.info,
        icon: Icons.folder_copy_rounded,
      ),
      _ResourceSource(
        name: 'Luyện tập theo dạng bài — 9Study',
        description:
            'Luyện từng dạng bài THPT, có gợi ý AI về nội dung nên ôn trước.',
        url: 'https://9study.vn/phong-luyen-tap/dang-bai',
        color: AppColors.subjectAnh,
        icon: Icons.fact_check_rounded,
      ),
      _ResourceSource(
        name: 'Đề thi tốt nghiệp THPT — DolThpt',
        description:
            'Kho đề thi thử và đề thi chính thức tốt nghiệp THPT các năm.',
        url: 'https://dolthpt.vn/',
        color: AppColors.secondary,
        icon: Icons.emoji_events_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Thư viện tài liệu',
            'Học liệu theo chương trình khối $_grade, kèm nguồn tham khảo và đề luyện bên ngoài.'),
        const SizedBox(height: 14),
        const Text('Danh mục học liệu trong PetMath',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...MathCurriculumCatalog.lessonsForGrade(_grade)
            .map((lesson) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _libraryLessonCard(context, lesson),
                )),
        const SizedBox(height: 8),
        const Text('Nguồn tham khảo ngoài ứng dụng',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...resources.map((resource) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _resourceCard(context, resource),
            )),
        const SizedBox(height: 8),
        const Text('Nhóm nội dung nên học tiếp',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 11),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Hàm số & đồ thị',
            'Lượng giác',
            'Dãy số & cấp số',
            'Hình học không gian',
            'Tích phân',
            'Xác suất – thống kê',
            'Toán thực tế',
            'Ôn thi tốt nghiệp',
          ]
              .map((label) => Chip(
                    label: Text(label),
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        _noticeCard(
            'Lưu ý bản quyền',
            'PetMath chỉ lưu thông tin mô tả và liên kết tham khảo. Khi mở tài liệu, hãy tuân thủ điều khoản của từng nguồn.',
            Icons.verified_user_outlined),
      ],
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(
                color: AppColors.textSecondary, height: 1.35, fontSize: 13)),
      ],
    );
  }

  Widget _quickStartCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(buttonText)),
        ],
      ),
    );
  }

  Widget _topicCard(BuildContext context, _MathTopic topic, int index,
      MathProgressModel progress) {
    final topicProgress = progress.topics[topic.title];
    final hasStudied = topicProgress != null && topicProgress.sessions > 0;

    return InkWell(
      onTap: () => _showTopicSheet(context, topic),
      borderRadius: BorderRadius.circular(19),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: topic.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Text('$index',
                  style: TextStyle(
                      color: topic.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 17)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(topic.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  hasStudied
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: hasStudied ? AppColors.success : topic.color,
                ),
                Text(
                  hasStudied ? '${topicProgress!.sessions} phiên' : 'Chưa học',
                  style: TextStyle(
                    color: hasStudied
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight:
                        hasStudied ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _practiceCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required String tag,
      required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _startExam(context, title),
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
              boxShadow: AppShadows.card),
          child: Row(
            children: [
              Icon(icon, color: color, size: 31),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                            child: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15))),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(tag,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.play_arrow_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _libraryLessonCard(BuildContext context, MathLessonData lesson) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MathLessonScreen(lesson: lesson),
      )),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.auto_stories_rounded,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.unit,
                      style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(lesson.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                      '${lesson.objectives.length} mục tiêu · ${lesson.formulas.length} nhóm công thức',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _resourceCard(BuildContext context, _ResourceSource resource) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: resource.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(resource.icon, color: resource.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resource.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(resource.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.35,
                        fontSize: 12)),
                const SizedBox(height: 8),
                Text(resource.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: resource.color, fontSize: 10)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _copyUrl(context, resource.url),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Sao chép liên kết'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: resource.color,
                    side: BorderSide(
                        color: resource.color.withValues(alpha: 0.4)),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticeCard(String title, String body, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_MathTopic> _topicsForGrade(int grade) {
    const colors = [
      AppColors.primary,
      AppColors.info,
      AppColors.success,
      AppColors.secondary,
      Color(0xFFEF767A),
    ];
    return MathCurriculumCatalog.lessonsForGrade(grade)
        .asMap()
        .entries
        .map((entry) {
      final lesson = entry.value;
      return _MathTopic(
        lesson: lesson,
        color: colors[entry.key % colors.length],
        duration: '${lesson.objectives.length + lesson.checkpoints.length} mục',
      );
    }).toList();
  }

  void _startExam(BuildContext context, String title, {_MathTopic? topic}) {
    final presetQuestions =
        topic == null ? null : MathPracticeCatalog.questionsForLesson(topic.id);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExamScreen(
        subject: 'Toán',
        grade: _grade,
        topic: topic?.title,
        presetQuestions: presetQuestions,
        displayTitle: title,
      ),
    ));
  }

  void _showTopicSheet(BuildContext context, _MathTopic topic) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: topic.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15)),
                    child: Icon(Icons.functions_rounded, color: topic.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(topic.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 21)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Toán $_grade · ${topic.duration}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 10),
              Text(topic.description,
                  style: const TextStyle(height: 1.45, fontSize: 14)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MathLessonScreen(lesson: topic.lesson),
                    ));
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Mở học liệu đầy đủ'),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Gợi ý cách học',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text(
                  'Đọc phần khái niệm cốt lõi, xem ví dụ mẫu, sau đó làm một chặng luyện tập ngắn để kiểm tra mức độ nắm bài.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                      fontSize: 13)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _startExam(context, 'Luyện tập ${topic.title}',
                        topic: topic);
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Bắt đầu luyện tập'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyUrl(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép liên kết nguồn tài liệu.')),
    );
  }

  void _showGoalDialog(BuildContext context, MathProgressModel progress) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mục tiêu học Toán'),
        content: Text(progress.completedSessions == 0
            ? 'Bạn chưa hoàn thành phiên học Toán nào ở khối $_grade. Hãy bắt đầu một chuyên đề để tiến độ được cập nhật.'
            : 'Bạn đã hoàn thành ${progress.completedSessions} phiên học và ${progress.completedTopics} chuyên đề ở khối $_grade.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Để sau')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu')),
        ],
      ),
    );
  }
}

enum _MathSection { study, practice, assignments, exams, library }

class _MathTopic {
  final MathLessonData lesson;
  final String duration;
  final Color color;

  const _MathTopic({
    required this.lesson,
    required this.duration,
    required this.color,
  });

  String get id => lesson.id;
  String get title => lesson.title;
  String get description => lesson.overview;
}

class _ExamPreset {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ExamPreset(this.title, this.subtitle, this.icon, this.color);
}

class _ResourceSource {
  final String name;
  final String description;
  final String url;
  final Color color;
  final IconData icon;

  const _ResourceSource({
    required this.name,
    required this.description,
    required this.url,
    required this.color,
    required this.icon,
  });
}
