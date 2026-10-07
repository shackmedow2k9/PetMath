import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Hiển thị nội dung trả lời của Gia sư AI (Groq) một cách dễ đọc.
///
/// Groq trả lời theo định dạng Markdown + LaTeX trộn lẫn (in đậm bằng
/// `**...**`, tiêu đề bằng `### `, gạch ngang `---`, công thức trong dòng
/// `\(...\)` và công thức khối nhiều dòng `\[...\]`) — nếu hiển thị bằng
/// [Text] thuần thì người dùng sẽ thấy nguyên các ký hiệu này, rất rối
/// mắt. Widget này không phụ thuộc gói markdown ngoài, chỉ dùng
/// flutter_math_fork (đã có sẵn trong project) + parser tự viết, đủ cho
/// đúng những gì Groq thường trả về.
class AiAnswerView extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const AiAnswerView(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final baseStyle = (style ?? DefaultTextStyle.of(context).style)
        .copyWith(height: 1.5);
    final blocks = _splitBlockMath(text);
    final children = <Widget>[];
    for (final block in blocks) {
      if (block.isMath) {
        children.add(_buildMathBlock(block.value, baseStyle));
      } else {
        children.addAll(_buildTextLines(block.value, baseStyle));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildMathBlock(String tex, TextStyle baseStyle) {
    if (tex.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          tex,
          mathStyle: MathStyle.display,
          textStyle: baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 15) + 1),
          onErrorFallback: (err) => Text(tex, style: baseStyle),
        ),
      ),
    );
  }

  List<Widget> _buildTextLines(String text, TextStyle baseStyle) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line == '---' || line == '***') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1),
        ));
        continue;
      }
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final headerMatch = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      if (headerMatch != null) {
        final content = headerMatch.group(2)!;
        final level = headerMatch.group(1)!.length;
        final fontSize = (baseStyle.fontSize ?? 15) + (5 - level).clamp(0, 4);
        final headerStyle = baseStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        );
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: RichText(text: _buildInlineSpan(content, headerStyle)),
        ));
        continue;
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RichText(text: _buildInlineSpan(line, baseStyle)),
      ));
    }
    return widgets;
  }

  /// Xử lý **đậm** và \(công thức trong dòng\) trên cùng 1 dòng văn bản.
  InlineSpan _buildInlineSpan(String line, TextStyle baseStyle) {
    final pattern = RegExp(r'\*\*(.+?)\*\*|\\\((.+?)\\\)');
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in pattern.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: line.substring(cursor, match.start),
          style: baseStyle,
        ));
      }
      final bold = match.group(1);
      final inlineMath = match.group(2);
      if (bold != null) {
        spans.add(TextSpan(
          text: bold,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (inlineMath != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            inlineMath,
            mathStyle: MathStyle.text,
            textStyle: baseStyle,
            onErrorFallback: (err) => Text(inlineMath, style: baseStyle),
          ),
        ));
      }
      cursor = match.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor), style: baseStyle));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: line, style: baseStyle));
    }
    return TextSpan(children: spans);
  }

  /// Tách văn bản thành các đoạn "chữ thường" và "công thức khối"
  /// \[...\] (có thể nhiều dòng) để công thức khối được canh giữa, cỡ
  /// chữ lớn hơn (MathStyle.display) thay vì lẫn vào giữa dòng chữ.
  List<_TextOrMathBlock> _splitBlockMath(String input) {
    final pattern = RegExp(r'\\\[([\s\S]*?)\\\]');
    final result = <_TextOrMathBlock>[];
    var cursor = 0;
    for (final match in pattern.allMatches(input)) {
      if (match.start > cursor) {
        result.add(_TextOrMathBlock(input.substring(cursor, match.start), false));
      }
      result.add(_TextOrMathBlock(match.group(1)!.trim(), true));
      cursor = match.end;
    }
    if (cursor < input.length) {
      result.add(_TextOrMathBlock(input.substring(cursor), false));
    }
    if (result.isEmpty) {
      result.add(_TextOrMathBlock(input, false));
    }
    return result;
  }
}

class _TextOrMathBlock {
  final String value;
  final bool isMath;
  _TextOrMathBlock(this.value, this.isMath);
}