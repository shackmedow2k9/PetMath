import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../models/cipher_data.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Ngân hàng cụm từ (không dấu, chữ HOA) dùng làm đáp án cho Giải mật mã.
const List<String> _cipherAnswers = [
  'HOC SINH',
  'CON MEO',
  'MAT TROI',
  'TOAN HOC',
  'TRUONG HOC',
  'MUA XUAN',
  'BAI TAP',
  'CON CA',
  'QUYEN SACH',
  'MAY TINH',
  'NIEM VUI',
  'UOC MO',
];

const int _hintGemCost = 2;
const int _questionsPerRound = 10;

/// Mini game Giải mật mã — mỗi lượt chơi tốn 1 Vé (mua ở Cửa hàng, 10
/// Coin/vé). Mỗi vé random ra 1 loại mật mã + 1 độ khó, áp dụng cho cả 10
/// câu của lượt đó (khóa vẫn ngẫu nhiên riêng từng câu). Học sinh tự gõ đáp
/// án thay vì chọn trắc nghiệm; có thể mua gợi ý bằng Gem (hé lộ từng chữ).
class CipherScreen extends StatefulWidget {
  const CipherScreen({super.key});

  @override
  State<CipherScreen> createState() => _CipherScreenState();
}

class _CipherScreenState extends State<CipherScreen> {
  final _answerController = TextEditingController();

  // Trạng thái của lượt chơi hiện tại (null = chưa dùng vé để bắt đầu).
  CipherFamily? _family;
  List<String> _answers = [];
  List<String> _cipherTexts = [];
  final Set<int> _revealed = {};
  int _currentIndex = 0;
  int _score = 0;
  bool _finished = false;
  bool _isStartingRound = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _startRound() async {
    setState(() => _isStartingRound = true);
    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent!;

    final consumed = await FirestoreService().consumeCipherTicket(student.uid);
    if (!consumed) {
      if (mounted) {
        setState(() => _isStartingRound = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bạn đã hết vé rồi! Hãy mua thêm ở Cửa hàng nhé.')),
        );
      }
      return;
    }

    auth.currentStudent =
        student.copyWith(cipherTickets: student.cipherTickets - 1);
    auth.notifyListeners();

    final random = Random();
    final difficulty =
        CipherDifficulty.values[random.nextInt(CipherDifficulty.values.length)];
    final candidates = familiesForTier(difficulty.tier);
    final family = candidates[random.nextInt(candidates.length)];

    final answers = (List<String>.from(_cipherAnswers)..shuffle(random))
        .take(_questionsPerRound)
        .toList();
    final cipherTexts =
        answers.map((a) => family.encode(a, difficulty, random)).toList();

    setState(() {
      _family = family;
      _answers = answers;
      _cipherTexts = cipherTexts;
      _currentIndex = 0;
      _score = 0;
      _finished = false;
      _isStartingRound = false;
      _revealed.clear();
      _answerController.clear();
    });
  }

  String _normalize(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<int> get _letterPositions {
    final answer = _answers[_currentIndex];
    return [
      for (int i = 0; i < answer.length; i++)
        if (answer[i] != ' ') i
    ];
  }

  int get _maxHints => max(0, _letterPositions.length - 1);

  Future<void> _useHint() async {
    if (_revealed.length >= _maxHints) return;

    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent!;
    if (!student.hasEnoughGem(_hintGemCost)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không đủ Gem để mua gợi ý!')),
      );
      return;
    }

    final success =
        await FirestoreService().spendGemForHint(student.uid, _hintGemCost);
    if (!success) return;

    auth.currentStudent = student.copyWith(gem: student.gem - _hintGemCost);
    auth.notifyListeners();

    final unrevealed =
        _letterPositions.where((i) => !_revealed.contains(i)).toList();
    if (unrevealed.isEmpty) return;
    unrevealed.shuffle();

    setState(() => _revealed.add(unrevealed.first));
  }

  Future<void> _submit() async {
    final guess = _normalize(_answerController.text);
    if (guess.isEmpty) return;

    if (guess != _answers[_currentIndex]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sai rồi, thử lại nhé! 🤔')),
      );
      return;
    }

    _score++;

    if (_currentIndex < _answers.length - 1) {
      setState(() {
        _currentIndex++;
        _revealed.clear();
        _answerController.clear();
      });
    } else {
      final coinReward = _score * 20;
      final auth = context.read<AuthProvider>();
      if (coinReward > 0) {
        await FirestoreService()
            .claimMiniGameReward(auth.currentStudent!.uid, coinReward);
        auth.currentStudent = auth.currentStudent
            ?.copyWith(coin: auth.currentStudent!.coin + coinReward);
        auth.notifyListeners();
      }
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent!;

    // Chip nhỏ hiển thị số vé đang có — thêm duy nhất phần này vào AppBar.
    final ticketChip = Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: Row(children: [
          const Text('🎫', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text('${student.cipherTickets}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
    );

    if (_family == null) {
      return ScreenScaffold(bg: BgKind.lavender, 
        appBar: AppBar(title: const Text('Giải mật mã'), actions: [ticketChip]),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🕵️‍♂️🔐', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'Mỗi vé cho 1 lượt chơi $_questionsPerRound câu - độ khó từ dễ đến siêu khó, sử dụng gợi ý cần $_hintGemCost kim cương cho 1 câu hỏi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                if (student.cipherTickets > 0)
                  ElevatedButton(
                    onPressed: _isStartingRound ? null : _startRound,
                    child: Text(_isStartingRound
                        ? 'Đang bắt đầu...'
                        : 'Dùng 1 vé để chơi 🎲'),
                  )
                else
                  const Text(
                      'Bạn đã hết vé! Hãy mua thêm ở Cửa hàng (10 Coin/vé).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger)),
              ],
            ),
          ),
        ),
      );
    }

    if (_finished) {
      final coinReward = _score * 20;
      return ScreenScaffold(bg: BgKind.lavender, 
        appBar: AppBar(title: const Text('Giải mật mã'), actions: [ticketChip]),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🕵️‍♂️🔓', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('Giải đúng $_score/${_answers.length} mật mã',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Nhận được 🪙 $coinReward Coin',
                  style: const TextStyle(
                      color: AppColors.success, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }

    final answer = _answers[_currentIndex];
    final cipherText = _cipherTexts[_currentIndex];
    final masked = [
      for (int i = 0; i < answer.length; i++)
        answer[i] == ' ' ? '   ' : (_revealed.contains(i) ? answer[i] : '_'),
    ].join();

    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(
        title: Text('Giải mật mã (${_currentIndex + 1}/${_answers.length})'),
        actions: [ticketChip],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5),
                ),
                child: Column(
                  children: [
                    Text('🔐 ${_family!.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    const SizedBox(height: 10),
                    SelectableText(
                      cipherText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(_family!.hint,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                masked,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _answerController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                decoration:  InputDecoration(
                  labelText: tr('Gõ đáp án của bạn'),
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _submit, child: const Text('Nộp đáp án')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _revealed.length >= _maxHints ? null : _useHint,
                icon: const Text('💡', style: TextStyle(fontSize: 16)),
                label: Text('Gợi ý (💎 $_hintGemCost)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
