import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  const MathText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final segments = MathTextParser.parse(text);
    if (segments.length == 1 && !segments.first.isMath) {
      return Text(
        text,
        style: effectiveStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(
        style: effectiveStyle,
        children: [
          for (final segment in segments)
            if (segment.isMath)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Math.tex(
                  segment.value,
                  mathStyle: MathStyle.text,
                  textStyle: effectiveStyle,
                ),
              )
            else
              TextSpan(text: segment.value),
        ],
      ),
    );
  }
}

class MathTextSegment {
  final String value;
  final bool isMath;

  const MathTextSegment(this.value, this.isMath);
}

class MathTextParser {
  static final _explicitPattern = RegExp(r'(\$[^$]+\$|\\\([^)]*\\\))');
  static final _mathWordPattern = RegExp(
    r'(pi|sqrt|alpha|beta|gamma|delta|theta|lambda|mu|sigma|omega|infinity|approx|leq|geq|ne|pm)',
    caseSensitive: false,
  );

  static List<MathTextSegment> parse(String input) {
    if (input.trim().isEmpty) return [const MathTextSegment('', false)];
    final result = <MathTextSegment>[];
    var cursor = 0;
    for (final match in _explicitPattern.allMatches(input)) {
      _appendPlain(result, input.substring(cursor, match.start));
      var value = match.group(0)!;
      if (value.startsWith(r'\(')) {
        value = value.substring(2, value.length - 2);
      } else {
        value = value.substring(1, value.length - 1);
      }
      result.add(MathTextSegment(_toTex(value), true));
      cursor = match.end;
    }
    _appendPlain(result, input.substring(cursor));
    return result.isEmpty ? [MathTextSegment(input, false)] : result;
  }

  static void _appendPlain(List<MathTextSegment> result, String plain) {
    if (plain.isEmpty) return;
    final tokens = RegExp(r'\s+|[^\s]+').allMatches(plain);
    for (final match in tokens) {
      final token = match.group(0)!;
      if (token.trim().isEmpty) {
        result.add(MathTextSegment(token, false));
      } else if (_looksMath(token)) {
        result.add(MathTextSegment(_toTex(token), true));
      } else {
        result.add(MathTextSegment(token, false));
      }
    }
  }

  static bool _looksMath(String token) {
    if (token.contains('/')) return true;
    if (token.contains('^') || token.contains('_')) return true;
    if (_mathWordPattern.hasMatch(token)) return true;
    if (RegExp(r'[=+×·≤≥<>√*]').hasMatch(token) &&
        RegExp(r'[A-Za-zÀ-ỹ0-9]').hasMatch(token)) {
      return true;
    }
    return RegExp(r'[A-Za-z0-9À-ỹ]\.[A-Za-z0-9À-ỹ]').hasMatch(token);
  }

  static String _toTex(String raw) {
    var tex = raw.trim();
    tex = tex.replaceAll('√', r'\sqrt');
    tex = tex.replaceAll('≤', r'\le');
    tex = tex.replaceAll('≥', r'\ge');
    tex = tex.replaceAll('≠', r'\ne');
    tex = tex.replaceAll('≈', r'\approx');
    tex = tex.replaceAll('×', r'\times');
    tex = tex.replaceAll('·', r'\cdot');
    tex = tex.replaceAll('∞', r'\infty');
    tex = tex.replaceAll('->', r'\to');
    tex = tex.replaceAll('+-', r'\pm');
    tex = tex.replaceAllMapped(
      RegExp(r'\bsqrt\(([^()]+)\)', caseSensitive: false),
      (match) => r'\sqrt{' + match.group(1)! + '}',
    );
    tex = tex.replaceAllMapped(
      RegExp(
          r'\b(pi|alpha|beta|gamma|delta|theta|lambda|mu|sigma|omega|infinity)\b',
          caseSensitive: false),
      (match) => '\\${match.group(1)!.toLowerCase()}',
    );
    tex = _addVietnameseSubscripts(tex);
    tex = tex.replaceAll('*', r'\cdot');
    if (tex.contains('/') && !tex.contains(r'\frac')) {
      final slash = tex.indexOf('/');
      if (slash > 0 &&
          slash < tex.length - 1 &&
          !tex.substring(slash + 1).contains('/')) {
        final numerator = tex.substring(0, slash).trim();
        final denominator = tex.substring(slash + 1).trim();
        return r'\frac{' + numerator + '}{' + denominator + '}';
      }
    }
    if (RegExp(r'[A-Za-z0-9À-ỹ]\.[A-Za-z0-9À-ỹ]').hasMatch(tex)) {
      tex = tex.replaceAll('.', r'\cdot ');
    }
    return tex;
  }

  static String _addVietnameseSubscripts(String value) {
    var result = value;
    const suffixes = [
      'đáy',
      'day',
      'cao',
      'bên',
      'ben',
      'trong',
      'ngoài',
      'ngoai',
      'min',
      'max',
    ];
    for (final suffix in suffixes) {
      result = result.replaceAllMapped(
        RegExp('([A-Za-z])$suffix', caseSensitive: false),
        (match) => '${match.group(1)}_{\\text{$suffix}}',
      );
    }
    return result;
  }
}
