import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';

import '../data/word_chain_starters.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/vietnamese_lexicon_service.dart';
import '../theme/app_theme.dart';

class WordChainScreen extends StatefulWidget {
  const WordChainScreen({super.key});

  @override
  State<WordChainScreen> createState() => _WordChainScreenState();
}

class _WordChainScreenState extends State<WordChainScreen> {
  final _lexicon = VietnameseLexiconService.instance;
  final _controller = TextEditingController();
  final _random = Random();
  final _used = <String>{};
  final _history = <_ChainTurn>[];
  Timer? _timer;
  Timer? _thinkingTimer;

  String? _systemWord;
  String _requiredSyllable = '';
  String? _message;
  String? _pendingContinuation;
  bool _loading = true;
  bool _finished = false;
  bool _machineThinking = false;
  int _thinkingSecondsLeft = 0;
  int _machineDisplaySeconds = 30;
  int _round = 0;
  int _score = 0;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    await _lexicon.load();
    if (!mounted) return;
    setState(_startRound);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finished || _loading || _machineThinking) return;
      if (_secondsLeft <= 1) {
        _finish('Hết thời gian');
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _startRound() {
    final available = wordChainStarterPhrases.where((word) {
      if (!_lexicon.contains(word) || !_lexicon.isPlayableChainWord(word)) {
        return false;
      }
      // Không khởi động bằng một từ khiến người chơi bị kẹt ngay lập tức.
      return _lexicon.hasUnusedContinuation(word, <String>{word});
    }).toList();
    final word = available.isEmpty
        ? 'học tập'
        : available[_random.nextInt(available.length)];
    _systemWord = word;
    _requiredSyllable = _lexicon.lastSyllable(word);
    _used.add(word);
    _history.add(_ChainTurn(word: word, fromSystem: true));
    _round = 1;
    _secondsLeft = 30;
    _loading = false;
  }

  void _submit() {
    if (_machineThinking || _finished || _loading) return;

    final raw = _controller.text.trim();
    final word = _lexicon.normalize(raw);
    if (word.isEmpty) return;

    final firstSyllable = word.split(' ').first;
    final resolved = _lexicon.resolveForChain(word, _requiredSyllable, _used);
    if (resolved == null) {
      final aliasCanStartCorrectly = _lexicon.normalizedForms(word).any(
            (form) =>
                _lexicon.normalize(form).split(' ').first == _requiredSyllable,
          );
      if (_used.contains(word)) {
        setState(() => _message = 'Từ này đã được dùng trong ván hiện tại.');
      } else if (firstSyllable != _requiredSyllable &&
          !aliasCanStartCorrectly) {
        setState(() =>
            _message = 'Từ của bạn phải bắt đầu bằng “$_requiredSyllable”.');
      } else {
        setState(() =>
            _message = 'Từ này chưa có trong từ điển có nghĩa của trò chơi.');
      }
      return;
    }

    _used.add(resolved);
    _history.add(_ChainTurn(word: resolved, fromSystem: false));
    final nextSyllable = _lexicon.lastSyllable(resolved);
    final continuation =
        _lexicon.randomContinuation(nextSyllable, _used, _random);
    _controller.clear();

    if (continuation == null) {
      _score += 2;
      _finish('Không còn từ có thể nối tiếp hợp lệ.');
      return;
    }

    _round++;
    _score++;
    _beginMachineThinking(continuation);
  }

  void _beginMachineThinking(String continuation) {
    _thinkingTimer?.cancel();
    _pendingContinuation = continuation;
    _machineThinking = true;
    _thinkingSecondsLeft =
        5 + _random.nextInt(11); // Thời gian nội bộ 5..15 giây, không hiển thị.
    _machineDisplaySeconds = 30;
    setState(() => _message = 'Máy đang suy nghĩ để chọn từ nối tiếp');

    _thinkingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finished) return;
      if (_thinkingSecondsLeft <= 1) {
        _thinkingTimer?.cancel();
        _thinkingTimer = null;
        _completeMachineTurn();
      } else {
        setState(() {
          _thinkingSecondsLeft--;
          if (_machineDisplaySeconds > 1) _machineDisplaySeconds--;
          _message = 'Máy đang suy nghĩ để chọn từ nối tiếp';
        });
      }
    });
  }

  void _completeMachineTurn() {
    final continuation = _pendingContinuation;
    if (continuation == null || _finished) return;

    _pendingContinuation = null;
    _used.add(continuation);
    _history.add(_ChainTurn(word: continuation, fromSystem: true));
    _systemWord = continuation;
    _requiredSyllable = _lexicon.lastSyllable(continuation);
    _machineThinking = false;
    _thinkingSecondsLeft = 0;
    _machineDisplaySeconds = 30;
    // Chỉ khi máy đã nối xong, người chơi mới nhận một lượt mới đủ 30 giây.
    _secondsLeft = 30;
    setState(() => _message = null);
  }

  Future<void> _finish(String message) async {
    if (_finished) return;
    _thinkingTimer?.cancel();
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _finished = true;
        _machineThinking = false;
        _pendingContinuation = null;
        _message = message;
      });
    }
    final auth = context.read<AuthProvider>();
    final reward = _score * 3;
    if (reward > 0 && auth.currentStudent != null) {
      await FirestoreService()
          .claimMiniGameReward(auth.currentStudent!.uid, reward);
      auth.currentStudent = auth.currentStudent?.copyWith(
        coin: auth.currentStudent!.coin + reward,
      );
      auth.notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _thinkingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ScreenScaffold(bg: BgKind.cream, body: Center(child: CircularProgressIndicator()));
    }
    if (_finished) return _buildResult();

    return ScreenScaffold(bg: BgKind.cream, 
      appBar: AppBar(title: const Text('Nối từ tiếng Việt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildChainCard(),
            const SizedBox(height: 16),
            Text(
              _machineThinking
                  ? 'Máy đang suy nghĩ để chọn từ nối tiếp'
                  : 'Nhập một từ bắt đầu bằng “$_requiredSyllable”',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: !_machineThinking,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: _machineThinking
                    ? 'Đang chờ máy nối từ...'
                    : 'Ví dụ: $_requiredSyllable ...',
                suffixIcon: IconButton(
                  onPressed: _machineThinking ? null : _submit,
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_message != null && !_machineThinking)
              Text(
                _message!,
                style: const TextStyle(color: AppColors.danger),
              ),
            const SizedBox(height: 18),
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final timerText = _machineThinking
        ? 'Máy\n$_machineDisplaySeconds s'
        : 'Bạn\n$_secondsLeft s';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF4FACFE)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Text('🔗', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vua nối từ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Từ có nghĩa • Không lặp từ • Lượt mới 30 giây',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                timerText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Điểm $_score',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChainCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _machineThinking
            ? Column(
                children: [
                  const Text(
                    'Máy đang suy nghĩ để chọn từ nối tiếp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                ],
              )
            : Column(
                children: [
                  const Text(
                    'Từ hệ thống đưa ra',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _systemWord ?? '',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Âm tiết tiếp theo: $_requiredSyllable',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chuỗi từ trong ván',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _history.map((turn) {
                return Chip(
                  avatar: Text(turn.fromSystem ? '🤖' : '🙂'),
                  label: Text(turn.word),
                  backgroundColor: turn.fromSystem
                      ? AppColors.info.withValues(alpha: 0.12)
                      : AppColors.secondary.withValues(alpha: 0.16),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final reward = _score * 3;
    return ScreenScaffold(bg: BgKind.cream, 
      appBar: AppBar(title: const Text('Kết quả nối từ')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 14),
              Text(
                _message ?? 'Hoàn thành!',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Điểm: $_score • Thưởng: $reward Coin',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
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

class _ChainTurn {
  final String word;
  final bool fromSystem;
  const _ChainTurn({required this.word, required this.fromSystem});
}
