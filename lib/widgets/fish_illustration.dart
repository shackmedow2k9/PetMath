import 'dart:math';
import 'package:flutter/material.dart';
import '../models/fish_data.dart';

/// Vẽ 1 loài cá/vật phẩm bằng hình VECTOR đơn giản, dễ thương — KHÔNG dùng
/// ảnh cá thật. Mỗi [FishShape] là 1 khuôn hình riêng đúng với đặc điểm cơ
/// bản của loài thật (cá trê có ria, cá đuối dẹt, ốc có vỏ xoắn, sao biển
/// hình sao...), tô màu bằng đúng màu riêng của loài đó
/// ([FishSpecies.color]) để 2 loài cùng khuôn hình (ví dụ rùa nhỏ/rùa
/// khổng lồ) vẫn phân biệt được qua màu.
class FishIllustration extends StatelessWidget {
  final FishShape shape;
  final Color color;
  final double size;

  const FishIllustration({
    super.key,
    required this.shape,
    required this.color,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FishIllustrationPainter(shape: shape, color: color),
      ),
    );
  }
}

/// Tiện ích: chuyển toạ độ lưới 0..100 (dễ "vẽ tay" bằng số) sang toạ độ
/// canvas thật, luôn căn giữa và co dãn theo [size] của widget.
typedef _G = Offset Function(double gx, double gy);

Path _poly(_G g, List<List<double>> pts) {
  final path = Path();
  for (var i = 0; i < pts.length; i++) {
    final p = g(pts[i][0], pts[i][1]);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

/// Vẽ 1 khối thân THON DẦN dọc theo 1 đường tâm — mỗi điểm [x, y, nửa-bề-rộng]
/// (đơn vị lưới 0..100). Dùng để tạo thân cá mập mũi nhọn / rồng biển uốn
/// lượn mượt mà, thay vì ghép nhiều hình tròn cứng nhắc trông như sâu.
Path _taperedSnake(_G g, double s, List<List<double>> centerline) {
  final n = centerline.length;
  final topPts = <Offset>[];
  final bottomPts = <Offset>[];
  for (var i = 0; i < n; i++) {
    final cx = centerline[i][0];
    final cy = centerline[i][1];
    final hw = centerline[i][2];
    double dx, dy;
    if (i == 0) {
      dx = centerline[1][0] - cx;
      dy = centerline[1][1] - cy;
    } else if (i == n - 1) {
      dx = cx - centerline[i - 1][0];
      dy = cy - centerline[i - 1][1];
    } else {
      dx = centerline[i + 1][0] - centerline[i - 1][0];
      dy = centerline[i + 1][1] - centerline[i - 1][1];
    }
    final len = sqrt(dx * dx + dy * dy);
    final ux = len == 0 ? 0.0 : dx / len;
    final uy = len == 0 ? 0.0 : dy / len;
    final px = -uy;
    final py = ux;
    topPts.add(g(cx + px * hw, cy + py * hw));
    bottomPts.add(g(cx - px * hw, cy - py * hw));
  }
  final path = Path()..moveTo(topPts.first.dx, topPts.first.dy);
  for (var i = 1; i < topPts.length; i++) {
    path.lineTo(topPts[i].dx, topPts[i].dy);
  }
  for (var i = bottomPts.length - 1; i >= 0; i--) {
    path.lineTo(bottomPts[i].dx, bottomPts[i].dy);
  }
  path.close();
  return path;
}

class _FishIllustrationPainter extends CustomPainter {
  final FishShape shape;
  final Color color;

  _FishIllustrationPainter({required this.shape, required this.color});

  Color get _dark {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0))
        .toColor();
  }

  Color get _light {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.24).clamp(0.0, 1.0)).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    final origin = size.center(Offset.zero) - Offset(50 * s, 50 * s);
    Offset g(double x, double y) => origin + Offset(x * s, y * s);

    final body = Paint()..color = color;
    final dark = Paint()..color = _dark;
    final light = Paint()..color = _light;
    final white = Paint()..color = Colors.white;
    final white70 = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final black = Paint()..color = Colors.black87;

    switch (shape) {
      case FishShape.genericFish:
        _fishLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.eelFish:
        _eelLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.catfish:
        _fishLike(canvas, g, s, body, dark, white, black, whiskers: true);
        break;
      case FishShape.pufferRound:
        _pufferLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.goldfishFancy:
        _fishLike(canvas, g, s, body, dark, white, black, flowingTail: true);
        break;
      case FishShape.koiFish:
        _fishLike(canvas, g, s, body, dark, white, black,
            flowingTail: true, spots: true, spotPaint: white70);
        break;
      case FishShape.bettaFish:
        _bettaLike(canvas, g, s, body, light, dark, white, black);
        break;
      case FishShape.angelfish:
        _angelLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.clownfish:
        _fishLike(canvas, g, s, body, dark, white, black, stripes: true);
        break;
      case FishShape.swordtailFish:
        _fishLike(canvas, g, s, body, dark, white, black, sword: true);
        break;
      case FishShape.flyingFish:
        _fishLike(canvas, g, s, body, dark, white, black, wings: true);
        break;
      case FishShape.rayFlat:
        _rayLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.seahorseCurve:
        _seahorseLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.sharkFin:
        _sharkLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.dolphinCurve:
        _dolphinLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.whaleBig:
        _whaleLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.shrimpCurl:
        _shrimpLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.prawnClaw:
        _shrimpLike(canvas, g, s, body, dark, white, black, claws: true);
        break;
      case FishShape.crabShell:
        _crabLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.snailShell:
        _snailLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.nautilusShell:
        _snailLike(canvas, g, s, body, dark, white, black, banded: true);
        break;
      case FishShape.abaloneShell:
        _abaloneLike(canvas, g, s, body, dark, light);
        break;
      case FishShape.oysterPearl:
        _oysterLike(canvas, g, s, body, dark, white);
        break;
      case FishShape.starfishPoint:
        _starLike(canvas, g, s, body, dark);
        break;
      case FishShape.coralBranch:
        _coralLike(canvas, g, s, body, dark, light);
        break;
      case FishShape.seaweedFresh:
        _seaweedLike(canvas, g, s, body, dark, drooping: false);
        break;
      case FishShape.seaweedDried:
        _seaweedLike(canvas, g, s, body, dark, drooping: true);
        break;
      case FishShape.squidGiant:
        _squidLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.octopusCute:
        _octopusLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.turtleShell:
        _turtleLike(canvas, g, s, body, dark, light, white, black);
        break;
      case FishShape.sealCute:
        _sealLike(canvas, g, s, body, dark, white, black);
        break;
      case FishShape.penguinCute:
        _penguinLike(canvas, g, s, body, white, black);
        break;
      case FishShape.jellyfishGlow:
        _jellyfishLike(canvas, g, s, body, light, white);
        break;
      case FishShape.mermaidTreasure:
        _mermaidLike(canvas, g, s, body, dark, light, white, black);
        break;
      case FishShape.dragonSea:
        _dragonLike(canvas, g, s, body, dark, light, white, black);
        break;
      case FishShape.crownRoyal:
        _crownLike(canvas, g, s, body, dark, light);
        break;
      case FishShape.treasureChest:
        _chestLike(canvas, g, s, body, dark, light);
        break;
      case FishShape.bootShoe:
        _bootLike(canvas, g, s, body, dark);
        break;
      case FishShape.canRusty:
        _canLike(canvas, g, s, body, dark);
        break;
      case FishShape.bottleGlass:
        _bottleLike(canvas, g, s, body, dark, light);
        break;
      case FishShape.sandalFlip:
        _sandalLike(canvas, g, s, body, dark);
        break;
      case FishShape.plasticBag:
        _bagLike(canvas, g, s, body, dark);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FishIllustrationPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}

// ============================================================
// NHÓM CÁ (thân bầu dục quay đầu bên trái, đuôi bên phải).
// ============================================================

void _fishLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black,
    {bool whiskers = false,
    bool flowingTail = false,
    bool spots = false,
    Paint? spotPaint,
    bool stripes = false,
    bool sword = false,
    bool wings = false}) {
  canvas.drawOval(Rect.fromPoints(g(18, 30), g(82, 70)), body);

  if (flowingTail) {
    final tail = Path()
      ..moveTo(g(78, 38).dx, g(78, 38).dy)
      ..quadraticBezierTo(
          g(98, 18).dx, g(98, 18).dy, g(100, 40).dx, g(100, 40).dy)
      ..quadraticBezierTo(
          g(88, 50).dx, g(88, 50).dy, g(100, 60).dx, g(100, 60).dy)
      ..quadraticBezierTo(
          g(98, 82).dx, g(98, 82).dy, g(78, 62).dx, g(78, 62).dy)
      ..close();
    canvas.drawPath(tail, dark);
  } else if (sword) {
    // Thùy đuôi TRÊN — bình thường, nhỏ gọn.
    canvas.drawPath(
        _poly(g, [
          [80, 48],
          [98, 34],
          [90, 54]
        ]),
        dark);
    // Thùy đuôi DƯỚI kéo dài thành 1 thanh KIẾM nhọn, dài rõ ràng —
    // đặc điểm nhận dạng của cá đuôi kiếm, không bị lẫn vào đuôi trên.
    canvas.drawPath(
        _poly(g, [
          [80, 54],
          [104, 78],
          [84, 62]
        ]),
        dark);
    final edgeP = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * s;
    canvas.drawLine(g(82, 58), g(104, 78), edgeP);
  } else {
    canvas.drawPath(
        _poly(g, [
          [80, 50],
          [100, 32],
          [100, 68]
        ]),
        dark);
  }

  canvas.drawPath(
      _poly(g, [
        [42, 32],
        [52, 12],
        [62, 32]
      ]),
      dark);
  canvas.drawPath(
      _poly(g, [
        [44, 67],
        [52, 84],
        [60, 67]
      ]),
      dark);

  if (wings) {
    canvas.drawPath(
        _poly(g, [
          [38, 34],
          [12, 6],
          [50, 30]
        ]),
        dark);
    canvas.drawPath(
        _poly(g, [
          [38, 66],
          [12, 94],
          [50, 70]
        ]),
        dark);
  }
  if (whiskers) {
    final wp = Paint()
      ..color = dark.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(g(22, 55), g(4, 50), wp);
    canvas.drawLine(g(22, 59), g(4, 66), wp);
  }
  if (stripes) {
    final sp = Paint()..color = white.color;
    for (final x in [32.0, 48.0, 64.0]) {
      canvas.drawRect(Rect.fromPoints(g(x, 31), g(x + 6, 69)), sp);
    }
  }
  if (spots) {
    canvas.drawCircle(g(40, 40), 5 * s, spotPaint ?? white);
    canvas.drawCircle(g(58, 58), 4 * s, spotPaint ?? white);
  }

  canvas.drawCircle(g(28, 44), 5 * s, white);
  canvas.drawCircle(g(29, 44), 2.3 * s, black);
}

void _eelLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  final bodyPath = Path()
    ..moveTo(g(4, 50).dx, g(4, 50).dy)
    ..quadraticBezierTo(g(32, 26).dx, g(32, 26).dy, g(62, 40).dx, g(62, 40).dy)
    ..quadraticBezierTo(g(86, 46).dx, g(86, 46).dy, g(94, 50).dx, g(94, 50).dy)
    ..quadraticBezierTo(g(86, 54).dx, g(86, 54).dy, g(62, 60).dx, g(62, 60).dy)
    ..quadraticBezierTo(g(32, 74).dx, g(32, 74).dy, g(4, 50).dx, g(4, 50).dy)
    ..close();
  canvas.drawPath(bodyPath, body);
  canvas.drawPath(
      _poly(g, [
        [90, 44],
        [100, 50],
        [90, 56]
      ]),
      dark);
  canvas.drawCircle(g(15, 45), 4 * s, white);
  canvas.drawCircle(g(16, 45), 2 * s, black);
}

void _pufferLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  canvas.drawCircle(g(48, 52), 30 * s, body);
  final spikeP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6 * s
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 10; i++) {
    final angle = (2 * pi / 10) * i;
    final inner = g(48, 52) + Offset(cos(angle), sin(angle)) * 29 * s;
    final outer = g(48, 52) + Offset(cos(angle), sin(angle)) * 37 * s;
    canvas.drawLine(inner, outer, spikeP);
  }
  canvas.drawPath(
      _poly(g, [
        [76, 44],
        [92, 52],
        [76, 60]
      ]),
      dark);
  canvas.drawCircle(g(34, 42), 5 * s, white);
  canvas.drawCircle(g(35, 42), 2.3 * s, black);
}

void _bettaLike(Canvas canvas, _G g, double s, Paint body, Paint light,
    Paint dark, Paint white, Paint black) {
  // Vây to xoè bay bổng — vẽ trước để thân cá nằm trên.
  final finPaint = Paint()..color = light.color.withValues(alpha: 0.85);
  canvas.drawPath(
      _poly(g, [
        [52, 40],
        [96, 10],
        [100, 30],
        [60, 46]
      ]),
      finPaint);
  canvas.drawPath(
      _poly(g, [
        [52, 60],
        [96, 90],
        [100, 70],
        [60, 54]
      ]),
      finPaint);
  canvas.drawPath(
      _poly(g, [
        [48, 44],
        [90, 50],
        [48, 56]
      ]),
      finPaint);
  canvas.drawOval(Rect.fromPoints(g(16, 38), g(56, 62)), body);
  canvas.drawCircle(g(26, 48), 4.5 * s, white);
  canvas.drawCircle(g(27, 48), 2 * s, black);
}

void _angelLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  canvas.drawPath(
      _poly(g, [
        [50, 10],
        [22, 50],
        [50, 90],
        [78, 50]
      ]),
      body);
  // Vây kéo dài
  final finP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2 * s
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(g(50, 12), g(58, 0), finP);
  canvas.drawLine(g(50, 88), g(58, 100), finP);
  canvas.drawPath(
      _poly(g, [
        [74, 44],
        [92, 50],
        [74, 56]
      ]),
      dark);
  canvas.drawCircle(g(58, 40), 4.5 * s, white);
  canvas.drawCircle(g(59, 40), 2 * s, black);
}

void _rayLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  canvas.drawPath(
      _poly(g, [
        [50, 20],
        [10, 50],
        [50, 62],
        [90, 50]
      ]),
      body);
  final tailP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6 * s
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(g(50, 60), g(60, 96), tailP);
  canvas.drawCircle(g(42, 42), 4 * s, white);
  canvas.drawCircle(g(43, 42), 2 * s, black);
  canvas.drawCircle(g(58, 42), 4 * s, white);
  canvas.drawCircle(g(59, 42), 2 * s, black);
}

void _seahorseLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  final bodyP = Paint()
    ..color = body.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 15 * s
    ..strokeCap = StrokeCap.round;
  final path = Path()
    ..moveTo(g(50, 14).dx, g(50, 14).dy)
    ..quadraticBezierTo(g(30, 22).dx, g(30, 22).dy, g(34, 42).dx, g(34, 42).dy)
    ..quadraticBezierTo(g(40, 58).dx, g(40, 58).dy, g(60, 60).dx, g(60, 60).dy)
    ..quadraticBezierTo(g(80, 62).dx, g(80, 62).dy, g(78, 78).dx, g(78, 78).dy)
    ..quadraticBezierTo(g(76, 90).dx, g(76, 90).dy, g(62, 88).dx, g(62, 88).dy);
  canvas.drawPath(path, bodyP);
  // Vây lưng nhỏ
  final finP = Paint()..color = dark.color;
  canvas.drawPath(
      _poly(g, [
        [50, 40],
        [64, 34],
        [56, 52]
      ]),
      finP);
  // Vòi mõm nhỏ phía trước đầu
  final snoutP = Paint()
    ..color = body.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6 * s
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(g(46, 12), g(34, 10), snoutP);
  canvas.drawCircle(g(50, 14), 4 * s, white);
  canvas.drawCircle(g(51, 14), 1.8 * s, black);
}

void _sharkLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  // Thân thon, MŨI NHỌN phía trước — dùng thân thon dần thay vì hình bầu
  // dục tròn trịa, trông "ngầu" và giống cá mập thật hơn.
  final centerline = [
    [4.0, 52.0, 2.0],
    [20.0, 50.0, 11.0],
    [46.0, 50.0, 14.0],
    [72.0, 50.0, 9.0],
    [92.0, 50.0, 3.0],
  ];
  canvas.drawPath(_taperedSnake(g, s, centerline), body);

  // Vây lưng dựng CAO, nhọn hẳn lên — dữ dằn hơn bản cũ (thấp, tù).
  canvas.drawPath(
      _poly(g, [
        [34, 40],
        [48, 4],
        [60, 40]
      ]),
      dark);
  // Đuôi 2 thùy KHÔNG ĐỀU (thùy trên to, thùy dưới nhỏ) — đặc trưng đuôi
  // cá mập thật, khác hẳn đuôi cân đối của cá thường.
  canvas.drawPath(
      _poly(g, [
        [82, 42],
        [102, 10],
        [100, 46],
        [86, 48]
      ]),
      dark);
  canvas.drawPath(
      _poly(g, [
        [84, 54],
        [100, 70],
        [84, 58]
      ]),
      dark);
  // Vây bụng nhọn phía dưới.
  canvas.drawPath(
      _poly(g, [
        [42, 58],
        [52, 76],
        [64, 58]
      ]),
      dark);
  // Mang cá — vài đường cong nhỏ sau đầu.
  final gillP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4 * s;
  for (final x in [16.0, 21.0, 26.0]) {
    canvas.drawLine(g(x, 42), g(x - 3, 58), gillP);
  }
  // Miệng RĂNG CƯA dữ tợn thay vì 1 đường thẳng đơn giản.
  final mouthPath = Path();
  final mx = [4.0, 9.0, 14.0, 19.0, 24.0];
  for (var i = 0; i < mx.length; i++) {
    final y = i.isEven ? 60.0 : 55.0;
    if (i == 0) {
      mouthPath.moveTo(g(mx[i], y).dx, g(mx[i], y).dy);
    } else {
      mouthPath.lineTo(g(mx[i], y).dx, g(mx[i], y).dy);
    }
  }
  canvas.drawPath(
      mouthPath,
      Paint()
        ..color = dark.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * s);
  // Mắt nhỏ, sắc.
  canvas.drawCircle(g(16, 45), 2.6 * s, black);
}

void _dolphinLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  final path = Path()
    ..moveTo(g(8, 52).dx, g(8, 52).dy)
    ..quadraticBezierTo(g(20, 30).dx, g(20, 30).dy, g(46, 34).dx, g(46, 34).dy)
    ..quadraticBezierTo(g(70, 36).dx, g(70, 36).dy, g(88, 48).dx, g(88, 48).dy)
    ..quadraticBezierTo(g(70, 50).dx, g(70, 50).dy, g(46, 58).dx, g(46, 58).dy)
    ..quadraticBezierTo(g(20, 66).dx, g(20, 66).dy, g(8, 52).dx, g(8, 52).dy)
    ..close();
  canvas.drawPath(path, body);
  canvas.drawPath(
      _poly(g, [
        [86, 42],
        [100, 30],
        [96, 48]
      ]),
      dark);
  canvas.drawPath(
      _poly(g, [
        [44, 30],
        [52, 14],
        [58, 32]
      ]),
      dark);
  canvas.drawCircle(g(20, 26), 2 * s, dark);
  canvas.drawCircle(g(18, 44), 3.4 * s, white);
  canvas.drawCircle(g(19, 44), 1.6 * s, black);
}

void _whaleLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  canvas.drawPath(
      _poly(g, [
        [6, 55],
        [12, 32],
        [45, 22],
        [78, 34],
        [86, 55],
        [70, 68],
        [30, 68]
      ]),
      body);
  canvas.drawPath(
      _poly(g, [
        [80, 40],
        [100, 22],
        [100, 58],
        [80, 50]
      ]),
      dark);
  canvas.drawOval(Rect.fromPoints(g(28, 60), g(56, 74)), dark);
  canvas.drawCircle(g(38, 26), 2.6 * s, dark);
  canvas.drawCircle(g(20, 46), 4 * s, white);
  canvas.drawCircle(g(21, 46), 2 * s, black);
}

// ============================================================
// NHÓM GIÁP XÁC / THÂN MỀM (tôm, cua, ốc, sò, sao biển, san hô...)
// ============================================================

void _shrimpLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black,
    {bool claws = false}) {
  final path = Path()
    ..moveTo(g(20, 30).dx, g(20, 30).dy)
    ..quadraticBezierTo(g(60, 20).dx, g(60, 20).dy, g(80, 50).dx, g(80, 50).dy)
    ..quadraticBezierTo(g(70, 60).dx, g(70, 60).dy, g(50, 55).dx, g(50, 55).dy)
    ..quadraticBezierTo(g(30, 50).dx, g(30, 50).dy, g(20, 30).dx, g(20, 30).dy)
    ..close();
  canvas.drawPath(path, body);
  canvas.drawPath(
      _poly(g, [
        [76, 44],
        [96, 36],
        [92, 56],
        [76, 54]
      ]),
      dark);
  final legP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6 * s;
  for (final x in [35.0, 45.0, 55.0]) {
    canvas.drawLine(g(x, 48), g(x - 4, 62), legP);
  }
  canvas.drawLine(g(20, 30), g(6, 18), legP);
  if (claws) {
    canvas.drawOval(Rect.fromPoints(g(2, 8), g(18, 20)), dark);
    canvas.drawOval(Rect.fromPoints(g(14, 26), g(30, 38)), dark);
  }
  canvas.drawCircle(g(24, 30), 3 * s, white);
  canvas.drawCircle(g(25, 30), 1.4 * s, black);
}

void _crabLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  canvas.drawOval(Rect.fromPoints(g(20, 34), g(80, 70)), body);
  canvas.drawOval(Rect.fromPoints(g(2, 20), g(24, 40)), dark);
  canvas.drawOval(Rect.fromPoints(g(76, 20), g(98, 40)), dark);
  canvas.drawLine(
      g(14, 32),
      g(2, 20),
      Paint()
        ..color = dark.color
        ..strokeWidth = 3 * s);
  canvas.drawLine(
      g(86, 32),
      g(98, 20),
      Paint()
        ..color = dark.color
        ..strokeWidth = 3 * s);
  final legP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2 * s
    ..strokeCap = StrokeCap.round;
  for (final dx in [-1, 1]) {
    for (final y in [46.0, 56.0, 66.0]) {
      canvas.drawLine(g(50 + dx * 26, y), g(50 + dx * 40, y + 10), legP);
    }
  }
  canvas.drawCircle(g(40, 48), 3.4 * s, white);
  canvas.drawCircle(g(41, 48), 1.6 * s, black);
  canvas.drawCircle(g(60, 48), 3.4 * s, white);
  canvas.drawCircle(g(61, 48), 1.6 * s, black);
}

void _snailLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black,
    {bool banded = false}) {
  final shellCenter = g(52, 44);
  for (var i = 5; i >= 1; i--) {
    final r = 8.0 * i;
    final rect = Rect.fromCircle(center: shellCenter, radius: r * s);
    final paint = Paint()..color = banded && i.isEven ? dark.color : body.color;
    canvas.drawArc(rect, -pi * 0.7, pi * 1.7, true, paint);
  }
  canvas.drawOval(Rect.fromPoints(g(14, 60), g(40, 76)), dark);
  canvas.drawCircle(g(18, 62), 2.6 * s, white);
  canvas.drawCircle(g(19, 62), 1.2 * s, black);
}

void _abaloneLike(
    Canvas canvas, _G g, double s, Paint body, Paint dark, Paint light) {
  canvas.drawOval(Rect.fromPoints(g(10, 26), g(90, 74)), body);
  final shine = Paint()..color = light.color.withValues(alpha: 0.7);
  canvas.drawOval(Rect.fromPoints(g(46, 34), g(78, 54)), shine);
  final holeP = Paint()..color = dark.color;
  for (final x in [34.0, 48.0, 62.0, 76.0]) {
    canvas.drawCircle(g(x, 40), 2.4 * s, holeP);
  }
}

void _oysterLike(
    Canvas canvas, _G g, double s, Paint body, Paint dark, Paint white) {
  canvas.drawPath(
      _poly(g, [
        [10, 55],
        [50, 20],
        [90, 55],
        [50, 62]
      ]),
      dark);
  canvas.drawPath(
      _poly(g, [
        [12, 58],
        [50, 66],
        [88, 58],
        [50, 90]
      ]),
      body);
  canvas.drawCircle(g(50, 58), 8 * s, white);
}

void _starLike(Canvas canvas, _G g, double s, Paint body, Paint dark) {
  const spikes = 5;
  final path = Path();
  for (var i = 0; i < spikes * 2; i++) {
    final angle = (pi / spikes) * i - pi / 2;
    final r = i.isEven ? 40.0 : 16.0;
    final p = g(50 + cos(angle) * r, 50 + sin(angle) * r);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  canvas.drawPath(path, body);
  final dotP = Paint()..color = dark.color;
  canvas.drawCircle(g(50, 50), 2.6 * s, dotP);
  canvas.drawCircle(g(42, 40), 1.6 * s, dotP);
  canvas.drawCircle(g(60, 44), 1.6 * s, dotP);
}

void _coralLike(
    Canvas canvas, _G g, double s, Paint body, Paint dark, Paint light) {
  final branchP = Paint()
    ..color = body.color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final branches = [
    [50.0, 92.0, 30.0, 30.0, 20.0, 8.0],
    [50.0, 92.0, 50.0, 20.0, 50.0, 4.0],
    [50.0, 92.0, 70.0, 30.0, 80.0, 8.0],
    [50.0, 92.0, 38.0, 46.0, 22.0, 30.0],
    [50.0, 92.0, 62.0, 46.0, 78.0, 30.0],
  ];
  for (final b in branches) {
    final path = Path()
      ..moveTo(g(b[0], b[1]).dx, g(b[0], b[1]).dy)
      ..quadraticBezierTo(g(b[2], b[3]).dx, g(b[2], b[3]).dy, g(b[4], b[5]).dx,
          g(b[4], b[5]).dy);
    canvas.drawPath(path, branchP..strokeWidth = 7 * s);
    canvas.drawCircle(g(b[4], b[5]), 5 * s, Paint()..color = light.color);
  }
}

void _seaweedLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    {required bool drooping}) {
  final ribbons = drooping
      ? [
          [30.0, 90.0, 20.0, 55.0, 40.0, 35.0],
          [50.0, 92.0, 45.0, 60.0, 55.0, 30.0],
          [70.0, 90.0, 78.0, 55.0, 60.0, 32.0],
        ]
      : [
          [30.0, 92.0, 15.0, 55.0, 30.0, 10.0],
          [50.0, 94.0, 60.0, 55.0, 45.0, 6.0],
          [70.0, 92.0, 82.0, 55.0, 68.0, 12.0],
        ];
  for (final r in ribbons) {
    final path = Path()
      ..moveTo(g(r[0], r[1]).dx, g(r[0], r[1]).dy)
      ..quadraticBezierTo(g(r[2], r[3]).dx, g(r[2], r[3]).dy, g(r[4], r[5]).dx,
          g(r[4], r[5]).dy);
    canvas.drawPath(
        path,
        Paint()
          ..color = body.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * s
          ..strokeCap = StrokeCap.round);
  }
}

void _squidLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  // Thân hình chóp — đỉnh NHỌN ở trên (đặc trưng đầu mực), xòe rộng dần
  // xuống dưới rồi thu lại ở đáy.
  canvas.drawPath(
      _poly(g, [
        [50, 2],
        [76, 20],
        [84, 46],
        [50, 60],
        [16, 46],
        [24, 20]
      ]),
      body);
  canvas.drawPath(
      _poly(g, [
        [24, 22],
        [6, 34],
        [26, 38]
      ]),
      dark);
  canvas.drawPath(
      _poly(g, [
        [76, 22],
        [94, 34],
        [74, 38]
      ]),
      dark);
  final tentP = Paint()
    ..color = body.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.6 * s
    ..strokeCap = StrokeCap.round;
  for (final x in [32.0, 42.0, 58.0, 68.0]) {
    final path = Path()
      ..moveTo(g(x, 58).dx, g(x, 58).dy)
      ..quadraticBezierTo(
          g(x - 4, 78).dx, g(x - 4, 78).dy, g(x + 2, 96).dx, g(x + 2, 96).dy);
    canvas.drawPath(path, tentP);
  }
  canvas.drawCircle(g(40, 32), 3.4 * s, white);
  canvas.drawCircle(g(41, 32), 1.6 * s, black);
  canvas.drawCircle(g(60, 32), 3.4 * s, white);
  canvas.drawCircle(g(61, 32), 1.6 * s, black);
}

void _octopusLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  canvas.drawOval(Rect.fromPoints(g(16, 12), g(84, 62)), body);
  final tentP = Paint()
    ..color = body.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8 * s
    ..strokeCap = StrokeCap.round;
  for (final x in [20.0, 36.0, 50.0, 64.0, 80.0]) {
    final path = Path()
      ..moveTo(g(x, 54).dx, g(x, 54).dy)
      ..quadraticBezierTo(
          g(x - 6, 76).dx, g(x - 6, 76).dy, g(x + 6, 94).dx, g(x + 6, 94).dy);
    canvas.drawPath(path, tentP);
  }
  canvas.drawCircle(g(36, 32), 8 * s, white);
  canvas.drawCircle(g(37, 33), 3.6 * s, black);
  canvas.drawCircle(g(64, 32), 8 * s, white);
  canvas.drawCircle(g(65, 33), 3.6 * s, black);
}

// ============================================================
// NHÓM RÙA / HẢI CẨU / CHIM CÁNH CỤT / SỨA
// ============================================================

void _turtleLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint light, Paint white, Paint black) {
  canvas.drawOval(Rect.fromPoints(g(18, 22), g(82, 74)), dark);
  canvas.drawOval(Rect.fromPoints(g(24, 28), g(76, 68)), body);
  final lineP = Paint()
    ..color = light.color.withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6 * s;
  canvas.drawLine(g(30, 40), g(70, 40), lineP);
  canvas.drawLine(g(30, 56), g(70, 56), lineP);
  canvas.drawLine(g(50, 30), g(50, 66), lineP);
  canvas.drawOval(Rect.fromPoints(g(4, 40), g(22, 56)), dark);
  canvas.drawOval(Rect.fromPoints(g(20, 12), g(40, 26)), dark);
  canvas.drawOval(Rect.fromPoints(g(60, 12), g(80, 26)), dark);
  canvas.drawOval(Rect.fromPoints(g(20, 70), g(40, 84)), dark);
  canvas.drawOval(Rect.fromPoints(g(60, 70), g(80, 84)), dark);
  canvas.drawCircle(g(10, 46), 2 * s, white);
}

void _sealLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint white, Paint black) {
  final path = Path()
    ..moveTo(g(20, 40).dx, g(20, 40).dy)
    ..quadraticBezierTo(g(20, 16).dx, g(20, 16).dy, g(48, 16).dx, g(48, 16).dy)
    ..quadraticBezierTo(g(84, 20).dx, g(84, 20).dy, g(88, 52).dx, g(88, 52).dy)
    ..quadraticBezierTo(g(90, 78).dx, g(90, 78).dy, g(58, 82).dx, g(58, 82).dy)
    ..quadraticBezierTo(g(22, 84).dx, g(22, 84).dy, g(20, 60).dx, g(20, 60).dy)
    ..close();
  canvas.drawPath(path, body);
  canvas.drawPath(
      _poly(g, [
        [60, 78],
        [78, 90],
        [56, 92]
      ]),
      dark);
  canvas.drawCircle(g(34, 34), 4 * s, white);
  canvas.drawCircle(g(35, 34), 2 * s, black);
  final whiskerP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2 * s;
  canvas.drawLine(g(18, 42), g(2, 38), whiskerP);
  canvas.drawLine(g(18, 46), g(2, 48), whiskerP);
}

void _penguinLike(
    Canvas canvas, _G g, double s, Paint body, Paint white, Paint black) {
  canvas.drawOval(
      Rect.fromPoints(g(24, 12), g(76, 90)), Paint()..color = Colors.black87);
  canvas.drawOval(Rect.fromPoints(g(32, 34), g(68, 84)), white);
  canvas.drawPath(
      _poly(g, [
        [6, 40],
        [26, 32],
        [22, 56]
      ]),
      Paint()..color = Colors.black87);
  canvas.drawPath(
      _poly(g, [
        [94, 40],
        [74, 32],
        [78, 56]
      ]),
      Paint()..color = Colors.black87);
  // Mỏ và chân — luôn dùng màu cam cố định (không dùng màu riêng của loài)
  // để không bao giờ bị lẫn vào đầu đen dù species.color là tông tối.
  final beakP = Paint()..color = const Color(0xFFFFA726);
  canvas.drawPath(
      _poly(g, [
        [42, 34],
        [50, 24],
        [58, 34]
      ]),
      beakP);
  canvas.drawOval(Rect.fromPoints(g(30, 86), g(46, 96)), beakP);
  canvas.drawOval(Rect.fromPoints(g(54, 86), g(70, 96)), beakP);
  // Mắt — tròng TRẮNG + con ngươi đen, để luôn nổi rõ trên nền đầu đen
  // (trước đó vẽ thẳng chấm đen nên bị chìm mất, coi như không có mắt).
  canvas.drawCircle(g(42, 24), 3.6 * s, white);
  canvas.drawCircle(g(42.6, 24), 1.7 * s, black);
  canvas.drawCircle(g(58, 24), 3.6 * s, white);
  canvas.drawCircle(g(58.6, 24), 1.7 * s, black);
}

void _jellyfishLike(
    Canvas canvas, _G g, double s, Paint body, Paint light, Paint white) {
  final domeRect = Rect.fromPoints(g(20, 20), g(80, 56));
  canvas.drawArc(domeRect, pi, pi, true, body);
  final tentP = Paint()
    ..color = body.color.withValues(alpha: 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2 * s
    ..strokeCap = StrokeCap.round;
  for (final x in [30.0, 42.0, 50.0, 58.0, 70.0]) {
    final path = Path()..moveTo(g(x, 50).dx, g(x, 50).dy);
    var prevX = x, prevY = 50.0;
    for (var seg = 1; seg <= 3; seg++) {
      final ny = 50.0 + seg * 15;
      final nx = x + (seg.isOdd ? 8 : -8);
      path.quadraticBezierTo(g(prevX, prevY + 6).dx, g(prevX, prevY + 6).dy,
          g(nx, ny).dx, g(nx, ny).dy);
      prevX = nx;
      prevY = ny;
    }
    canvas.drawPath(path, tentP);
  }
  final glowP = Paint()..color = white.color.withValues(alpha: 0.6);
  canvas.drawCircle(g(38, 34), 2.6 * s, glowP);
  canvas.drawCircle(g(58, 30), 2 * s, glowP);
  canvas.drawCircle(g(48, 40), 2.2 * s, glowP);
}

// ============================================================
// HUYỀN THOẠI (mang tính biểu tượng, đơn giản — không vẽ người thật)
// ============================================================

void _mermaidLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint light, Paint white, Paint black) {
  // Đuôi cá (thân dưới) — biểu tượng cho "nàng tiên cá", giữ tối giản.
  canvas.drawPath(
      _poly(g, [
        [50, 30],
        [26, 70],
        [50, 96],
        [74, 70]
      ]),
      body);
  final finP = Paint()..color = dark.color;
  canvas.drawPath(
      _poly(g, [
        [30, 80],
        [10, 96],
        [38, 92]
      ]),
      finP);
  canvas.drawPath(
      _poly(g, [
        [70, 80],
        [90, 96],
        [62, 92]
      ]),
      finP);
  // Vỏ sò nhỏ (áo)
  final shellP = Paint()..color = light.color;
  canvas.drawOval(Rect.fromPoints(g(34, 16), g(48, 30)), shellP);
  canvas.drawOval(Rect.fromPoints(g(52, 16), g(66, 30)), shellP);
  // Tóc gợn sóng
  final hairP = Paint()..color = dark.color;
  canvas.drawOval(Rect.fromPoints(g(30, 2), g(70, 24)), hairP);
}

void _dragonLike(Canvas canvas, _G g, double s, Paint body, Paint dark,
    Paint light, Paint white, Paint black) {
  // Thân UỐN LƯỢN mượt mà (không còn là chuỗi hình tròn trông như sâu bọ),
  // đầu to bên trái, thon nhỏ dần về phía đuôi bên phải.
  final centerline = [
    [22.0, 54.0, 12.0],
    [38.0, 38.0, 12.0],
    [56.0, 32.0, 10.0],
    [72.0, 38.0, 8.0],
    [86.0, 50.0, 5.5],
    [96.0, 62.0, 3.0],
  ];
  canvas.drawPath(_taperedSnake(g, s, centerline), body);

  // Gai nhọn dọc sống lưng — nhọn và dứt khoát hơn bản cũ.
  final spikeP = Paint()..color = dark.color;
  final spikeAt = [
    [32.0, 40.0],
    [48.0, 32.0],
    [64.0, 34.0],
    [78.0, 42.0],
  ];
  for (final p in spikeAt) {
    canvas.drawPath(
        _poly(g, [
          [p[0] - 5, p[1]],
          [p[0], p[1] - 15],
          [p[0] + 5, p[1]],
        ]),
        spikeP);
  }

  // Đầu rồng to, có 2 sừng nhọn.
  canvas.drawOval(Rect.fromPoints(g(2, 38), g(32, 66)), body);
  canvas.drawPath(
      _poly(g, [
        [8, 40],
        [2, 22],
        [18, 38]
      ]),
      dark);
  canvas.drawPath(
      _poly(g, [
        [18, 38],
        [18, 20],
        [28, 36]
      ]),
      dark);

  // Miệng mở với răng nanh nhỏ — dữ tợn hơn hẳn khuôn mặt tròn trước đó.
  canvas.drawPath(
      _poly(g, [
        [0, 56],
        [16, 66],
        [2, 70]
      ]),
      dark);
  canvas.drawPath(
      _poly(g, [
        [2, 58],
        [7, 63],
        [2, 64]
      ]),
      white);

  // Mắt dữ tợn + chân mày xếch lên.
  canvas.drawOval(Rect.fromPoints(g(12, 46), g(20, 54)), white);
  canvas.drawCircle(g(17, 50), 2.2 * s, black);
  final browP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6 * s
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(g(10, 42), g(22, 38), browP);
}

void _crownLike(
    Canvas canvas, _G g, double s, Paint body, Paint dark, Paint light) {
  canvas.drawPath(
      _poly(g, [
        [14, 80],
        [14, 46],
        [30, 62],
        [50, 30],
        [70, 62],
        [86, 46],
        [86, 80],
      ]),
      body);
  final jewelP = Paint()..color = light.color;
  canvas.drawCircle(g(50, 44), 4 * s, jewelP);
  canvas.drawCircle(g(30, 58), 2.6 * s, jewelP);
  canvas.drawCircle(g(70, 58), 2.6 * s, jewelP);
  canvas.drawRect(Rect.fromPoints(g(14, 80), g(86, 90)), dark);
}

void _chestLike(
    Canvas canvas, _G g, double s, Paint body, Paint dark, Paint light) {
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromPoints(g(12, 42), g(88, 84)), Radius.circular(6 * s)),
      body);
  canvas.drawArc(Rect.fromPoints(g(12, 20), g(88, 58)), pi, pi, true, dark);
  canvas.drawRect(
      Rect.fromPoints(g(44, 40), g(56, 56)), Paint()..color = light.color);
  final coinP = Paint()..color = light.color;
  canvas.drawCircle(g(22, 88), 4 * s, coinP);
  canvas.drawCircle(g(34, 92), 3.4 * s, coinP);
  canvas.drawCircle(g(70, 90), 3.6 * s, coinP);
}

// ============================================================
// RÁC (câu hụt) — vẫn dễ thương, màu đơn giản.
// ============================================================

void _bootLike(Canvas canvas, _G g, double s, Paint body, Paint dark) {
  canvas.drawPath(
      _poly(g, [
        [30, 10],
        [58, 10],
        [58, 56],
        [86, 64],
        [86, 88],
        [16, 88],
        [16, 60],
        [30, 56],
      ]),
      body);
  final tearP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2 * s;
  final tear = Path()
    ..moveTo(g(36, 20).dx, g(36, 20).dy)
    ..lineTo(g(46, 30).dx, g(46, 30).dy)
    ..lineTo(g(38, 40).dx, g(38, 40).dy)
    ..lineTo(g(50, 50).dx, g(50, 50).dy);
  canvas.drawPath(tear, tearP);
}

void _canLike(Canvas canvas, _G g, double s, Paint body, Paint dark) {
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromPoints(g(28, 12), g(72, 88)), Radius.circular(6 * s)),
      body);
  canvas.drawOval(Rect.fromPoints(g(28, 6), g(72, 18)), dark);
  final speckP = Paint()..color = dark.color.withValues(alpha: 0.7);
  canvas.drawCircle(g(40, 40), 2.4 * s, speckP);
  canvas.drawCircle(g(58, 56), 2 * s, speckP);
  canvas.drawCircle(g(46, 68), 2.6 * s, speckP);
  final dentP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6 * s;
  canvas.drawLine(g(30, 50), g(70, 46), dentP);
}

void _bottleLike(
    Canvas canvas, _G g, double s, Paint body, Paint dark, Paint light) {
  canvas.drawRect(Rect.fromPoints(g(42, 6), g(58, 26)), body);
  canvas.drawPath(
      _poly(g, [
        [42, 26],
        [58, 26],
        [72, 44],
        [72, 90],
        [28, 90],
        [28, 44]
      ]),
      body);
  final crackP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8 * s;
  final crack = Path()
    ..moveTo(g(36, 50).dx, g(36, 50).dy)
    ..lineTo(g(48, 60).dx, g(48, 60).dy)
    ..lineTo(g(40, 70).dx, g(40, 70).dy)
    ..lineTo(g(54, 82).dx, g(54, 82).dy);
  canvas.drawPath(crack, crackP);
  canvas.drawOval(Rect.fromPoints(g(46, 34), g(56, 50)),
      Paint()..color = light.color.withValues(alpha: 0.6));
}

void _sandalLike(Canvas canvas, _G g, double s, Paint body, Paint dark) {
  canvas.drawOval(Rect.fromPoints(g(14, 24), g(70, 92)), body);
  final strapP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4 * s
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(g(42, 40), g(30, 12), strapP);
  canvas.drawLine(g(42, 40), g(54, 12), strapP);
  canvas.drawLine(g(42, 40), g(42, 60), strapP);
}

void _bagLike(Canvas canvas, _G g, double s, Paint body, Paint dark) {
  final path = Path()
    ..moveTo(g(24, 24).dx, g(24, 24).dy)
    ..lineTo(g(76, 24).dx, g(76, 24).dy)
    ..quadraticBezierTo(g(88, 60).dx, g(88, 60).dy, g(70, 90).dx, g(70, 90).dy)
    ..quadraticBezierTo(g(50, 76).dx, g(50, 76).dy, g(30, 90).dx, g(30, 90).dy)
    ..quadraticBezierTo(g(12, 60).dx, g(12, 60).dy, g(24, 24).dx, g(24, 24).dy)
    ..close();
  canvas.drawPath(path, Paint()..color = body.color.withValues(alpha: 0.75));
  final handleP = Paint()
    ..color = dark.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3 * s;
  canvas.drawArc(Rect.fromPoints(g(38, 8), g(62, 28)), pi, pi, false, handleP);
}
