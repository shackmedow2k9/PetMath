import 'dart:convert';
import 'dart:math';

/// 4 mức độ khó cho Giải mật mã — độ khó càng cao thì khóa/tham số của
/// mật mã càng phức tạp hơn (VD: bỏ khoảng trắng, dịch chuyển lớn hơn,
/// từ khóa dài hơn, thuật toán khó nhận diện hơn...).
enum CipherDifficulty { easy, medium, hard, superHard }

extension CipherDifficultyX on CipherDifficulty {
  String get label {
    switch (this) {
      case CipherDifficulty.easy:
        return 'Dễ';
      case CipherDifficulty.medium:
        return 'Trung bình';
      case CipherDifficulty.hard:
        return 'Khó';
      case CipherDifficulty.superHard:
        return 'Siêu khó';
    }
  }

  /// 1 (Dễ) .. 4 (Siêu khó) — dùng để lọc mật mã phù hợp.
  int get tier {
    switch (this) {
      case CipherDifficulty.easy:
        return 1;
      case CipherDifficulty.medium:
        return 2;
      case CipherDifficulty.hard:
        return 3;
      case CipherDifficulty.superHard:
        return 4;
    }
  }
}

/// Một họ mật mã (thuật toán mã hóa) — [hint] hiển thị dạng nhãn khóa RẤT
/// NGẮN GỌN kiểu "key:SECRETKEY" hoặc "key:NONE" (không giải thích dài dòng,
/// không tiết lộ khóa cụ thể — khóa thật được sinh ngẫu nhiên mỗi lần
/// trong hàm [encode]).
class CipherFamily {
  final String id;
  final String name;
  final String hint;
  final int minTier;
  final int maxTier;
  final String Function(
      String plain, CipherDifficulty difficulty, Random random) encode;

  const CipherFamily({
    required this.id,
    required this.name,
    required this.hint,
    required this.encode,
    this.minTier = 1,
    this.maxTier = 4,
  });
}

const String _az = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

String _stripSpacesIfHard(String text, CipherDifficulty diff) {
  return diff.tier <= 2 ? text : text.replaceAll(' ', '');
}

// ---------- 1. Caesar ----------
String _caesarEncode(String plain, CipherDifficulty diff, Random random) {
  final shift = 1 + random.nextInt(25);
  final text = _stripSpacesIfHard(plain, diff);
  final buffer = StringBuffer();
  for (final code in text.codeUnits) {
    if (code >= 65 && code <= 90) {
      buffer.writeCharCode(((code - 65 + shift) % 26) + 65);
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

// ---------- 2. ROT13 ----------
String _rot13Encode(String plain, CipherDifficulty diff, Random random) {
  const shift = 13;
  final text = _stripSpacesIfHard(plain, diff);
  final buffer = StringBuffer();
  for (final code in text.codeUnits) {
    if (code >= 65 && code <= 90) {
      buffer.writeCharCode(((code - 65 + shift) % 26) + 65);
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

// ---------- 3. Atbash ----------
String _atbashEncode(String plain, CipherDifficulty diff, Random random) {
  final text = _stripSpacesIfHard(plain, diff);
  final buffer = StringBuffer();
  for (final code in text.codeUnits) {
    if (code >= 65 && code <= 90) {
      buffer.writeCharCode(90 - (code - 65));
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

// ---------- 4. Vigenère ----------
const _vigenereKeywords = [
  'KEY',
  'LOCK',
  'STAR',
  'MOON',
  'GOLD',
  'TIGER',
  'EAGLE',
  'PLANET',
  'FLOWER',
  'DRAGON'
];
String _vigenereEncode(String plain, CipherDifficulty diff, Random random) {
  final pool = _vigenereKeywords.where((k) {
    if (diff.tier <= 2) return k.length <= 5;
    if (diff.tier == 3) return k.length >= 4 && k.length <= 6;
    return k.length >= 6;
  }).toList();
  final source = pool.isNotEmpty ? pool : _vigenereKeywords;
  final keyword = source[random.nextInt(source.length)];
  final text = _stripSpacesIfHard(plain, diff);
  final buffer = StringBuffer();
  int keyIndex = 0;
  for (final code in text.codeUnits) {
    if (code >= 65 && code <= 90) {
      final shift = keyword.codeUnitAt(keyIndex % keyword.length) - 65;
      buffer.writeCharCode(((code - 65 + shift) % 26) + 65);
      keyIndex++;
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

// ---------- 5. A1Z26 ----------
String _a1z26Encode(String plain, CipherDifficulty diff, Random random) {
  final parts = <String>[];
  for (final code in plain.codeUnits) {
    if (code == 32) {
      parts.add('/');
    } else if (code >= 65 && code <= 90) {
      parts.add((code - 65 + 1).toString());
    }
  }
  return parts.join('-');
}

// ---------- 6. Morse ----------
const _morseMap = {
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',
};
String _morseEncode(String plain, CipherDifficulty diff, Random random) {
  final words = plain.split(' ');
  final encodedWords = words.map(
    (w) => w.split('').map((c) => _morseMap[c] ?? '').join(' '),
  );
  return encodedWords.join(' / ');
}

// ---------- 7. Nhị phân ASCII ----------
String _binaryEncode(String plain, CipherDifficulty diff, Random random) {
  final text = _stripSpacesIfHard(plain, diff);
  final groups = <String>[];
  for (final code in text.codeUnits) {
    groups.add(code.toRadixString(2).padLeft(8, '0'));
  }
  return groups.join(' ');
}

// ---------- 8. Mật mã bàn phím QWERTY ----------
const _qwertyOrder = 'QWERTYUIOPASDFGHJKLZXCVBNM';
String _keyboardShiftEncode(
    String plain, CipherDifficulty diff, Random random) {
  final shift = 1 + random.nextInt(25);
  final text = _stripSpacesIfHard(plain, diff);
  final buffer = StringBuffer();
  for (final ch in text.split('')) {
    final idx = _qwertyOrder.indexOf(ch);
    if (idx == -1) {
      buffer.write(ch);
    } else {
      buffer.write(_qwertyOrder[(idx + shift) % 26]);
    }
  }
  return buffer.toString();
}

// ---------- 9. Ô vuông Polybius ----------
const _polybiusAlphabet = 'ABCDEFGHIKLMNOPQRSTUVWXYZ'; // 25 chữ, J gộp vào I
String _polybiusEncode(String plain, CipherDifficulty diff, Random random) {
  final parts = <String>[];
  for (final ch in plain.split('')) {
    if (ch == ' ') {
      parts.add('/');
      continue;
    }
    final letter = ch == 'J' ? 'I' : ch;
    final idx = _polybiusAlphabet.indexOf(letter);
    if (idx == -1) continue;
    final row = idx ~/ 5 + 1;
    final col = idx % 5 + 1;
    parts.add('$row$col');
  }
  return parts.join(' ');
}

// ---------- 10. Affine ----------
const _affineValidA = [1, 3, 5, 7, 9, 11, 15, 17, 19, 21, 23, 25];
String _affineEncode(String plain, CipherDifficulty diff, Random random) {
  final a = _affineValidA[random.nextInt(_affineValidA.length)];
  final b = random.nextInt(26);
  final text = _stripSpacesIfHard(plain, diff);
  final buffer = StringBuffer();
  for (final code in text.codeUnits) {
    if (code >= 65 && code <= 90) {
      final x = code - 65;
      final y = (a * x + b) % 26;
      buffer.writeCharCode(y + 65);
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

// ---------- 11. Rail Fence (hàng rào kẽm gai) ----------
String _railFenceEncode(String plain, CipherDifficulty diff, Random random) {
  final text = plain.replaceAll(' ', '');
  final railCount = diff.tier + 1; // 2..5 đường ray
  if (railCount <= 1 || text.isEmpty) return text;

  final fence = List.generate(railCount, (_) => StringBuffer());
  int rail = 0;
  int dir = 1;
  for (final ch in text.split('')) {
    fence[rail].write(ch);
    if (rail == 0) {
      dir = 1;
    } else if (rail == railCount - 1) {
      dir = -1;
    }
    rail += dir;
  }
  return fence.map((b) => b.toString()).join();
}

// ---------- 12. Thay thế đơn bảng (Substitution) ----------
String _substitutionEncode(String plain, CipherDifficulty diff, Random random) {
  final shuffled = _az.split('')..shuffle(random);
  final mapping = <String, String>{};
  for (int i = 0; i < 26; i++) {
    mapping[_az[i]] = shuffled[i];
  }
  final text = _stripSpacesIfHard(plain, diff);
  final buffer = StringBuffer();
  for (final ch in text.split('')) {
    buffer.write(mapping[ch] ?? ch);
  }
  return buffer.toString();
}

// ---------- 13. Đảo ngược ----------
String _reverseEncode(String plain, CipherDifficulty diff, Random random) {
  return plain.split('').reversed.join();
}

// ---------- 14. Baconian ----------
String _baconianEncode(String plain, CipherDifficulty diff, Random random) {
  final groups = <String>[];
  for (final code in plain.codeUnits) {
    if (code == 32) {
      groups.add('/');
      continue;
    }
    if (code < 65 || code > 90) continue;
    final idx = code - 65;
    final bin = idx.toRadixString(2).padLeft(5, '0');
    groups.add(bin.split('').map((b) => b == '0' ? 'A' : 'B').join());
  }
  return groups.join(' ');
}

// ---------- 15. Base64 ----------
String _base64CipherEncode(String plain, CipherDifficulty diff, Random random) {
  return base64Encode(utf8.encode(plain));
}

final List<CipherFamily> kCipherFamilies = [
  CipherFamily(
    id: 'caesar',
    name: 'Mật mã Caesar',
    hint: 'key:SHIFT_NUMBER',
    encode: _caesarEncode,
    minTier: 1,
    maxTier: 3,
  ),
  CipherFamily(
    id: 'rot13',
    name: 'ROT13',
    hint: 'key:NONE',
    encode: _rot13Encode,
    minTier: 1,
    maxTier: 2,
  ),
  CipherFamily(
    id: 'atbash',
    name: 'Mật mã Atbash',
    hint: 'key:NONE',
    encode: _atbashEncode,
    minTier: 1,
    maxTier: 2,
  ),
  CipherFamily(
    id: 'vigenere',
    name: 'Mật mã Vigenère',
    hint: 'key:SECRETKEY',
    encode: _vigenereEncode,
    minTier: 3,
    maxTier: 4,
  ),
  CipherFamily(
    id: 'a1z26',
    name: 'Mật mã A1Z26',
    hint: 'key:NONE',
    encode: _a1z26Encode,
    minTier: 1,
    maxTier: 3,
  ),
  CipherFamily(
    id: 'morse',
    name: 'Mã Morse',
    hint: 'key:NONE',
    encode: _morseEncode,
    minTier: 1,
    maxTier: 3,
  ),
  CipherFamily(
    id: 'binary',
    name: 'Mã nhị phân ASCII',
    hint: 'key:NONE',
    encode: _binaryEncode,
    minTier: 2,
    maxTier: 4,
  ),
  CipherFamily(
    id: 'keyboard_shift',
    name: 'Mật mã bàn phím QWERTY',
    hint: 'key:SHIFT_NUMBER',
    encode: _keyboardShiftEncode,
    minTier: 2,
    maxTier: 4,
  ),
  CipherFamily(
    id: 'polybius',
    name: 'Ô vuông Polybius',
    hint: 'key:NONE',
    encode: _polybiusEncode,
    minTier: 2,
    maxTier: 4,
  ),
  CipherFamily(
    id: 'affine',
    name: 'Mật mã Affine',
    hint: 'key:A,B',
    encode: _affineEncode,
    minTier: 3,
    maxTier: 4,
  ),
  CipherFamily(
    id: 'rail_fence',
    name: 'Mật mã hàng rào (Rail Fence)',
    hint: 'key:RAIL_COUNT',
    encode: _railFenceEncode,
    minTier: 2,
    maxTier: 4,
  ),
  CipherFamily(
    id: 'substitution',
    name: 'Mật mã thay thế đơn bảng',
    hint: 'key:26_LETTER_MAP',
    encode: _substitutionEncode,
    minTier: 3,
    maxTier: 4,
  ),
  CipherFamily(
    id: 'reverse',
    name: 'Mật mã đảo ngược',
    hint: 'key:NONE',
    encode: _reverseEncode,
    minTier: 1,
    maxTier: 2,
  ),
  CipherFamily(
    id: 'baconian',
    name: 'Mật mã Baconian',
    hint: 'key:NONE',
    encode: _baconianEncode,
    minTier: 3,
    maxTier: 4,
  ),
  CipherFamily(
    id: 'base64',
    name: 'Base64',
    hint: 'key:NONE',
    encode: _base64CipherEncode,
    minTier: 4,
    maxTier: 4,
  ),
];

List<CipherFamily> familiesForTier(int tier) {
  return kCipherFamilies
      .where((f) => tier >= f.minTier && tier <= f.maxTier)
      .toList();
}
