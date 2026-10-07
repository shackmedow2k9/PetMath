import 'tr_en.dart';
import 'tr_en_extra.dart';

/// Dịch các chuỗi tiếng Việt viết thẳng trong code sang tiếng Anh lúc chạy.
///
/// Khoá = chính câu tiếng Việt gốc; chuỗi có biến (`$name`) được ghi với chỗ
/// trống `{0}`, `{1}`... trong [kTrEn] (file sinh tự động từ tool, xem
/// tr_en.dart). Không có bản dịch → trả lại nguyên văn tiếng Việt (không bao
/// giờ crash, không mất chữ).
class Tr {
  Tr._();

  /// Ngôn ngữ hiện tại — LocaleProvider cập nhật mỗi khi đổi/tải ngôn ngữ.
  static String lang = 'vi';

  static bool get isEn => lang == 'en';

  static final Map<String, String> _exact = {};
  static final List<_Pattern> _patterns = [];
  static final Map<String, String> _cache = {};
  static bool _ready = false;

  static void _init() {
    if (_ready) return;
    _ready = true;
    final merged = <String, String>{...kTrEn, ...kTrEnExtra};
    merged.forEach((vi, en) {
      if (vi.contains('{0}')) {
        _patterns.add(_Pattern(vi, en));
      } else {
        _exact[vi] = en;
      }
    });
    // Mẫu có nhiều chữ cố định (cụ thể hơn) được thử trước.
    _patterns.sort((a, b) => b.literalLength.compareTo(a.literalLength));
  }

  /// Dịch [vi] theo ngôn ngữ [language] (mặc định: ngôn ngữ hiện tại).
  static String t(String vi, [String? language]) {
    if ((language ?? lang) != 'en' || vi.isEmpty) return vi;
    _init();
    final cached = _cache[vi];
    if (cached != null) return cached;
    final out = _translate(vi);
    if (_cache.length < 4000) _cache[vi] = out;
    return out;
  }

  static String _translate(String vi) {
    final exact = _exact[vi];
    if (exact != null) return exact;
    final matched = _matchPattern(vi);
    if (matched != null) return matched;
    // "Exception: ..." (lỗi ném từ service) → bỏ tiền tố rồi dịch phần còn lại.
    if (vi.startsWith('Exception: ')) {
      return _translate(vi.substring('Exception: '.length));
    }
    // Chuỗi nhiều dòng → dịch từng dòng.
    if (vi.contains('\n')) {
      return vi.split('\n').map((l) => l.isEmpty ? l : _translate(l)).join('\n');
    }
    return vi;
  }

  static String? _matchPattern(String vi) {
    for (final p in _patterns) {
      final m = p.regex.firstMatch(vi);
      if (m != null) {
        var out = p.en;
        for (var i = 1; i <= m.groupCount; i++) {
          final captured = m.group(i) ?? '';
          // Biến bên trong cũng có thể là tiếng Việt (vd tên môn) → dịch luôn.
          out = out.replaceAll('{${i - 1}}', _exact[captured] ?? captured);
        }
        return out;
      }
    }
    return null;
  }
}

class _Pattern {
  final String en;
  late final RegExp regex;
  late final int literalLength;

  _Pattern(String vi, this.en) {
    final parts = vi.split(RegExp(r'\{\d+\}'));
    literalLength = parts.fold<int>(0, (a, p) => a + p.length);
    final buf = StringBuffer('^');
    for (var i = 0; i < parts.length; i++) {
      buf.write(RegExp.escape(parts[i]));
      if (i < parts.length - 1) buf.write('(.+?)');
    }
    buf.write(r'$');
    regex = RegExp(buf.toString(), dotAll: true);
  }
}

/// Viết tắt cho code không có BuildContext (hint, label, tooltip...).
String tr(String vi) => Tr.t(vi);
