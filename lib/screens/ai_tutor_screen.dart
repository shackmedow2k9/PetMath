import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_answer_view.dart';
import 'math_3d_request_screen.dart';

class AiTutorScreen extends StatefulWidget {
  final String questionText;
  final List<String> options;
  final String? questionId;
  final String? assignmentId;
  final String? submissionId;
  final bool isExamOrAssignment;
  final bool hasSubmitted;

  const AiTutorScreen({
    super.key,
    required this.questionText,
    required this.options,
    this.questionId,
    this.assignmentId,
    this.submissionId,
    this.isExamOrAssignment = false,
    this.hasSubmitted = true,
  });

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _service = FirestoreService();
  final _questionController = TextEditingController();
  String? _answer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _questionController.text = 'Em chưa biết bắt đầu từ đâu.';
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _open3DBuilder() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const Math3DRequestScreen()),
    );
  }

  Future<void> _ask(String mode) async {
    if (widget.isExamOrAssignment && !widget.hasSubmitted) {
      setState(() => _error = 'Hãy nộp bài trước khi hỏi gia sư AI.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _answer = null;
    });
    try {
      final result = await _service.askMathTutor(
        mode: mode,
        questionText:
            '${widget.questionText}\n\nCâu hỏi của học sinh: ${_questionController.text.trim()}',
        options: widget.options,
        questionId: widget.questionId,
        assignmentId: widget.assignmentId,
        submissionId: widget.submissionId,
        isExamOrAssignment: widget.isExamOrAssignment,
      );
      if (mounted) setState(() => _answer = result['text']?.toString() ?? '');
    } catch (e) {
      if (mounted) setState(() => _error = 'Gia sư AI chưa sẵn sàng: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent;
    final gemText = student == null || student.gemInfinite
        ? 'Không giới hạn Gem'
        : '${student.gem} Gem';

    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(
        title: const Text('Gia sư AI'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Card(
            color: AppColors.primary.withValues(alpha: 0.07),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AiAnswerView(
                widget.questionText,
                style: const TextStyle(height: 1.45),
              ),
            ),
          ),
          if (widget.isExamOrAssignment && !widget.hasSubmitted)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Bài kiểm tra/bài giáo viên giao chỉ mở gia sư sau khi bạn nộp bài.',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _questionController,
            maxLines: 3,
            decoration:  InputDecoration(
              labelText: tr('Em muốn hỏi điều gì?'),
              hintText: tr('VD: Em chưa hiểu bước biến đổi này.'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : () => _ask('hint'),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Gợi ý từng bước — miễn phí'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _ask('answer'),
            icon: const Icon(Icons.lock_open),
            label: Text('Mở đáp án đầy đủ — 10 Gem ($gemText)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _open3DBuilder,
            icon: const Icon(Icons.view_in_ar_outlined),
            label: const Text('Vẽ hình 3D theo yêu cầu bài toán'),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.danger)),
            ),
          if (_answer != null) ...[
            const SizedBox(height: 20),
            const Text('Phản hồi của gia sư',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AiAnswerView(_answer!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
