import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';

import '../theme/app_theme.dart';

class WordScrambleScreen extends StatefulWidget {
  const WordScrambleScreen({super.key});

  @override
  State<WordScrambleScreen> createState() => _WordScrambleScreenState();
}

class _WordScrambleScreenState extends State<WordScrambleScreen> {
  final _input = TextEditingController();
  final _random = Random();
  final _puzzles = <_ScramblePuzzle>[
    _ScramblePuzzle('lao công', 'A/L/Ô/C/O/N/G', 'Nghề giữ gìn vệ sinh'),
    _ScramblePuzzle(
        'cầu vồng', 'Ồ/V/C/Ầ/U/N/G', 'Hiện tượng nhiều màu sau mưa'),
    _ScramblePuzzle('bút chì', 'Ì/B/Ú/T/C/H', 'Dụng cụ dùng để viết và vẽ'),
    _ScramblePuzzle('bảo tàng', 'À/B/T/Ả/O/N/G', 'Nơi lưu giữ hiện vật'),
    _ScramblePuzzle(
        'nhà khoa học', 'Ọ/N/H/A/H/O/C/K/À/I', 'Người nghiên cứu khoa học'),
    _ScramblePuzzle(
        'trường học', 'Ọ/T/R/H/Ư/N/G/H/Ọ/C', 'Nơi học sinh học tập'),
    _ScramblePuzzle('đại dương', 'D/Ư/Ơ/N/Ạ/G/I/Đ', 'Vùng nước mặn rộng lớn'),
    _ScramblePuzzle(
        'mặt trăng', 'Ă/T/M/R/N/G/Ặ', 'Vệ tinh tự nhiên của Trái Đất'),
    _ScramblePuzzle('thư viện', 'Ệ/V/T/H/Ư/I/N', 'Nơi đọc và mượn sách'),
    _ScramblePuzzle(
        'phi hành gia', 'A/P/H/I/G/N/H/À/H/I', 'Người bay vào không gian'),
    _ScramblePuzzle(
        'nhân vật', 'V/Ậ/N/H/Â/T/N', 'Người hoặc hình tượng trong truyện'),
    _ScramblePuzzle('bình minh', 'N/H/B/I/N/M/H', 'Thời điểm bắt đầu một ngày'),
    _ScramblePuzzle(
        'Hồ Chí Minh', 'M/H/Í/H/C/H/Ồ/N/I', 'Tên một vị lãnh tụ của dân tộc'),
    _ScramblePuzzle('Nguyễn Du', 'D/U/Y/Ễ/N/G/N', 'Tác giả Truyện Kiều'),
    _ScramblePuzzle(
        'Thạch Sanh', 'S/A/N/H/T/H/Ạ/C/H', 'Nhân vật trong truyện cổ tích'),
  ];
  late List<_ScramblePuzzle> _rounds;
  int _index = 0;
  int _score = 0;
  bool _answered = false;
  bool _finished = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _rounds = [..._puzzles]..shuffle(_random);
  }

  void _submit() {
    if (_answered) return;
    final puzzle = _rounds[_index];
    final answer = _normalize(_input.text);
    final correct = answer == _normalize(puzzle.answer);
    setState(() {
      _answered = true;
      _feedback =
          correct ? 'Chính xác! +2 điểm' : 'Đáp án đúng: ${puzzle.answer}';
      if (correct) _score += 2;
    });
  }

  void _next() {
    if (_index >= _rounds.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _answered = false;
      _feedback = null;
      _input.clear();
    });
  }

  String _normalize(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return _ResultScreen(
          title: 'Sắp xếp từ', score: _score, total: _rounds.length);
    }
    final puzzle = _rounds[_index];
    return ScreenScaffold(bg: BgKind.cream, 
      appBar: AppBar(title: Text('Sắp xếp từ ${_index + 1}/${_rounds.length}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _GameBanner(icon: '🧩', title: 'Xáo trộn từ', subtitle: puzzle.clue),
          const SizedBox(height: 18),
          Text('Các chữ cái đã bị trộn',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
              child: Text(puzzle.scrambled,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            enabled: !_answered,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration:  InputDecoration(
                labelText: tr('Nhập lại từ/cụm từ đúng'),
                prefixIcon: Icon(Icons.edit_rounded)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _answered ? null : _submit,
              child: const Text('Kiểm tra')),
          if (_feedback != null) ...[
            const SizedBox(height: 14),
            Text(_feedback!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _feedback!.startsWith('Chính')
                        ? AppColors.success
                        : AppColors.danger)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _next,
                child: Text(_index == _rounds.length - 1
                    ? 'Xem kết quả'
                    : 'Câu tiếp theo')),
          ],
        ],
      ),
    );
  }
}

class ProverbGuessScreen extends StatefulWidget {
  const ProverbGuessScreen({super.key});

  @override
  State<ProverbGuessScreen> createState() => _ProverbGuessScreenState();
}

class _ProverbGuessScreenState extends State<ProverbGuessScreen> {
  final _random = Random();
  final _questions = <_ChoiceQuestion>[
    _ChoiceQuestion(
        'Có công mài sắt, có ngày nên ...', ['kim', 'vàng', 'đá', 'ngọc'], 0),
    _ChoiceQuestion('Đi một ngày đàng, học một ... sàng khôn',
        ['trăm', 'ngàn', 'vạn', 'vốn'], 1),
    _ChoiceQuestion('Uống nước nhớ ...', ['nguồn', 'sông', 'mưa', 'giếng'], 0),
    _ChoiceQuestion('Ăn quả nhớ kẻ trồng ...', ['hoa', 'cây', 'quả', 'đất'], 1),
    _ChoiceQuestion('Lá lành đùm lá ...', ['đẹp', 'xanh', 'rách', 'non'], 2),
    _ChoiceQuestion(
        'Gần mực thì đen, gần đèn thì ...', ['sáng', 'rực', 'vui', 'tỏ'], 0),
    _ChoiceQuestion(
        'Một cây làm chẳng nên non, ba cây chụm lại nên hòn núi ...',
        ['cao', 'lớn', 'non', 'xanh'],
        0),
    _ChoiceQuestion('Thất bại là mẹ của ...',
        ['thành công', 'hy vọng', 'ước mơ', 'nỗ lực'], 0),
  ];
  late List<_ChoiceQuestion> _rounds;
  int _index = 0;
  int _score = 0;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _rounds = [..._questions]..shuffle(_random);
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _rounds.length)
      return _ResultScreen(
          title: 'Đoán thành ngữ', score: _score, total: _rounds.length);
    final q = _rounds[_index];
    return ScreenScaffold(bg: BgKind.cream, 
      appBar:
          AppBar(title: Text('Đoán thành ngữ ${_index + 1}/${_rounds.length}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _GameBanner(
              icon: '📖',
              title: 'Mảnh ghép thành ngữ',
              subtitle: 'Chọn từ còn thiếu để hoàn thành câu'),
          const SizedBox(height: 22),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(q.prompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 16),
          ...List.generate(q.options.length, (i) {
            final selected = _selected == i;
            final correct = i == q.correctIndex;
            Color color = Colors.white;
            if (_selected != null && correct)
              color = AppColors.success.withValues(alpha: 0.18);
            if (_selected == i && !correct)
              color = AppColors.danger.withValues(alpha: 0.18);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: _selected == null ? () => _answer(i) : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2)),
                    child: Text(q.options[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
              ),
            );
          }),
          if (_selected != null)
            OutlinedButton(
                onPressed: () => setState(() {
                      _index++;
                      _selected = null;
                    }),
                child: Text(_index == _rounds.length - 1
                    ? 'Xem kết quả'
                    : 'Câu tiếp theo')),
        ],
      ),
    );
  }

  void _answer(int index) {
    setState(() {
      _selected = index;
      if (index == _rounds[_index].correctIndex) _score++;
    });
  }
}

class SynonymGameScreen extends StatefulWidget {
  const SynonymGameScreen({super.key});

  @override
  State<SynonymGameScreen> createState() => _SynonymGameScreenState();
}

class _SynonymGameScreenState extends State<SynonymGameScreen> {
  final _random = Random();
  final _questions = <_ChoiceQuestion>[
    _ChoiceQuestion('Từ nào gần nghĩa với “siêng năng”?',
        ['lười biếng', 'chăm chỉ', 'vội vàng', 'yên tĩnh'], 1),
    _ChoiceQuestion('Từ nào gần nghĩa với “dũng cảm”?',
        ['gan dạ', 'nhút nhát', 'mệt mỏi', 'hiền lành'], 0),
    _ChoiceQuestion('Từ nào gần nghĩa với “bình minh”?',
        ['hoàng hôn', 'rạng đông', 'buổi trưa', 'đêm khuya'], 1),
    _ChoiceQuestion('Từ nào gần nghĩa với “sạch sẽ”?',
        ['gọn gàng', 'ồn ào', 'nhanh nhẹn', 'khó khăn'], 0),
    _ChoiceQuestion('Từ nào gần nghĩa với “thông minh”?',
        ['sáng dạ', 'vụng về', 'chậm chạp', 'buồn bã'], 0),
    _ChoiceQuestion('Từ nào gần nghĩa với “quê hương”?',
        ['đất nước', 'quê nhà', 'núi non', 'xóm nhỏ'], 1),
  ];
  late List<_ChoiceQuestion> _rounds;
  int _index = 0;
  int _score = 0;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _rounds = [..._questions]..shuffle(_random);
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _rounds.length)
      return _ResultScreen(
          title: 'Tìm từ đồng nghĩa', score: _score, total: _rounds.length);
    final q = _rounds[_index];
    return ScreenScaffold(bg: BgKind.cream, 
      appBar:
          AppBar(title: Text('Từ đồng nghĩa ${_index + 1}/${_rounds.length}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _GameBanner(
              icon: '🔍',
              title: 'Thợ săn từ hay',
              subtitle: 'Chọn đáp án gần nghĩa nhất'),
          const SizedBox(height: 22),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(q.prompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 16),
          ...List.generate(q.options.length, (i) {
            final selected = _selected == i;
            final correct = i == q.correctIndex;
            Color color = Colors.white;
            if (_selected != null && correct)
              color = AppColors.success.withValues(alpha: 0.18);
            if (selected && !correct)
              color = AppColors.danger.withValues(alpha: 0.18);
            return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                    onTap: _selected == null ? () => _answer(i) : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 2)),
                        child: Text(q.options[i],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)))));
          }),
          if (_selected != null)
            OutlinedButton(
                onPressed: () => setState(() {
                      _index++;
                      _selected = null;
                    }),
                child: Text(_index == _rounds.length - 1
                    ? 'Xem kết quả'
                    : 'Câu tiếp theo')),
        ],
      ),
    );
  }

  void _answer(int index) {
    setState(() {
      _selected = index;
      if (index == _rounds[_index].correctIndex) _score++;
    });
  }
}

class _ScramblePuzzle {
  final String answer;
  final String scrambled;
  final String clue;
  const _ScramblePuzzle(this.answer, this.scrambled, this.clue);
}

class _ChoiceQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  const _ChoiceQuestion(this.prompt, this.options, this.correctIndex);
}

class _GameBanner extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  const _GameBanner(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [AppColors.primary, AppColors.info]),
          borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 34)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70))
        ]))
      ]),
    );
  }
}

class _ResultScreen extends StatelessWidget {
  final String title;
  final int score;
  final int total;
  const _ResultScreen(
      {required this.title, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.cream, 
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 14),
              Text(
                '$score/$total điểm',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mỗi lượt chơi được xáo trộn lại để bạn luyện tập nhiều lần.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Về Vua Tiếng Việt'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
