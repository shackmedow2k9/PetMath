import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';

import '../theme/app_theme.dart';
import 'true_3d_viewport.dart';

enum Parametric3DShape {
  cube,
  cuboid,
  pyramid,
  frustum,
  tetrahedron,
  prism,
  cylinder,
  cone,
  sphere,
  plane,
}

/// How the base of a pyramid/tetrahedron should be built, decided ONCE from
/// the prompt text and then reused everywhere (viewport geometry, vertex
/// labels, purple distance lines, volume estimate). Having a single source
/// of truth here avoids the class of bug where two independent regex
/// classifiers (one per file) can disagree about the same shape.
enum PyramidBaseKind {
  /// Not a pyramid/tetrahedron.
  none,

  /// "S.ABC ... SA vuông góc ..." — right angle at B, apex above A.
  triangleRightAngle,

  /// "S.ABCD ... hình chữ nhật/hình vuông ... SA vuông góc ..." — apex
  /// above A.
  rectangle,

  /// "S.ABCD ... đáy ABCD là hình thang vuông tại A và D ... SA vuông
  /// góc ..." — AB ∥ DC, right angles at A and D, apex above A. Uses
  /// [Math3DConfig.topWidth] for the length of DC (the shorter parallel
  /// side), reusing the field the frustum shape already carries.
  rightTrapezoid,

  /// Everything else: a regular n-sided base ("chóp ngũ giác đều", "chóp
  /// thất giác đều", or simply no base shape stated), apex centered above
  /// the base unless the text says "SA vuông góc" (then above vertex A).
  regularPolygon,
}

class Math3DConfig {
  final Parametric3DShape shape;
  final String title;
  final String caption;
  final double width;
  final double height;
  final double depth;
  final double topWidth;
  final double topDepth;
  final int sides;
  final bool inferredFromText;
  final int apexBaseIndex;
  final bool showAxes;
  final String sideLabel;
  final PyramidBaseKind pyramidBaseKind;

  /// True when the prompt gave at least one concrete number (e.g. "AB = 3").
  /// False when every length is only known as a symbolic multiple of "a"
  /// ("AB=a", "AD=2a" ...) or wasn't given at all — in that case distances
  /// and the volume estimate are reported as multiples of "a" instead of a
  /// raw number, since the raw scene units are just an illustrative scale.
  final bool hasNumericMeasurements;

  /// How many scene units equal exactly "1 × a" — only meaningful when
  /// [hasNumericMeasurements] is false. NOT the same as [width]: e.g. for
  /// "AB=2a" width is 2 × this value, since AB's own coefficient (2) isn't
  /// 1. The purple distance line and the volume estimate divide by this to
  /// report a correct multiple of "a", instead of by [width] (which used
  /// to silently assume every base edge's coefficient was exactly 1).
  final double sceneUnitsPerA;

  /// The apex letter for a pyramid/tetrahedron, e.g. "F" for "F.APME" —
  /// defaults to "S", the conventional letter, when the prompt doesn't
  /// name a pyramid explicitly (or names it "S...").
  final String apexLabel;

  /// The base vertex letters for a pyramid/tetrahedron IN ORDER, e.g.
  /// ["A","P","M","E"] for "F.APME" — or, for a prism, the BOTTOM face
  /// letters, e.g. ["N","I","D"] for "NID.OWP". Empty means "not given
  /// explicitly", in which case consumers fall back to the standard
  /// A, B, C, D... . Reading the real letters (instead of always assuming
  /// S.ABCD... or A,B,C.A',B',C'...) is what makes labels correct for
  /// problems named with arbitrary letters.
  final List<String> baseLabels;

  /// For a prism only: the TOP face letters IN ORDER, e.g. ["O","W","P"]
  /// for "NID.OWP" (matched index-for-index with [baseLabels]) — or
  /// ["A'","B'","C'"] when the prompt used the conventional primed
  /// naming. Empty means "not given explicitly" (fall back to
  /// baseLabels[i] + "'").
  final List<String> topLabels;

  /// True when a PRISM's base is a right triangle (unequal legs) rather
  /// than a regular polygon — e.g. "lăng trụ đứng ABC.A'B'C' có đáy ABC là
  /// tam giác vuông tại A, AB=a, AC=2a". [width]/[depth] then hold the two
  /// leg lengths (from the right-angle vertex) instead of a shared "every
  /// edge is the same length" value.
  final bool prismRightTriangleBase;

  /// Index (0/1/2) of the right-angle vertex within [baseLabels], only
  /// meaningful when [prismRightTriangleBase] is true.
  final int prismRightAngleIndex;

  const Math3DConfig({
    required this.shape,
    required this.title,
    required this.caption,
    this.width = 3,
    this.height = 2.5,
    this.depth = 2.4,
    this.topWidth = 1.8,
    this.topDepth = 1.8,
    this.sides = 4,
    this.inferredFromText = false,
    this.apexBaseIndex = -1,
    this.showAxes = false,
    this.sideLabel = 'a',
    this.pyramidBaseKind = PyramidBaseKind.none,
    this.hasNumericMeasurements = false,
    this.sceneUnitsPerA = 3,
    this.apexLabel = 'S',
    this.baseLabels = const <String>[],
    this.topLabels = const <String>[],
    this.prismRightTriangleBase = false,
    this.prismRightAngleIndex = -1,
  });

  /// Parses an explicit pyramid naming like "F.APME" or "S.ABCD" out of the
  /// (already folded) prompt: a single apex letter, a dot, then 3+ base
  /// vertex letters IN THE ORDER GIVEN. Returns null when the prompt never
  /// names the solid this way (e.g. a bare "hình chóp tam giác đều").
  static ({String apex, List<String> base})? _parsePyramidNaming(
      String source) {
    final match =
        RegExp(r'\b([a-z])\s*\.\s*([a-z]{3,24})\b').firstMatch(source);
    if (match == null) return null;
    final apex = match.group(1)!.toUpperCase();
    final base = match.group(2)!.toUpperCase().split('');
    return (apex: apex, base: base);
  }

  /// Parses an explicit prism naming like "NID.OWP" (custom letters, no
  /// primes) or "ABC.A'B'C'" (top = bottom + prime) out of the (already
  /// folded) prompt: a bottom-face letter group, a dot, then a top-face
  /// letter group of the SAME length. Returns null when the prompt never
  /// names the solid this way (e.g. a bare "lăng trụ tam giác đều").
  static ({List<String> bottom, List<String> top})? _parsePrismNaming(
      String source) {
    // A trailing \b doesn't work here: it requires a word/non-word
    // transition, but the group can legitimately END on an apostrophe
    // (non-word) — "abc.a'b'c'" — so \b right after it would force a
    // backtrack that silently drops the very last apostrophe. A negative
    // lookahead for "not a lowercase letter" avoids that.
    final match = RegExp(r"\b([a-z]{3,24})\s*\.\s*((?:[a-z]'?){3,24})(?![a-z])")
        .firstMatch(source);
    if (match == null) return null;
    final bottom = match.group(1)!.toUpperCase().split('');
    final top = _splitPrimedLetters(match.group(2)!);
    if (bottom.length != top.length) return null;
    return (bottom: bottom, top: top);
  }

  /// Splits a run like "a'b'c'" or "owp" into individual (uppercased)
  /// vertex tokens, keeping a trailing apostrophe with its letter.
  static List<String> _splitPrimedLetters(String raw) {
    final tokens = <String>[];
    var i = 0;
    while (i < raw.length) {
      if (!RegExp(r'[a-zA-Z]').hasMatch(raw[i])) {
        i++;
        continue;
      }
      var token = raw[i].toUpperCase();
      i++;
      if (i < raw.length && raw[i] == "'") {
        token += "'";
        i++;
      }
      tokens.add(token);
    }
    return tokens;
  }

  static Math3DConfig fromPrompt(
    String prompt, {
    Parametric3DShape? overrideShape,
  }) {
    final source = foldVietnamese(prompt);
    final shape = overrideShape ?? _detectShape(source);
    final naming =
        shape == Parametric3DShape.pyramid ? _parsePyramidNaming(source) : null;
    final prismNaming =
        shape == Parametric3DShape.prism ? _parsePrismNaming(source) : null;
    // "lăng trụ đứng ABC.A'B'C' có đáy ABC là tam giác vuông tại A" — a
    // very common prism base that is NOT a regular polygon (its two legs
    // from the right-angle vertex can differ, e.g. AB=a, AC=2a). Detected
    // whenever exactly 3 base letters are known (from an explicit naming,
    // or the conventional A,B,C fallback) and "vuông tại <one of them>" is
    // stated.
    final prismBottomLetters = prismNaming?.bottom ??
        (shape == Parametric3DShape.prism ? const ['A', 'B', 'C'] : null);
    int? prismRightAngleIndex;
    if (shape == Parametric3DShape.prism &&
        prismBottomLetters != null &&
        prismBottomLetters.length == 3) {
      for (var i = 0; i < 3; i++) {
        if (source
            .contains('vuong tai ${prismBottomLetters[i].toLowerCase()}')) {
          prismRightAngleIndex = i;
          break;
        }
      }
    }
    final pyramidBaseKind = _classifyPyramidBase(shape, source, naming);
    final values = _inferMeasurements(
        source,
        shape,
        pyramidBaseKind,
        naming,
        prismNaming?.bottom.length,
        prismBottomLetters,
        prismRightAngleIndex,
        prismNaming?.top);
    final inferred = values.containsKey('explicit');
    final label = shapeLabel(shape);
    final showAxes = _needsAxes(source);
    // Only show "a=<number>" when the prompt actually gave a concrete
    // number; symbolic problems ("AB=a", "AD=2a"...) never give a number for
    // "a" itself, so the label should stay the plain variable "a" even
    // though we did infer real proportions from the symbolic coefficients.
    final hasNumericLiteral = values.containsKey('numericExplicit');
    final sideLabel = source.contains('canh bang a')
        ? 'a'
        : hasNumericLiteral && values['width'] != null
            ? 'a=${_formatNumber(values['width']!)}'
            : 'a';
    final title = prompt.trim().isEmpty ? 'Mô hình $label' : prompt.trim();
    final apexLetter = naming?.apex ?? 'S';
    // "<apex><base letter> vuông góc mặt phẳng đáy" — search EVERY base
    // vertex, not just the first one, since the perpendicular edge can
    // connect the apex to any of them (e.g. "EW vuông góc" for E.PDOW,
    // where W is the LAST base letter, not the first). Falls back to the
    // conventional "SA" when the pyramid wasn't named explicitly.
    final perpBaseIndex = shape == Parametric3DShape.pyramid
        ? _findPerpendicularBaseIndex(source, apexLetter, naming?.base)
        : null;
    final perpendicularAtA = perpBaseIndex != null;
    final perpVertexLetter = perpBaseIndex != null
        ? (naming != null && naming.base.length > perpBaseIndex
            ? naming.base[perpBaseIndex]
            : 'A')
        : null;
    final relation = perpendicularAtA
        ? ' Nhận diện $apexLetter$perpVertexLetter vuông góc mặt phẳng đáy, nên $apexLetter được đặt thẳng đứng trên $perpVertexLetter.'
        : '';
    final caption = inferred
        ? 'Đã tự nhận diện $label và các kích thước xuất hiện trong đề.$relation Kéo hình để xoay; dùng Oxyz để định hướng.'
        : 'Đề chưa cho đủ số đo nên hình được dựng theo tỉ lệ minh họa.$relation Kéo hình để xoay; các trục Ox, Oy, Oz dùng chung hệ tọa độ với vật thể.';
    return Math3DConfig(
      shape: shape,
      title: title,
      caption: caption,
      width: values['width'] ?? 3,
      height: values['height'] ?? 2.8,
      depth: values['depth'] ?? 2.4,
      topWidth: values['topWidth'] ?? 1.8,
      topDepth: values['topDepth'] ?? 1.8,
      sides: (values['sides'] ?? _defaultSides(shape))
          .round()
          .clamp(3, 24)
          .toInt(),
      inferredFromText: inferred,
      apexBaseIndex: perpBaseIndex ?? -1,
      showAxes: showAxes,
      sideLabel: sideLabel,
      pyramidBaseKind: pyramidBaseKind,
      hasNumericMeasurements: hasNumericLiteral,
      sceneUnitsPerA: values['sceneUnitsPerA'] ?? values['width'] ?? 3,
      apexLabel: apexLetter,
      baseLabels: naming?.base ?? prismNaming?.bottom ?? const <String>[],
      topLabels: prismNaming?.top ?? const <String>[],
      prismRightTriangleBase: prismRightAngleIndex != null,
      prismRightAngleIndex: prismRightAngleIndex ?? -1,
    );
  }

  /// Finds which base vertex the apex is perpendicular to — i.e. the index
  /// `i` such that "<apex><baseLetters[i]> vuông góc" appears in the
  /// (folded) prompt — searching EVERY base letter, not just the first,
  /// since the stated perpendicular edge can name any of them (e.g. "EW
  /// vuông góc" for E.PDOW, W being the last of 4 base letters). Falls back
  /// to the conventional "SA vuông góc" (index 0) when the pyramid wasn't
  /// named explicitly. Returns null when no perpendicular edge is stated.
  static int? _findPerpendicularBaseIndex(
      String source, String apexLetter, List<String>? baseLetters) {
    final apex = apexLetter.toLowerCase();
    if (baseLetters != null) {
      for (var i = 0; i < baseLetters.length; i++) {
        if (source.contains('$apex${baseLetters[i].toLowerCase()} vuong goc')) {
          return i;
        }
      }
      return null;
    }
    return source.contains('sa vuong goc') ? 0 : null;
  }

  /// Classifies the base of a pyramid/tetrahedron from the (already
  /// ASCII-folded) prompt text. Called once and threaded through to every
  /// consumer — see [PyramidBaseKind]. `naming`, when the prompt used an
  /// explicit "X.YYYY" naming (any letters, not just the conventional
  /// "S.ABCD"), lets this recognise "FA vuông góc" etc. for a pyramid named
  /// with arbitrary letters, not only the classic S/A/B/C/D convention.
  static PyramidBaseKind _classifyPyramidBase(
      Parametric3DShape shape, String source,
      [({String apex, List<String> base})? naming]) {
    if (shape == Parametric3DShape.tetrahedron) {
      return PyramidBaseKind.regularPolygon;
    }
    if (shape != Parametric3DShape.pyramid) return PyramidBaseKind.none;

    final quadBase =
        source.contains('hinh chu nhat') || source.contains('hinh vuong');
    final trapezoidBase = source.contains('hinh thang');
    final quadBaseLetterCount = naming != null && naming.base.length == 4;
    final triBaseLetterCount = naming != null && naming.base.length == 3;

    // Fallback letter checks for when the prompt never used the "X.YYYY"
    // dot naming at all (e.g. "đáy ABCD" written without "S.ABCD").
    final hasAbcd = source.contains('abcd');
    final hasAbcOnly = !hasAbcd &&
        (source.contains('tam giac abc') ||
            RegExp(r's\s*\.?\s*a\s*b\s*c(?!\s*d)').hasMatch(source) ||
            source.contains('(abc)'));

    // Perpendicular edge, checked against EVERY base letter (not just the
    // first) — see _findPerpendicularBaseIndex.
    final perpendicular = _findPerpendicularBaseIndex(
            source, naming?.apex ?? 'S', naming?.base) !=
        null;

    if ((quadBaseLetterCount || hasAbcd) && trapezoidBase && perpendicular) {
      return PyramidBaseKind.rightTrapezoid;
    }
    if ((quadBaseLetterCount || hasAbcd) && quadBase && perpendicular) {
      return PyramidBaseKind.rectangle;
    }
    if ((triBaseLetterCount || hasAbcOnly) && perpendicular) {
      return PyramidBaseKind.triangleRightAngle;
    }
    return PyramidBaseKind.regularPolygon;
  }

  static Math3DConfig? fromQuestionVisual(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final shapeName = foldVietnamese((raw['shape'] ?? 'cuboid').toString());
    final shape = _shapeFromName(shapeName);
    final titleSource =
        foldVietnamese('${raw['title'] ?? ''} ${raw['caption'] ?? ''}'.trim());
    final pyramidBaseKindRaw = raw['pyramidBaseKind']?.toString();
    final pyramidBaseKind = pyramidBaseKindRaw != null
        ? PyramidBaseKind.values.firstWhere(
            (v) => v.name == pyramidBaseKindRaw,
            orElse: () => _classifyPyramidBase(shape, titleSource),
          )
        : _classifyPyramidBase(shape, titleSource);
    double number(String key, double fallback) =>
        (raw[key] as num?)?.toDouble() ?? fallback;
    final sides = (raw['sides'] as num?)?.round() ?? _defaultSides(shape);
    return Math3DConfig(
      shape: shape,
      title: (raw['title'] ?? 'Mô hình hình học theo đề bài').toString(),
      caption:
          (raw['caption'] ?? 'Dựng từ các tham số của câu hỏi.').toString(),
      width: number('width', 3),
      height: number('height', 2.8),
      depth: number('depth', 2.4),
      topWidth: number('topWidth', 1.8),
      topDepth: number('topDepth', 1.8),
      sides: sides.clamp(3, 24).toInt(),
      apexBaseIndex: (raw['apexBaseIndex'] as num?)?.round() ?? -1,
      showAxes: raw['showAxes'] as bool? ?? false,
      sideLabel: (raw['sideLabel'] ?? 'a').toString(),
      pyramidBaseKind: pyramidBaseKind,
      hasNumericMeasurements: raw['hasNumericMeasurements'] as bool? ?? true,
      apexLabel: (raw['apexLabel'] ?? 'S').toString(),
      baseLabels:
          (raw['baseLabels'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[],
    );
  }

  static Math3DConfig? forLesson(String lessonId) {
    switch (lessonId) {
      case 'g11-hinh-hoc-khong-gian':
        return const Math3DConfig(
          shape: Parametric3DShape.pyramid,
          title: 'Mô hình 3D hình chóp và đường cao',
          caption:
              'Kéo ngang hình để xoay; đáy, cạnh bên, đường cao và hệ trục Oxyz được dựng cùng một phép chiếu.',
          width: 2.8,
          height: 3.0,
          depth: 2.4,
          sides: 4,
          showAxes: false,
          pyramidBaseKind: PyramidBaseKind.regularPolygon,
          hasNumericMeasurements: true,
        );
      case 'g12-hinh-hoc-toa-do':
        return const Math3DConfig(
          shape: Parametric3DShape.sphere,
          title: 'Mô hình 3D mặt cầu trong Oxyz',
          caption:
              'Các vòng kinh/vĩ tuyến và ba trục tọa độ giúp quan sát mặt cầu trong không gian.',
          width: 2.6,
          height: 2.6,
          depth: 2.6,
          sides: 16,
          showAxes: true,
          hasNumericMeasurements: true,
        );
      default:
        return null;
    }
  }

  static String shapeLabel(Parametric3DShape shape) {
    return switch (shape) {
      Parametric3DShape.cube => 'hình lập phương',
      Parametric3DShape.cuboid => 'hình hộp chữ nhật',
      Parametric3DShape.pyramid => 'hình chóp',
      Parametric3DShape.frustum => 'hình chóp cụt tứ giác đều',
      Parametric3DShape.tetrahedron => 'hình tứ diện',
      Parametric3DShape.prism => 'hình lăng trụ',
      Parametric3DShape.cylinder => 'hình trụ',
      Parametric3DShape.cone => 'hình nón',
      Parametric3DShape.sphere => 'mặt cầu',
      Parametric3DShape.plane => 'mặt phẳng',
    };
  }

  static Parametric3DShape _detectShape(String source) {
    // "khối" is a very common synonym for "hình" when naming a solid
    // ("khối chóp", "khối lăng trụ", "khối cầu"...). Every check below
    // originally required the literal "hinh X" — so "hình khối chóp
    // S.ABCD" (the word "khối" splitting "hình" from "chóp") matched NONE
    // of them and fell all the way through to the "mặt phẳng" check
    // (since the prompt also mentions "mặt phẳng (ABCD)"), misclassifying
    // an entire pyramid question as a bare plane. Normalizing "khoi " to
    // "hinh " first makes every existing check match either phrasing.
    final normalized = source.replaceAll('khoi ', 'hinh ');
    if (normalized.contains('chop cut')) {
      return Parametric3DShape.frustum;
    }
    // Check "chóp" (pyramid) and "tứ diện" (tetrahedron) before the
    // square/cube keywords: a very common phrasing is "hinh chop S.ABCD co
    // day ABCD la hinh vuong ..." where "hinh vuong" only describes the base
    // of the pyramid, not the solid itself. Matching cube/square first would
    // misclassify every such pyramid question as a hinh lap phuong. "chop"
    // alone (not requiring a "hinh"/"khoi" prefix) also catches phrasings
    // like "cho chóp S.ABC ..." that skip the classifier word entirely.
    if (normalized.contains('tu dien')) return Parametric3DShape.tetrahedron;
    if (normalized.contains('chop')) return Parametric3DShape.pyramid;
    if (normalized.contains('lap phuong') ||
        normalized.contains('hinh vuong')) {
      return Parametric3DShape.cube;
    }
    if (normalized.contains('lang tru')) return Parametric3DShape.prism;
    if (normalized.contains('hinh non')) return Parametric3DShape.cone;
    if (normalized.contains('hinh tru')) return Parametric3DShape.cylinder;
    if (normalized.contains('mat cau') || normalized.contains('hinh cau')) {
      return Parametric3DShape.sphere;
    }
    if (normalized.contains('mat phang') ||
        normalized.contains('mp ') ||
        normalized == 'mp') {
      return Parametric3DShape.plane;
    }
    if (normalized.contains('hinh hop')) return Parametric3DShape.cuboid;
    return Parametric3DShape.cuboid;
  }

  static Parametric3DShape _shapeFromName(String source) {
    if (source.contains('chop cut') || source == 'frustum') {
      return Parametric3DShape.frustum;
    }
    if (source.contains('lap phuong') || source == 'cube') {
      return Parametric3DShape.cube;
    }
    if (source.contains('tu dien') || source == 'tetrahedron') {
      return Parametric3DShape.tetrahedron;
    }
    if (source.contains('chop') || source == 'pyramid') {
      return Parametric3DShape.pyramid;
    }
    if (source.contains('lang tru') || source == 'prism') {
      return Parametric3DShape.prism;
    }
    if (source.contains('non') || source == 'cone')
      return Parametric3DShape.cone;
    if (source.contains('tru') || source == 'cylinder') {
      return Parametric3DShape.cylinder;
    }
    if (source.contains('cau') || source == 'sphere') {
      return Parametric3DShape.sphere;
    }
    if (source.contains('phang') || source == 'plane')
      return Parametric3DShape.plane;
    return Parametric3DShape.cuboid;
  }

  static bool _needsAxes(String source) {
    return source.contains('oxyz') ||
        source.contains('he truc toa do') ||
        source.contains('he toa do') ||
        source.contains('goc toa do') ||
        source.contains('toa do khong gian');
  }

  static String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static int _defaultSides(Parametric3DShape shape) {
    return switch (shape) {
      Parametric3DShape.tetrahedron => 3,
      Parametric3DShape.pyramid || Parametric3DShape.frustum => 4,
      Parametric3DShape.prism => 6,
      Parametric3DShape.cylinder || Parametric3DShape.cone => 20,
      _ => 4,
    };
  }

  static Map<String, double> _inferMeasurements(
    String rawSource,
    Parametric3DShape shape,
    PyramidBaseKind pyramidBaseKind, [
    ({String apex, List<String> base})? naming,
    int? prismSides,
    List<String>? prismBottomLetters,
    int? prismRightAngleIndex,
    List<String>? prismTopLetters,
  ]) {
    // "SA=AB=2a" (a chained equality — very common phrasing) only lets a
    // simple "varname=...a" regex pick up the LAST variable in the chain
    // (AB here), silently dropping SA. Expand every chain into separate
    // "sa=2a ab=2a" clauses first so each variable is extractable on its
    // own regardless of position in the chain.
    final source = _expandChainedEqualities(rawSource);

    double? numberAfter(List<String> labels) {
      // The trailing negative lookahead is what keeps this from misreading
      // a symbolic coefficient: "sa=2a" must NOT be read as "chiều cao =
      // 2" (silently dropping the "×a" and treating it as an absolute
      // number bypasses the unitA-scaled symbolic path entirely, which was
      // throwing off every proportion for a base edge/height whose
      // coefficient wasn't exactly 1). A real literal number is always
      // followed by whitespace, punctuation, or the end of the string —
      // never directly by a letter.
      const number = r'(-?\d+(?:[\.,]\d+)?)(?![a-z])';
      for (final label in labels) {
        final pattern = RegExp(
          r'(?:^|\s)' +
              RegExp.escape(label) +
              r'(?:\s|$|=|:)\s*(?:la|bang|=|:)?\s*' +
              number,
        );
        final match = pattern.firstMatch(source);
        if (match != null) {
          return double.tryParse(match.group(1)!.replaceAll(',', '.'));
        }
      }
      return null;
    }

    // Picks up a symbolic multiple of the reference side "a", e.g. "ab=a",
    // "ad = 2a", "sa=3a", "sb=a/2". Returns the coefficient (1, 2, 0.5, ...)
    // or null if that variable isn't expressed as a multiple of "a" in the
    // prompt. This lets the model reconstruct proportions (AB:AD:SA = 1:2:3,
    // etc.) for problems that never give concrete numbers — which is the
    // normal style of Vietnamese textbook geometry questions.
    double? symbolicCoefficient(String varName) {
      final pattern = RegExp(
        RegExp.escape(varName) +
            r'\s*=\s*(\d+(?:[\.,]\d+)?)?\s*a\s*(?:/\s*(\d+(?:[\.,]\d+)?))?(?![a-z0-9])',
      );
      final match = pattern.firstMatch(source);
      if (match == null) return null;
      final numerator = match.group(1) != null
          ? double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1.0
          : 1.0;
      final denominator = match.group(2) != null
          ? double.tryParse(match.group(2)!.replaceAll(',', '.')) ?? 1.0
          : 1.0;
      if (denominator == 0) return null;
      return numerator / denominator;
    }

    final result = <String, double>{};
    final side = numberAfter(['canh', 'a']);
    final width = numberAfter(['chieu dai', 'dai', 'rong', 'day', 'b']);
    final depth = numberAfter(['chieu rong', 'rong', 'sau', 'c']);
    final height = numberAfter(['chieu cao', 'cao', 'h', 'sa']);
    final radius = numberAfter(['ban kinh', 'bk', 'r']);
    final explicitHeight = height ?? radius;

    final triangularQuestion =
        pyramidBaseKind == PyramidBaseKind.triangleRightAngle;
    final rectangularPyramidQuestion =
        pyramidBaseKind == PyramidBaseKind.rectangle;
    final rightTrapezoidQuestion =
        pyramidBaseKind == PyramidBaseKind.rightTrapezoid;

    // Reference-side ("a") coefficients for the base edges and the vertical
    // edge, when the problem states them symbolically instead of with a
    // concrete number. Try the ACTUAL named edge first (e.g. "ui" for
    // U.UIOP's AB-equivalent edge), falling back to the conventional
    // "ab"/"ad"/"bc"/"cd" — so a pyramid named with arbitrary letters gets
    // its base edges read correctly instead of only ever matching a
    // literal "ab=...".
    double? namedOrFallbackCoef(int i, int j, String fallbackName) {
      if (naming != null && naming.base.length > i && naming.base.length > j) {
        final named = symbolicCoefficient(
            '${naming.base[i].toLowerCase()}${naming.base[j].toLowerCase()}');
        if (named != null) return named;
      }
      return symbolicCoefficient(fallbackName);
    }

    final abCoef = namedOrFallbackCoef(0, 1, 'ab');
    final adCoef = namedOrFallbackCoef(0, 3, 'ad');
    final bcCoef = namedOrFallbackCoef(1, 2, 'bc');
    final cdCoef = namedOrFallbackCoef(2, 3, 'cd');
    // The lateral (apex-to-base) edge coefficient: try the ACTUAL named
    // edge first (e.g. "ew" for E.PDOW with "EW⊥đáy"), falling back to the
    // conventional "sa" — so "EW=2a" is read correctly instead of only
    // ever looking for a literal "SA=...".
    final perpBaseIndex =
        _findPerpendicularBaseIndex(source, naming?.apex ?? 'S', naming?.base);
    final perpVertexLetter = naming != null &&
            perpBaseIndex != null &&
            naming.base.length > perpBaseIndex
        ? naming.base[perpBaseIndex]
        : null;
    final namedLateralCoef = perpVertexLetter != null
        ? symbolicCoefficient(
            '${naming!.apex.toLowerCase()}${perpVertexLetter.toLowerCase()}')
        : null;
    final saCoef = namedLateralCoef ?? symbolicCoefficient('sa');

    // Generic phrasing that isn't tied to a specific named edge — "cạnh
    // bằng a", "cạnh đáy bằng a", "cạnh bên = 2a" — used by cube/cuboid/
    // prism/tetrahedron questions, which don't have an AB/AD/SA to key off
    // of. Longer, more specific phrases are tried first.
    double? phraseCoefficient(List<String> phrases) {
      for (final phrase in phrases) {
        final pattern = RegExp(
          RegExp.escape(phrase) +
              r'\s*(?:bang|=|:)?\s*(\d+(?:[\.,]\d+)?)?\s*a(?:\s*/\s*(\d+(?:[\.,]\d+)?))?\b(?![a-z0-9])',
        );
        final match = pattern.firstMatch(source);
        if (match == null) continue;
        final numerator = match.group(1) != null
            ? double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1.0
            : 1.0;
        final denominator = match.group(2) != null
            ? double.tryParse(match.group(2)!.replaceAll(',', '.')) ?? 1.0
            : 1.0;
        if (denominator == 0) continue;
        return numerator / denominator;
      }
      return null;
    }

    // Scene-unit length of exactly "1 × a" when no concrete number is
    // given in the prompt. Every symbolic edge below is this constant
    // times ITS OWN coefficient — e.g. "AB=2a" -> 2*unitA — instead of
    // sharing one edge's coefficient as an implicit "1a" reference, which
    // previously threw distances/volume off by that edge's own
    // coefficient whenever it wasn't exactly 1, and previously didn't
    // apply at all outside the pyramid case (so "cạnh đáy bằng a" on a
    // prism/cube fell back to an arbitrary illustrative default that had
    // no real relationship to "a").
    const unitA = 2.0;
    double? edgeScene(double? coefficient) =>
        coefficient != null ? coefficient * unitA : null;

    final baseEdgeCoef =
        abCoef ?? phraseCoefficient(['canh day', 'day', 'canh']);
    // "cạnh bên" here is genuinely ambiguous: for a pyramid with a KNOWN
    // perpendicular vertex (saCoef non-null) it IS the height (SA). For a
    // "chóp đều" with a centered apex, "cạnh bên" instead means the SLANT
    // edge (apex to any base vertex) — a different length than the
    // perpendicular height whenever the base isn't a single point, and
    // needs a Pythagorean correction (see slantHeightCorrection below).
    final slantEdgeCoef = phraseCoefficient(['canh ben']);
    final lateralEdgeCoef = saCoef ?? slantEdgeCoef;

    // Regular n-gon with edge length w has circumradius R = w/(2 sin(π/n)).
    // When the apex is centered (no known perpendicular vertex) and the
    // problem gives the SLANT edge (apex-to-base-vertex) instead of the
    // straight-down height, height = √(slant² − R²) by Pythagoras (the
    // right triangle formed by the height, the circumradius, and the
    // slant edge). Returns null when there's nothing to correct (a direct
    // height/SA was already found, or no slant edge was given at all).
    double? slantHeightCorrection(int n, double w) {
      if (saCoef != null || slantEdgeCoef == null) return null;
      final slant = slantEdgeCoef * unitA;
      final r = w / (2 * math.sin(math.pi / n));
      final hSquared = slant * slant - r * r;
      return hSquared > 0 ? math.sqrt(hSquared) : null;
    }

    // When SA (the height) isn't given directly but the apex's distance to
    // a DIFFERENT base vertex is (e.g. "SB=5a" instead of "SA=...") — a
    // very common exam pattern — solve for SA via Pythagoras: since
    // SA⊥đáy, triangle S-A-X has a right angle at A for any base vertex X,
    // so SA = √(SX² − AX²). AX only depends on the base's width/depth
    // (already known at this point), not on the height we're solving for.
    double? heightFromOtherApexEdge(
        PyramidBaseKind kind, int baseSides, double w, double d,
        {double? topWidth}) {
      if (naming == null) return null;
      for (var i = 1; i < naming.base.length && i < baseSides; i++) {
        final coef = symbolicCoefficient(
            '${naming.apex.toLowerCase()}${naming.base[i].toLowerCase()}');
        if (coef == null) continue;
        final sx = coef * unitA;
        final ax = _baseVertexDistance(kind, baseSides, w, d, 0, i,
            topWidth: topWidth);
        final saSquared = sx * sx - ax * ax;
        if (saSquared > 0) return math.sqrt(saSquared);
      }
      return null;
    }

    switch (shape) {
      case Parametric3DShape.cube:
        final edge = side ?? width ?? edgeScene(baseEdgeCoef) ?? 3.0;
        result['width'] = edge;
        result['depth'] = edge;
        result['height'] = edge;
      case Parametric3DShape.cuboid:
        final w = width ?? side ?? edgeScene(baseEdgeCoef) ?? 3.0;
        result['width'] = w;
        result['depth'] = depth ?? edgeScene(adCoef) ?? 2.4;
        result['height'] = height ?? edgeScene(lateralEdgeCoef) ?? 2.8;
      case Parametric3DShape.pyramid:
        if (rectangularPyramidQuestion) {
          // Base is the actual rectangle ABCD: width = AB, depth = AD.
          final w = width ?? side ?? edgeScene(abCoef) ?? 2.0;
          result['width'] = w;
          final d = depth ?? edgeScene(adCoef) ?? w * 2.0;
          result['depth'] = d;
          result['height'] = height ??
              edgeScene(saCoef) ??
              heightFromOtherApexEdge(PyramidBaseKind.rectangle, 4, w, d) ??
              w * 3.0;
        } else if (rightTrapezoidQuestion) {
          // Right angles at A and D: AB ∥ DC, width = AB, depth = AD
          // (the perpendicular leg), topWidth = DC (reusing the frustum's
          // field — a pyramid never otherwise needs it).
          final w = width ?? side ?? edgeScene(abCoef) ?? 2.0;
          result['width'] = w;
          final d = depth ?? edgeScene(adCoef) ?? w * 0.5;
          result['depth'] = d;
          final tw = edgeScene(cdCoef) ?? d;
          result['topWidth'] = tw;
          result['height'] = height ??
              edgeScene(saCoef) ??
              heightFromOtherApexEdge(PyramidBaseKind.rightTrapezoid, 4, w, d,
                  topWidth: tw) ??
              w * 1.5;
        } else if (triangularQuestion) {
          // Right angle at B: width = AB, depth = BC.
          final w = width ?? side ?? edgeScene(abCoef) ?? 3.0;
          result['width'] = w;
          final d = depth ?? edgeScene(bcCoef) ?? w * 0.82;
          result['depth'] = d;
          result['height'] = height ??
              edgeScene(saCoef) ??
              heightFromOtherApexEdge(
                  PyramidBaseKind.triangleRightAngle, 3, w, d) ??
              w;
        } else {
          // Regular n-gon base: every base edge is the same length "a".
          final w = width ?? side ?? edgeScene(baseEdgeCoef) ?? 3.0;
          result['width'] = w;
          final d = depth ?? edgeScene(adCoef) ?? edgeScene(bcCoef) ?? w;
          result['depth'] = d;
          final nSides = naming?.base.length ?? _baseSides(source, fallback: 4);
          result['height'] = height ??
              edgeScene(saCoef) ??
              slantHeightCorrection(nSides, w) ??
              heightFromOtherApexEdge(
                  PyramidBaseKind.regularPolygon, nSides, w, d) ??
              3.2;
        }
        // The explicit "X.YYYY" naming (e.g. "F.APME" -> 4 vertices) is the
        // most authoritative source for the base's side count when
        // present; a polygon name in the prompt ("ngũ giác", "thất
        // giác"...) is the next best signal; a plain quadrilateral is the
        // last-resort default.
        result['sides'] = triangularQuestion
            ? 3
            : (rectangularPyramidQuestion || rightTrapezoidQuestion)
                ? 4
                : (naming?.base.length ?? _baseSides(source, fallback: 4))
                    .toDouble();

      case Parametric3DShape.frustum:
        final measures = RegExp(r'(\d+(?:[\.,]\d+)?)')
            .allMatches(source)
            .map((match) =>
                double.tryParse(match.group(1)!.replaceAll(',', '.')))
            .whereType<double>()
            .toList();
        final double firstBase = measures.isNotEmpty ? measures[0] : 5.0;
        final double secondBase = measures.length > 1 ? measures[1] : 3.0;
        final double bottom = firstBase >= secondBase ? firstBase : secondBase;
        final double top = firstBase >= secondBase ? secondBase : firstBase;
        final double frustumHeight =
            measures.length > 2 ? measures[2] : (height ?? 3.0);
        result['width'] = bottom;
        result['depth'] = bottom;
        result['topWidth'] = top;
        result['topDepth'] = top;
        result['height'] = frustumHeight;
        result['sides'] = 4;
        result['explicit'] = 1;
      case Parametric3DShape.tetrahedron:
        final edge = side ?? width ?? edgeScene(baseEdgeCoef) ?? 3.0;
        result['width'] = edge;
        result['depth'] = edge;
        result['height'] = height ?? edge * 0.82;
        result['sides'] = 3.0;
      case Parametric3DShape.prism:
        if (prismRightAngleIndex != null &&
            prismBottomLetters != null &&
            prismBottomLetters.length == 3) {
          // Right-triangle base (legs can differ) — e.g. "đáy ABC là tam
          // giác vuông tại A, AB=a, AC=2a": width = leg to the SECOND
          // letter, depth = leg to the THIRD letter (in the letters'
          // given order, skipping the right-angle vertex itself).
          final ra = prismRightAngleIndex;
          final others =
              [0, 1, 2].where((i) => i != ra).toList(growable: false);
          final bl = prismBottomLetters;
          double? legCoef(int i) => symbolicCoefficient(
              '${bl[ra].toLowerCase()}${bl[i].toLowerCase()}');
          final leg1 = width ?? edgeScene(legCoef(others[0]) ?? abCoef) ?? 3.0;
          result['width'] = leg1;
          final leg2 =
              depth ?? edgeScene(legCoef(others[1]) ?? bcCoef) ?? leg1 * 0.6;
          result['depth'] = leg2;

          // Height (the lateral edge, e.g. AA'): a direct value/"cạnh
          // bên" wins; otherwise solve it from a face DIAGONAL given
          // instead (e.g. "A'B=3a") via Pythagoras — for a right (đứng)
          // prism, the lateral edge from any bottom vertex i is
          // perpendicular to the whole base, so (top_i - bottom_j)² =
          // height² + dist(bottom_i, bottom_j)² for any other vertex j.
          double? solvedHeight;
          if (prismTopLetters != null && prismTopLetters.length == 3) {
            final coords = {
              bl[ra]: const [0.0, 0.0],
              bl[others[0]]: [leg1, 0.0],
              bl[others[1]]: [0.0, leg2],
            };
            outer:
            for (var i = 0; i < 3 && solvedHeight == null; i++) {
              for (var j = 0; j < 3; j++) {
                if (i == j) continue;
                final coef = symbolicCoefficient(
                    '${prismTopLetters[i].toLowerCase()}${bl[j].toLowerCase()}');
                if (coef == null) continue;
                final diag = coef * unitA;
                final pi = coords[bl[i]]!;
                final pj = coords[bl[j]]!;
                final baseDist = math.sqrt((pi[0] - pj[0]) * (pi[0] - pj[0]) +
                    (pi[1] - pj[1]) * (pi[1] - pj[1]));
                final hSquared = diag * diag - baseDist * baseDist;
                if (hSquared > 0) {
                  solvedHeight = math.sqrt(hSquared);
                  break outer;
                }
              }
            }
          }
          result['height'] =
              height ?? edgeScene(lateralEdgeCoef) ?? solvedHeight ?? leg1;
          result['sides'] = 3.0;
        } else {
          final w = width ?? side ?? edgeScene(baseEdgeCoef) ?? 3.0;
          result['width'] = w;
          result['depth'] = w;
          result['height'] = height ?? edgeScene(lateralEdgeCoef) ?? w;
          // An explicit "BOTTOM.TOP" naming (e.g. "NID.OWP") is the most
          // authoritative source for the base's side count — otherwise
          // fall back to a polygon name ("tam giác đều"...) or a hexagon
          // default.
          result['sides'] =
              (prismSides ?? _baseSides(source, fallback: 6)).toDouble();
        }
      case Parametric3DShape.cylinder:
        final r = radius ?? side ?? 1.6;
        result['width'] = r * 2;
        result['depth'] = r * 2;
        result['height'] = height ?? 3;
        result['sides'] = 20.0;
      case Parametric3DShape.cone:
        final r = radius ?? side ?? 1.8;
        result['width'] = r * 2;
        result['depth'] = r * 2;
        result['height'] = height ?? 3.4;
        result['sides'] = 20.0;
      case Parametric3DShape.sphere:
        final r = radius ?? side ?? 1.8;
        result['width'] = r * 2;
        result['depth'] = r * 2;
        result['height'] = r * 2;
        result['sides'] = 20.0;
      case Parametric3DShape.plane:
        result['width'] = width ?? 4;
        result['depth'] = depth ?? 3;
        result['height'] = explicitHeight ?? 0;
        result['sides'] = 4;
    }
    if (side != null ||
        width != null ||
        depth != null ||
        height != null ||
        radius != null) {
      // A concrete number was actually given (e.g. "AB = 3", "chieu cao 4").
      result['numericExplicit'] = 1;
    }
    if (side != null ||
        width != null ||
        depth != null ||
        height != null ||
        radius != null ||
        abCoef != null ||
        adCoef != null ||
        saCoef != null ||
        baseEdgeCoef != null ||
        lateralEdgeCoef != null) {
      // Either a concrete number, or a symbolic multiple of "a" ("AD=2a",
      // "cạnh đáy bằng a"...) was found — either way we inferred real
      // proportions from the text.
      result['explicit'] = 1;
    }
    // The true scene-unit length of "1 × a", for converting the purple
    // distance line and the volume estimate back into a multiple of "a" —
    // NOT the same as result['width'] whenever the referenced edge's own
    // coefficient isn't 1 (e.g. "AB=2a"). Set for every shape now, not
    // just pyramids, since any of them can be sized via a symbolic "a".
    result['sceneUnitsPerA'] = unitA;
    return result;
  }

  /// Vietnamese polygon-name -> side count, longest phrase first so e.g.
  /// "thập nhất giác" (11) isn't shadowed by the shorter "thập giác" (10).
  static const Map<String, int> _polygonNameSides = {
    'thap nhi giac': 12,
    'thap nhat giac': 11,
    'thap giac': 10,
    'cuu giac': 9,
    'bat giac': 8,
    'that giac': 7,
    'luc giac': 6,
    'ngu giac': 5,
    'tu giac': 4,
    'tam giac': 3,
  };

  /// Expands a chained equality like "sa=ab=2a" into separate clauses
  /// " sa=2a ab=2a" appended to the source, so a variable that isn't the
  /// last one in the chain (SA here) is still found by the simple
  /// "varname=...a" extractors above. Very common phrasing in Vietnamese
  /// textbook geometry ("SA=AB=2a", "AB=BC=CD=a"...).
  static String _expandChainedEqualities(String source) {
    final pattern = RegExp(
      r'\b([a-z]{1,3}(?:\s*=\s*[a-z]{1,3})+)\s*=\s*'
      r'((?:\d+(?:[\.,]\d+)?)?\s*a(?:\s*/\s*\d+(?:[\.,]\d+)?)?)',
    );
    final matches = pattern.allMatches(source).toList();
    if (matches.isEmpty) return source;
    final buffer = StringBuffer(source);
    for (final match in matches) {
      final value = match.group(2)!.trim();
      for (final variable in match.group(1)!.split('=')) {
        final name = variable.trim();
        if (name.isEmpty) continue;
        buffer.write(' $name=$value');
      }
    }
    return buffer.toString();
  }

  /// 2D distance between two base vertices (by LOCAL index) of a pyramid's
  /// base, using the exact same coordinate scheme the viewport builds —
  /// rectangle corners for [PyramidBaseKind.rectangle], the right-triangle
  /// corners for [PyramidBaseKind.triangleRightAngle], the right-trapezoid
  /// corners for [PyramidBaseKind.rightTrapezoid] (needs [topWidth] = DC),
  /// or a regular n-gon with edge length [w] for anything else. Used to
  /// solve for the height via Pythagoras when the apex's distance to a
  /// base vertex OTHER than the first is given instead of the height
  /// itself.
  static double _baseVertexDistance(
      PyramidBaseKind kind, int n, double w, double d, int i, int j,
      {double? topWidth}) {
    List<Offset> points;
    if (kind == PyramidBaseKind.rectangle) {
      final x = w / 2, y = d / 2;
      points = [Offset(-x, -y), Offset(x, -y), Offset(x, y), Offset(-x, y)];
    } else if (kind == PyramidBaseKind.rightTrapezoid) {
      final x = w / 2, y = d / 2;
      final tw = topWidth ?? d;
      points = [
        Offset(-x, y), // A
        Offset(x, y), // B
        Offset(-x + tw, -y), // C
        Offset(-x, -y), // D
      ];
    } else if (kind == PyramidBaseKind.triangleRightAngle) {
      final x = w / 2, y = d / 2;
      points = [Offset(-x, -y), Offset(x, -y), Offset(x, y)];
    } else {
      final halfAngle = math.pi / n;
      final rx = w / (2 * math.sin(halfAngle));
      final ry = d / (2 * math.sin(halfAngle));
      points = List<Offset>.generate(n, (k) {
        final angle = -math.pi / 2 + 2 * math.pi * k / n;
        return Offset(rx * math.cos(angle), ry * math.sin(angle));
      });
    }
    if (i >= points.length || j >= points.length) return 0;
    return (points[i] - points[j]).distance;
  }

  static int _baseSides(String source, {int fallback = 4}) {
    for (final entry in _polygonNameSides.entries) {
      if (source.contains(entry.key)) return entry.value;
    }
    // Explicit apex naming "S.ABCDE", "S.ABCDEF"... names every base vertex
    // in one run of letters right after "S." — its length IS the side
    // count. Checked before the plain "abcd"/"abc" checks below so e.g.
    // "S.ABCDE" (5 vertices) isn't misread as "S.ABCD" (4) just because
    // "abcde" contains "abcd" as a substring.
    final apexNaming = RegExp(r's\s*\.\s*([a-z]{3,24})\b').firstMatch(source);
    final namedLetters = apexNaming?.group(1);
    if (namedLetters != null &&
        namedLetters.length >= 3 &&
        namedLetters.length <= 24) {
      return namedLetters.length;
    }
    if (source.contains('abcd')) return 4;
    if (source.contains('abc')) return 3;
    // "12 giac", "12-giac", "đa giác đều 9 giác"...
    final digitGon = RegExp(r'(\d+)\s*-?\s*giac').firstMatch(source);
    final fromDigitGon = int.tryParse(digitGon?.group(1) ?? '');
    if (fromDigitGon != null && fromDigitGon >= 3 && fromDigitGon <= 24) {
      return fromDigitGon;
    }
    // Explicit side-count wording: "số cạnh 9", "cạnh đáy 7".
    final match = RegExp(r'(?:so canh|canh day)\s*(\d+)').firstMatch(source);
    return int.tryParse(match?.group(1) ?? '') ?? fallback;
  }

  static String foldVietnamese(String value) {
    var result = value.toLowerCase();
    const replacements = {
      'đ': 'd',
      'á': 'a',
      'à': 'a',
      'ả': 'a',
      'ã': 'a',
      'ạ': 'a',
      'ă': 'a',
      'ắ': 'a',
      'ằ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'ặ': 'a',
      'â': 'a',
      'ấ': 'a',
      'ầ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ậ': 'a',
      'é': 'e',
      'è': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ẹ': 'e',
      'ê': 'e',
      'ế': 'e',
      'ề': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ệ': 'e',
      'í': 'i',
      'ì': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ị': 'i',
      'ó': 'o',
      'ò': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ọ': 'o',
      'ô': 'o',
      'ố': 'o',
      'ồ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ộ': 'o',
      'ơ': 'o',
      'ớ': 'o',
      'ờ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ợ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ụ': 'u',
      'ư': 'u',
      'ứ': 'u',
      'ừ': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ự': 'u',
      'ý': 'y',
      'ỳ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'ỵ': 'y',
    };
    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Illustrative volume estimate for the currently-built model, or null for
  /// shapes where "volume" doesn't apply (a bare plane). This is computed
  /// straight from the same width/height/depth/sides the viewport already
  /// uses to draw the solid, so it always matches what's on screen — but it
  /// is only as accurate as those dimensions are: when the prompt didn't
  /// give every measurement, some of them are illustrative defaults, so the
  /// value is explicitly labelled as an estimate rather than a solved
  /// answer to the exercise.
  static String? volumeDescription(Math3DConfig config) {
    final w = config.width;
    final h = config.height;
    final d = config.depth;
    final n = config.sides.clamp(3, 24);
    double? volume;
    switch (config.shape) {
      case Parametric3DShape.cube:
        volume = w * w * w;
      case Parametric3DShape.cuboid:
        volume = w * d * h;
      case Parametric3DShape.pyramid:
      case Parametric3DShape.tetrahedron:
        final double baseArea;
        if (config.pyramidBaseKind == PyramidBaseKind.rectangle) {
          baseArea = w * d;
        } else if (config.pyramidBaseKind == PyramidBaseKind.rightTrapezoid) {
          // Right trapezoid, parallel sides AB=w and DC=topWidth, height
          // (the perpendicular leg AD) = d: area = (w + DC)/2 · d.
          baseArea = (w + config.topWidth) / 2 * d;
        } else if (config.pyramidBaseKind ==
            PyramidBaseKind.triangleRightAngle) {
          baseArea = 0.5 * w * d;
        } else {
          // Regular n-gon with EDGE LENGTH w (an ellipse-distorted version
          // when d differs — same illustrative approximation the geometry
          // itself uses): area = n·s²/(4·tan(π/n)), scaled by d/w for the
          // second axis so it matches the actual drawn (possibly slightly
          // elliptical) base exactly.
          baseArea = (n * w * d) / (4 * math.tan(math.pi / n));
        }
        volume = baseArea * h / 3;
      case Parametric3DShape.frustum:
        final a1 = w * d;
        final a2 = config.topWidth * config.topDepth;
        volume = h / 3 * (a1 + a2 + math.sqrt(a1 * a2));
      case Parametric3DShape.prism:
        final baseArea = config.prismRightTriangleBase
            ? 0.5 * w * d // right triangle: legs w (AB) and d (AC)
            : (n * w * w) / (4 * math.tan(math.pi / n)); // regular n-gon
        volume = baseArea * h;
      case Parametric3DShape.cylinder:
        volume = math.pi * (w / 2) * (w / 2) * h;
      case Parametric3DShape.cone:
        volume = math.pi * (w / 2) * (w / 2) * h / 3;
      case Parametric3DShape.sphere:
        final r = w / 2;
        volume = 4 / 3 * math.pi * r * r * r;
      case Parametric3DShape.plane:
        volume = null;
    }
    if (volume == null || volume <= 0) return null;
    final label = shapeLabel(config.shape);
    final unitA = config.sceneUnitsPerA;
    final valueText = !config.hasNumericMeasurements && unitA > 0
        ? '≈ ${_formatRatio(volume / (unitA * unitA * unitA))}·a³'
        : '≈ ${_formatRatio(volume)} (đơn vị³)';
    return 'Thể tích minh họa của $label theo mô hình: V $valueText. Đây là ước lượng theo tỉ lệ dựng hình, không thay thế lời giải chi tiết của bài toán.';
  }

  static String _formatRatio(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(2);
  }
}

class Parametric3DCard extends StatefulWidget {
  final Math3DConfig config;

  const Parametric3DCard({super.key, required this.config});

  @override
  State<Parametric3DCard> createState() => _Parametric3DCardState();
}

class _Parametric3DCardState extends State<Parametric3DCard> {
  double _yaw = 0.0;
  double _pitch = 0.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        True3DViewport(config: widget.config),
        const SizedBox(height: 8),
        const Text(
          'Viewport 3D',
          style: TextStyle(
              color: AppColors.secondary,
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(widget.config.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 4),
        Text(widget.config.caption,
            style: const TextStyle(
                color: AppColors.textSecondary, height: 1.4, fontSize: 12)),
        if (Math3DConfig.volumeDescription(widget.config) != null) ...[
          const SizedBox(height: 6),
          Text(
            Math3DConfig.volumeDescription(widget.config)!,
            style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}

class _V3 {
  final double x;
  final double y;
  final double z;
  const _V3(this.x, this.y, this.z);
}

class _Parametric3DPainter extends CustomPainter {
  final Math3DConfig config;
  final double yaw;
  final double pitch;

  _Parametric3DPainter(this.config, this.yaw, this.pitch);

  final _line = const Color(0xFF6758DA);
  final _hidden = const Color(0xFFB8B3E8);
  final _accent = const Color(0xFF17B897);
  final _gold = const Color(0xFFFFB84D);
  double _scale = 1;
  Offset _offset = Offset.zero;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF7F6FF), BlendMode.srcOver);
    final points = <_V3>[];
    final edges = <List<int>>[];
    final faces = <List<int>>[];
    final labels = <String>[];
    final axisLength = math.max(3.4,
        math.max(config.width, math.max(config.height, config.depth)) + 1.1);

    switch (config.shape) {
      case Parametric3DShape.cube:
        _cuboid(points, edges, faces, labels, cube: true);
      case Parametric3DShape.cuboid:
        _cuboid(points, edges, faces, labels);
      case Parametric3DShape.pyramid:
        _pyramid(points, edges, faces, labels);
      case Parametric3DShape.frustum:
        _frustum(points, edges, faces, labels);
      case Parametric3DShape.tetrahedron:
        _tetrahedron(points, edges, faces, labels);
      case Parametric3DShape.prism:
        _polygonSolid(points, edges, faces, labels, math.max(3, config.sides));
      case Parametric3DShape.cylinder:
        _polygonSolid(points, edges, faces, labels, math.max(12, config.sides));
      case Parametric3DShape.cone:
        _cone(points, edges, faces, labels, math.max(12, config.sides));
      case Parametric3DShape.sphere:
        _fitScene(size, const [], axisLength);
        _drawAxes(canvas, size, axisLength);
        _sphere(canvas, size);
        _label(canvas, 'R',
            _project(const _V3(0.9, 0, 0), size) + const Offset(6, -6), _gold);
        return;
      case Parametric3DShape.plane:
        _plane(points, edges, faces, labels);
    }

    _fitScene(size, points, axisLength);
    if (config.showAxes) {
      _drawAxes(canvas, size, axisLength);
    }
    _drawFaces(canvas, size, points, faces);

    final paint = Paint()
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final edge in edges) {
      paint.color = _line;
      canvas.drawLine(_project(points[edge[0]], size),
          _project(points[edge[1]], size), paint);
    }

    for (var i = 0; i < labels.length && i < points.length; i++) {
      _label(canvas, labels[i],
          _project(points[i], size) + const Offset(5, -14), _line);
    }
    if (config.showAxes) {
      _label(canvas, 'O',
          _project(const _V3(0, 0, 0), size) + const Offset(-14, 5), _hidden);
    }
    if (config.shape == Parametric3DShape.pyramid ||
        config.shape == Parametric3DShape.cone) {
      _label(
          canvas,
          'h',
          _project(_V3(0, 0, config.height), size) + const Offset(7, 8),
          _accent);
    }
    if (config.shape != Parametric3DShape.plane) {
      _label(canvas, config.sideLabel, const Offset(20, 24), _line);
    }
  }

  void _fitScene(Size size, List<_V3> points, double axisLength) {
    final scene = <_V3>[...points];
    if (config.showAxes || scene.isEmpty) {
      scene.addAll([
        const _V3(0, 0, 0),
        _V3(axisLength, 0, 0),
        _V3(0, axisLength, 0),
        _V3(0, 0, axisLength),
      ]);
    }
    final raw = scene.map((point) => _raw(point)).toList();
    final minX = raw.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final maxX = raw.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final minY = raw.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxY = raw.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    final rangeX = math.max(1, maxX - minX);
    final rangeY = math.max(1, maxY - minY);
    _scale = math.min((size.width - 48) / rangeX, (size.height - 48) / rangeY);
    _offset = Offset(
      size.width / 2 - (minX + maxX) * _scale / 2,
      size.height / 2 - (minY + maxY) * _scale / 2,
    );
  }

  Offset _raw(_V3 point) {
    final c = math.cos(yaw);
    final s = math.sin(yaw);
    final x = point.x * c - point.y * s;
    final y = point.x * s + point.y * c;
    const depthSlope = 0.62;
    const groundSlope = 0.38;
    final screenX = x - y * depthSlope;
    final ground = (x + y) * groundSlope;
    final screenY = ground - point.z * math.cos(pitch);
    return Offset(screenX, screenY);
  }

  Offset _project(_V3 point, Size size) => _raw(point) * _scale + _offset;

  void _cuboid(
    List<_V3> p,
    List<List<int>> e,
    List<List<int>> f,
    List<String> labels, {
    bool cube = false,
  }) {
    final w = cube ? config.width : config.width;
    final d = cube ? config.width : config.depth;
    final h = cube ? config.width : config.height;
    p.addAll([
      _V3(0, 0, 0),
      _V3(w, 0, 0),
      _V3(w, d, 0),
      _V3(0, d, 0),
      _V3(0, 0, h),
      _V3(w, 0, h),
      _V3(w, d, h),
      _V3(0, d, h),
    ]);
    e.addAll([
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 0],
      [4, 5],
      [5, 6],
      [6, 7],
      [7, 4],
      [0, 4],
      [1, 5],
      [2, 6],
      [3, 7],
    ]);
    f.addAll([
      [0, 1, 2, 3],
      [4, 7, 6, 5],
      [0, 4, 5, 1]
    ]);
    labels.addAll(["A", "B", "C", "D", "A'", "B'", "C'", "D'"]);
  }

  void _frustum(
      List<_V3> p, List<List<int>> e, List<List<int>> f, List<String> labels) {
    final bottom = config.width;
    final top = config.topWidth;
    final dBottom = config.depth;
    final dTop = config.topDepth;
    final h = config.height;
    p.addAll([
      _V3(0, 0, 0),
      _V3(bottom, 0, 0),
      _V3(bottom, dBottom, 0),
      _V3(0, dBottom, 0),
      _V3((bottom - top) / 2, (dBottom - dTop) / 2, h),
      _V3((bottom + top) / 2, (dBottom - dTop) / 2, h),
      _V3((bottom + top) / 2, (dBottom + dTop) / 2, h),
      _V3((bottom - top) / 2, (dBottom + dTop) / 2, h),
    ]);
    e.addAll([
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 0],
      [4, 5],
      [5, 6],
      [6, 7],
      [7, 4],
      [0, 4],
      [1, 5],
      [2, 6],
      [3, 7],
    ]);
    f.addAll([
      [0, 1, 2, 3],
      [4, 7, 6, 5],
      [0, 4, 5, 1],
      [1, 5, 6, 2],
      [2, 6, 7, 3],
      [3, 7, 4, 0],
    ]);
    labels.addAll(["A", "B", "C", "D", "A'", "B'", "C'", "D'"]);
  }

  void _pyramid(
      List<_V3> p, List<List<int>> e, List<List<int>> f, List<String> labels) {
    final n = config.sides.clamp(3, 8).toInt();
    final rx = config.width / 2;
    final ry = config.depth / 2;
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 4 + 2 * math.pi * i / n;
      p.add(_V3(rx + rx * math.cos(angle), ry + ry * math.sin(angle), 0));
    }
    final apexBase = config.apexBaseIndex >= 0 && config.apexBaseIndex < n
        ? p[config.apexBaseIndex]
        : _V3(rx, ry, 0);
    p.add(_V3(apexBase.x, apexBase.y, config.height));
    for (var i = 0; i < n; i++) {
      final next = (i + 1) % n;
      e.add([i, next]);
      e.add([i, n]);
      f.add([i, next, n]);
    }
    f.insert(0, List<int>.generate(n, (i) => i));
    labels.addAll(['A', 'B', 'C', 'D'].take(n));
    labels.add('S');
  }

  void _tetrahedron(
      List<_V3> p, List<List<int>> e, List<List<int>> f, List<String> labels) {
    final w = config.width;
    final d = config.depth;
    p.addAll([
      _V3(0, 0, 0),
      _V3(w, 0, 0),
      _V3(w / 2, d, 0),
      _V3(w / 2, d / 3, config.height),
    ]);
    e.addAll([
      [0, 1],
      [1, 2],
      [2, 0],
      [0, 3],
      [1, 3],
      [2, 3]
    ]);
    f.addAll([
      [0, 1, 2],
      [0, 1, 3],
      [1, 2, 3],
      [2, 0, 3]
    ]);
    labels.addAll(['A', 'B', 'C', 'D']);
  }

  void _polygonSolid(List<_V3> p, List<List<int>> e, List<List<int>> f,
      List<String> labels, int n) {
    final rx = config.width / 2;
    final ry = config.depth / 2;
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      p.add(_V3(rx + rx * math.cos(angle), ry + ry * math.sin(angle), 0));
    }
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      p.add(_V3(
          rx + rx * math.cos(angle), ry + ry * math.sin(angle), config.height));
    }
    for (var i = 0; i < n; i++) {
      final next = (i + 1) % n;
      e.addAll([
        [i, next],
        [i + n, next + n],
        [i, i + n]
      ]);
      f.add([i, next, next + n, i + n]);
    }
    f.add(List<int>.generate(n, (i) => i));
    f.add(List<int>.generate(n, (i) => i + n).reversed.toList());
    if (n <= 6) labels.addAll(['A', 'B', 'C', 'D', 'E', 'F'].take(n));
  }

  void _cone(List<_V3> p, List<List<int>> e, List<List<int>> f,
      List<String> labels, int n) {
    final rx = config.width / 2;
    final ry = config.depth / 2;
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      p.add(_V3(rx + rx * math.cos(angle), ry + ry * math.sin(angle), 0));
    }
    p.add(_V3(rx, ry, config.height));
    for (var i = 0; i < n; i++) {
      final next = (i + 1) % n;
      e.addAll([
        [i, next],
        [i, n]
      ]);
      f.add([i, next, n]);
    }
    f.insert(0, List<int>.generate(n, (i) => i));
    labels.add('A');
    labels.add('S');
  }

  void _plane(
      List<_V3> p, List<List<int>> e, List<List<int>> f, List<String> labels) {
    final w = config.width;
    final d = config.depth;
    p.addAll([_V3(0, 0, 0), _V3(w, 0, 0), _V3(w, d, 0), _V3(0, d, 0)]);
    e.addAll([
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 0]
    ]);
    f.add([0, 1, 2, 3]);
    labels.addAll(['A', 'B', 'C', 'D']);
  }

  void _drawFaces(
      Canvas canvas, Size size, List<_V3> points, List<List<int>> faces) {
    final fillColors = [
      _line.withValues(alpha: 0.08),
      _accent.withValues(alpha: 0.10),
      _gold.withValues(alpha: 0.10),
    ];
    for (var i = 0; i < faces.length; i++) {
      final face = faces[i];
      if (face.length < 3) continue;
      final path = Path()
        ..moveTo(_project(points[face[0]], size).dx,
            _project(points[face[0]], size).dy);
      for (final index in face.skip(1)) {
        final point = _project(points[index], size);
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = fillColors[i % fillColors.length]);
    }
  }

  void _sphere(Canvas canvas, Size size) {
    final radius = config.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    for (var latitude = -3; latitude <= 3; latitude++) {
      final phi = latitude * math.pi / 8;
      final path = Path();
      for (var i = 0; i <= 48; i++) {
        final theta = 2 * math.pi * i / 48;
        final point = _project(
          _V3(
            radius + radius * math.cos(phi) * math.cos(theta),
            radius + radius * math.cos(phi) * math.sin(theta),
            radius + radius * math.sin(phi),
          ),
          size,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      paint.color = latitude == 0 ? _accent : _line.withValues(alpha: 0.55);
      canvas.drawPath(path, paint);
    }
    for (var longitude = 0; longitude < 10; longitude++) {
      final theta = 2 * math.pi * longitude / 10;
      final path = Path();
      for (var i = 0; i <= 32; i++) {
        final phi = -math.pi / 2 + math.pi * i / 32;
        final point = _project(
          _V3(
            radius + radius * math.cos(phi) * math.cos(theta),
            radius + radius * math.cos(phi) * math.sin(theta),
            radius + radius * math.sin(phi),
          ),
          size,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      paint.color = _line.withValues(alpha: 0.42);
      canvas.drawPath(path, paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, double length) {
    final origin = _project(const _V3(0, 0, 0), size);
    final x = _project(_V3(length, 0, 0), size);
    final y = _project(_V3(0, length, 0), size);
    final z = _project(_V3(0, 0, length), size);
    _arrow(canvas, origin, x, _line);
    _arrow(canvas, origin, y, _accent);
    _arrow(canvas, origin, z, _gold);
    _label(canvas, 'Ox', x + const Offset(4, -4), _line);
    _label(canvas, 'Oy', y + const Offset(-20, -2), _accent);
    _label(canvas, 'Oz', z + const Offset(5, -4), _gold);
  }

  void _arrow(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..strokeWidth = 1.5;
    canvas.drawLine(start, end, paint);
    final direction = (end - start);
    final length = direction.distance;
    if (length == 0) return;
    final unit = direction / length;
    final normal = Offset(-unit.dy, unit.dx);
    final base = end - unit * 9;
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo((base + normal * 4).dx, (base + normal * 4).dy)
      ..lineTo((base - normal * 4).dx, (base - normal * 4).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.72));
  }

  void _label(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  bool shouldRepaint(covariant _Parametric3DPainter oldDelegate) =>
      oldDelegate.config != config ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch;
}
