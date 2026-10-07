import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../l10n/tr.dart';

/// `Text` của PetMath: y hệt `Text` của Flutter nhưng tự dịch chuỗi tiếng Việt
/// sang tiếng Anh khi app đang ở English (xem [Tr]). Các file chỉ cần
/// `import 'package:flutter/material.dart' hide Text;` + import file này là mọi
/// `Text(...)` sẵn có tự song ngữ, không phải sửa từng chỗ.
class Text extends StatelessWidget {
  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  static InlineSpan _translateSpan(InlineSpan span, String lang) {
    if (span is TextSpan) {
      return TextSpan(
        text: span.text == null ? null : Tr.t(span.text!, lang),
        children: span.children?.map((c) => _translateSpan(c, lang)).toList(),
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }
    return span;
  }

  @override
  Widget build(BuildContext context) {
    // Phụ thuộc vào Localizations → tự dựng lại khi người dùng đổi ngôn ngữ.
    final lang = Localizations.maybeLocaleOf(context)?.languageCode ?? Tr.lang;
    if (textSpan != null) {
      return m.Text.rich(
        lang == 'en' ? _translateSpan(textSpan!, lang) : textSpan!,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return m.Text(
      Tr.t(data!, lang),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null ? null : Tr.t(semanticsLabel!, lang),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
