import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

/// Bộ từ offline cho trò Nối từ tiếng Việt.
///
/// Service hợp nhất:
/// - Viet74K: danh sách lớn gồm từ và cụm từ tiếng Việt phổ biến.
/// - VietDictionaryWords: mục từ trích từ một bộ từ điển có định nghĩa.
/// - tu_ghep_bo_sung: danh sách từ ghép 2 âm tiết được chọn lọc thủ công để
///   bù các cặp từ còn thiếu, gồm cả từ hiện đại lẫn từ Hán Việt/từ cổ
///   thường gặp trong văn học (vd. "trượng phu", "sơn hà", "yết kiến"...).
/// - vi-nsw-dict: các biến thể hiện đại/khẩu ngữ có ánh xạ về dạng chuẩn.
///
/// Không có bộ dữ liệu offline nào có thể cam kết bao phủ tuyệt đối mọi từ
/// tiếng Việt. Khi cập nhật asset, service này có thể nạp thêm dữ liệu mà
/// không phải đổi luật chơi.
class VietnameseLexiconService {
  VietnameseLexiconService._();

  static final VietnameseLexiconService instance = VietnameseLexiconService._();

  Set<String> _words = <String>{};
  Map<String, List<String>> _byFirstSyllable = <String, List<String>>{};
  Map<String, List<String>> _modernAliases = <String, List<String>>{};
  bool _loaded = false;
  Future<void>? _loading;

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _loadAssets();
  }

  Future<void> _loadAssets() async {
    final accepted = <String>{};
    final aliases = <String, List<String>>{};

    await _loadWordLines('assets/vietnamese_lexicon/Viet74K.txt', accepted);
    await _loadWordLines(
      'assets/vietnamese_lexicon/VietDictionaryWords.txt',
      accepted,
    );
    // Danh sách chọn lọc thủ công, bù các từ ghép 2 âm tiết còn thiếu.
    await _loadWordLines(
      'assets/vietnamese_lexicon/tu_ghep_bo_sung.txt',
      accepted,
    );

    try {
      final rawDictionary = await rootBundle.loadString(
        'assets/vietnamese_lexicon/vi-nsw-dict.json',
      );
      final dictionary = jsonDecode(rawDictionary);
      if (dictionary is Map) {
        for (final entry in dictionary.entries) {
          final alias = normalize('${entry.key}');
          final rawTargets = entry.value is List
              ? (entry.value as List).map((value) => normalize('$value'))
              : <String>[];
          final targets = rawTargets.where(isAcceptable).toSet().toList();
          if (targets.isEmpty || !isModernAliasAcceptable(alias)) continue;

          // Alias chỉ được dùng khi có dạng chuẩn có nghĩa. Khi đưa vào
          // chuỗi, WordChain sẽ ghi nhận dạng chuẩn để tránh các biến thể
          // làm phình bộ từ hoặc tạo đường nối giả.
          aliases[alias] = targets;
          accepted.addAll(targets);
        }
      }
    } catch (_) {
      // Lớp biến thể là tùy chọn, không làm mất dữ liệu chuẩn nếu lỗi.
    }

    if (accepted.isEmpty) accepted.addAll(_fallbackWords);
    _words = accepted;
    _modernAliases = aliases;
    _byFirstSyllable = <String, List<String>>{};

    for (final word in _words) {
      final first = word.split(' ').first;
      (_byFirstSyllable[first] ??= <String>[]).add(word);
    }
    for (final values in _byFirstSyllable.values) {
      values.sort();
    }
    _loaded = true;
  }

  Future<void> _loadWordLines(String assetPath, Set<String> target) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      for (final line in content.split(RegExp(r'\r?\n'))) {
        final word = normalize(line);
        if (isAcceptable(word)) target.add(word);
      }
    } catch (_) {
      // Cho phép chạy với các asset cũ trong lúc người dùng đang cập nhật.
    }
  }

  String normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  bool isAcceptable(String word) {
    if (word.isEmpty || word.length > 60) return false;
    if (word.length == 1 && word != 'a') return false;
    if (word.contains(RegExp(r'[0-9_.,;:!?()\[\]{}+*=<>/@#%$|]'))) {
      return false;
    }
    final syllables = word.split(' ');
    if (syllables.length > 5) return false;
    return syllables.every(
      (syllable) => RegExp(r'^[a-zà-ỹđ]+(?:-[a-zà-ỹđ]+)?$').hasMatch(syllable),
    );
  }

  bool isModernAliasAcceptable(String word) {
    if (!isAcceptable(word)) return false;
    if (word.length < 2) return false;
    if (word.contains(' ')) return true;
    return !word.startsWith('x') || word.length > 2;
  }

  /// f, j, w, z không thuộc bảng chữ cái tiếng Việt chuẩn (chỉ xuất hiện
  /// trong từ vay mượn/viết tắt), và tiếng Việt không lặp phụ âm liên tiếp
  /// trong một âm tiết. Lưu ý: KHÔNG chặn nguyên âm đôi (oo, uô, ươ…) vì đó
  /// là chính tả hợp lệ (vd. “xoong nồi”, “boong tàu”). Hai kiểm tra này chỉ
  /// giúp loại bớt từ ngoại lai còn lẫn trong bộ dữ liệu nguồn (vd.
  /// "abscess", "amygdala") trước khi cho vào chuỗi nối từ.
  static final RegExp _nonVietnameseLetters = RegExp(r'[fjwz]');
  static final RegExp _doubledConsonant = RegExp(r'([bcdđghklmnpqrstvx])\1');

  bool _looksVietnameseSyllable(String syllable) {
    return !syllable.contains(_nonVietnameseLetters) &&
        !syllable.contains(_doubledConsonant);
  }

  bool contains(String value) => _words.contains(normalize(value));

  /// Trả về các dạng chuẩn nếu người chơi nhập biến thể hiện đại.
  List<String> normalizedForms(String value) {
    final word = normalize(value);
    return _modernAliases[word] ?? <String>[word];
  }

  /// Tìm dạng chuẩn có thể đưa vào chuỗi nối.
  ///
  /// Việc kiểm tra âm tiết đầu được thực hiện sau khi chuẩn hóa alias. Vì vậy
  /// các dạng như “ko” chỉ được nhận nếu có dạng chuẩn hợp lệ bắt đầu đúng
  /// âm tiết bắt buộc; không thể dùng alias để lách luật nối từ.
  String? resolveForChain(
    String value,
    String requiredSyllable,
    Set<String> used,
  ) {
    final required = normalize(requiredSyllable);
    for (final form in normalizedForms(value)) {
      final candidate = normalize(form);
      if (!contains(candidate) ||
          !isPlayableChainWord(candidate) ||
          used.contains(candidate)) continue;
      if (candidate.split(' ').first == required) return candidate;
    }
    return null;
  }

  String lastSyllable(String value) {
    final normalized = normalize(value);
    final parts = normalized.split(' ');
    return parts.isEmpty ? normalized : parts.last;
  }

  /// Luật của trò là Nối từ 2 chữ: mỗi lượt phải có ĐÚNG hai âm tiết,
  /// không hơn không kém. Vì vậy các mục đơn như “vồng” không được dùng làm
  /// một nước riêng, và các cụm 3-4-5 âm tiết lẫn trong bộ dữ liệu nguồn
  /// (vd. “ai khảo mà xưng”, “a di đà phật”) cũng bị loại khỏi trò chơi.
  bool isPlayableChainWord(String value) {
    final word = normalize(value);
    if (!isAcceptable(word)) return false;
    final syllables = word.split(' ');
    if (syllables.length != 2) return false;
    return syllables.every(_looksVietnameseSyllable);
  }

  List<String> candidatesFor(String syllable, Set<String> used) {
    final key = normalize(syllable).split(' ').last;
    return (_byFirstSyllable[key] ?? const <String>[])
        .where((word) => isPlayableChainWord(word) && !used.contains(word))
        .toList();
  }

  bool hasUnusedContinuation(String word, Set<String> used) {
    final nextUsed = <String>{...used, normalize(word)};
    return candidatesFor(lastSyllable(word), nextUsed).isNotEmpty;
  }

  String? randomContinuation(String syllable, Set<String> used, Random random) {
    final candidates = candidatesFor(syllable, used);
    if (candidates.isEmpty) return null;

    // Ưu tiên một từ/cụm từ mà sau đó vẫn còn ít nhất một nước nối. Nhờ vậy
    // máy không tự kết thúc ván quá sớm chỉ vì chọn ngẫu nhiên một ngõ cụt.
    final viable = candidates.where((candidate) {
      final nextUsed = <String>{...used, candidate};
      return candidatesFor(lastSyllable(candidate), nextUsed).isNotEmpty;
    }).toList();
    // Nếu không còn ứng viên có đường đi tiếp, kết thúc ván thay vì đưa ra
    // một từ cụt khiến người chơi phải nối vào âm tiết không tồn tại.
    if (viable.isEmpty) return null;
    return viable[random.nextInt(viable.length)];
  }

  int get wordCount => _words.length;
  int get modernAliasCount => _modernAliases.length;

  static const _fallbackWords = <String>[
    'bình minh',
    'minh bạch',
    'bạch tuộc',
    'tuộc đời',
    'đời sống',
    'sống động',
    'động vật',
    'vật lý',
    'lý tưởng',
    'tưởng tượng',
    'tượng hình',
    'hình học',
    'học tập',
    'tập trung',
    'trung thực',
    'thực vật',
    'vật chất',
    'chất lượng',
    'lượng giác',
    'giác quan',
    'quan tâm',
    'tâm hồn',
    'hồn nhiên',
    'nhiên liệu',
    'liệu pháp',
    'pháp luật',
    'luật lệ',
    'lệ phí',
  ];
}
