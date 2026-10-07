import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import '../theme/app_theme.dart';

enum MathVisualType {
  sets,
  numberLine,
  parabola,
  vector,
  probability,
  trigonometry,
  sequence,
  limit,
  spaceGeometry,
  statistics,
  derivative,
  integral,
  coordinate3d,
  complexPlane,
  randomVariable,
}

class MathVisualConfig {
  final MathVisualType type;
  final String title;
  final String caption;

  const MathVisualConfig({
    required this.type,
    required this.title,
    required this.caption,
  });
}

class MathVisualCatalog {
  static const Map<String, MathVisualConfig> _items = {
    'g10-menh-de-tap-hop': MathVisualConfig(
      type: MathVisualType.sets,
      title: 'Giao, hợp và phần bù của tập hợp',
      caption:
          'Vùng giao là phần tử thuộc đồng thời hai tập; hợp là toàn bộ vùng của A và B.',
    ),
    'g10-bat-phuong-trinh': MathVisualConfig(
      type: MathVisualType.numberLine,
      title: 'Trục số và khoảng nghiệm',
      caption:
          'Nghiệm bất phương trình được biểu diễn bằng khoảng trên trục số; đầu mút mở/đóng thể hiện điều kiện lấy hay không lấy.',
    ),
    'g10-ham-so-do-thi': MathVisualConfig(
      type: MathVisualType.parabola,
      title: 'Parabol, đỉnh và trục đối xứng',
      caption:
          'Đồ thị cho thấy đỉnh I, trục đối xứng và chiều mở của hàm số bậc hai.',
    ),
    'g10-vecto-toa-do': MathVisualConfig(
      type: MathVisualType.vector,
      title: 'Vectơ trên mặt phẳng tọa độ',
      caption:
          'Vectơ được đọc từ điểm đầu đến điểm cuối; tích vô hướng giúp nhận biết vuông góc.',
    ),
    'g10-xac-suat-co-ban': MathVisualConfig(
      type: MathVisualType.probability,
      title: 'Không gian mẫu và xác suất',
      caption:
          'Các nhánh kết quả tạo thành không gian mẫu; xác suất là tỉ lệ kết quả thuận lợi trên tổng số kết quả.',
    ),
    'g11-luong-giac': MathVisualConfig(
      type: MathVisualType.trigonometry,
      title: 'Đường tròn lượng giác',
      caption:
          'Góc, sin và cos được đọc từ tọa độ điểm trên đường tròn đơn vị.',
    ),
    'g11-day-so-cap-so': MathVisualConfig(
      type: MathVisualType.sequence,
      title: 'Dãy số và cấp số',
      caption:
          'Các điểm biểu diễn số hạng; cấp số cộng tạo bước tăng đều còn cấp số nhân tạo tỉ lệ đều.',
    ),
    'g11-gioi-han-lien-tuc': MathVisualConfig(
      type: MathVisualType.limit,
      title: 'Giới hạn khi x tiến đến a',
      caption:
          'Giá trị của hàm tiến gần L khi x tiến gần a; hình minh họa giúp quan sát xu hướng thay vì chỉ thế số.',
    ),
    'g11-hinh-hoc-khong-gian': MathVisualConfig(
      type: MathVisualType.spaceGeometry,
      title: 'Mặt phẳng, đường vuông góc và hình chiếu',
      caption:
          'Đường vuông góc là đoạn ngắn nhất nối điểm với mặt phẳng; hình chiếu nằm tại chân vuông góc.',
    ),
    'g11-thong-ke-xac-suat': MathVisualConfig(
      type: MathVisualType.statistics,
      title: 'Phân bố dữ liệu và độ phân tán',
      caption:
          'Cột dữ liệu, trung bình và độ phân tán giúp đọc nhanh đặc trưng của mẫu số liệu.',
    ),
    'g12-ung-dung-dao-ham': MathVisualConfig(
      type: MathVisualType.derivative,
      title: 'Đạo hàm, đơn điệu và cực trị',
      caption:
          'Dấu của đạo hàm quyết định chiều biến thiên; tiếp tuyến cho biết hệ số góc tại điểm đang xét.',
    ),
    'g12-nguyen-ham-tich-phan': MathVisualConfig(
      type: MathVisualType.integral,
      title: 'Diện tích giới hạn bởi đồ thị',
      caption:
          'Tích phân xác định được minh họa bằng vùng diện tích dưới đường cong trên đoạn [a;b].',
    ),
    'g12-hinh-hoc-toa-do': MathVisualConfig(
      type: MathVisualType.coordinate3d,
      title: 'Mặt phẳng và mặt cầu trong không gian Oxyz',
      caption:
          'Ba trục tọa độ, vectơ pháp tuyến và mặt cầu giúp hình dung phương trình trong không gian.',
    ),
    'g12-so-phuc': MathVisualConfig(
      type: MathVisualType.complexPlane,
      title: 'Biểu diễn số phức trên mặt phẳng phức',
      caption:
          'Số phức z=a+bi tương ứng với điểm M(a;b); môđun là khoảng cách từ O đến M.',
    ),
    'g12-xac-suat-ung-dung': MathVisualConfig(
      type: MathVisualType.randomVariable,
      title: 'Biến ngẫu nhiên và phân bố xác suất',
      caption:
          'Mỗi giá trị của biến ngẫu nhiên đi kèm một xác suất; tổng các xác suất bằng 1.',
    ),
  };

  static MathVisualConfig? forLesson(String lessonId) => _items[lessonId];
}

class MathVisualCard extends StatelessWidget {
  final MathVisualConfig config;

  const MathVisualCard({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 230,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6FF),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          child: CustomPaint(
            painter: _MathVisualPainter(config.type),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 10),
        Text(config.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 4),
        Text(config.caption,
            style: const TextStyle(
                color: AppColors.textSecondary, height: 1.4, fontSize: 12)),
      ],
    );
  }
}

class _MathVisualPainter extends CustomPainter {
  final MathVisualType type;
  _MathVisualPainter(this.type);

  final _ink = const Color(0xFF29264F);
  final _purple = const Color(0xFF6758DA);
  final _gold = const Color(0xFFFFB84D);
  final _teal = const Color(0xFF17B897);
  final _red = const Color(0xFFE56B6F);
  final _blue = const Color(0xFF5FA8E8);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF7F6FF), BlendMode.srcOver);
    switch (type) {
      case MathVisualType.sets:
        _drawSets(canvas, size);
        break;
      case MathVisualType.numberLine:
        _drawNumberLine(canvas, size);
        break;
      case MathVisualType.parabola:
        _drawGraph(canvas, size, (x) => 0.45 * x * x - 0.7, 'y=f(x)', 'I');
        break;
      case MathVisualType.vector:
        _drawVector(canvas, size);
        break;
      case MathVisualType.probability:
        _drawProbability(canvas, size);
        break;
      case MathVisualType.trigonometry:
        _drawUnitCircle(canvas, size);
        break;
      case MathVisualType.sequence:
        _drawSequence(canvas, size);
        break;
      case MathVisualType.limit:
        _drawGraph(canvas, size, (x) => 1.5 + 0.7 / (x + 2.6), 'f(x)', 'L');
        break;
      case MathVisualType.spaceGeometry:
        _drawSpaceGeometry(canvas, size);
        break;
      case MathVisualType.statistics:
        _drawStatistics(canvas, size);
        break;
      case MathVisualType.derivative:
        _drawDerivative(canvas, size);
        break;
      case MathVisualType.integral:
        _drawIntegral(canvas, size);
        break;
      case MathVisualType.coordinate3d:
        _drawCoordinate3d(canvas, size);
        break;
      case MathVisualType.complexPlane:
        _drawComplexPlane(canvas, size);
        break;
      case MathVisualType.randomVariable:
        _drawRandomVariable(canvas, size);
        break;
    }
  }

  void _drawAxes(Canvas c, Size s, {double y0 = 0.64}) {
    final p = Paint()
      ..color = _ink.withValues(alpha: 0.5)
      ..strokeWidth = 1.4;
    final ox = Offset(34, s.height * y0);
    c.drawLine(ox, Offset(s.width - 24, ox.dy), p);
    c.drawLine(Offset(ox.dx, 18), Offset(ox.dx, s.height - 22), p);
    c.drawLine(Offset(s.width - 24, ox.dy), Offset(s.width - 31, ox.dy - 4), p);
    c.drawLine(Offset(s.width - 24, ox.dy), Offset(s.width - 31, ox.dy + 4), p);
    c.drawLine(Offset(ox.dx, 18), Offset(ox.dx - 4, 26), p);
    c.drawLine(Offset(ox.dx, 18), Offset(ox.dx + 4, 26), p);
    _label(c, 'x', Offset(s.width - 22, ox.dy + 6), _ink);
    _label(c, 'y', Offset(ox.dx + 6, 16), _ink);
  }

  void _drawGraph(
      Canvas c, Size s, double Function(double) f, String name, String marker) {
    _drawAxes(c, s);
    final path = Path();
    for (var i = 0; i <= 160; i++) {
      final x = -3.2 + i * 6.4 / 160;
      final px = 34 + (x + 3.2) / 6.4 * (s.width - 62);
      final py = s.height * 0.64 - f(x) * 42;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    c.drawPath(
        path,
        Paint()
          ..color = _purple
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
    _label(c, name, Offset(s.width - 75, 47), _purple, bold: true);
    if (marker == 'I') {
      c.drawCircle(Offset(s.width * .5, s.height * .64 - (-.7) * 42), 5,
          Paint()..color = _gold);
      _label(c, 'I', Offset(s.width * .5 + 7, s.height * .64 - (-.7) * 42 - 18),
          _gold,
          bold: true);
      c.drawLine(
          Offset(s.width * .5, s.height * .64 - (-.7) * 42),
          Offset(s.width * .5, s.height * .64),
          Paint()..color = _gold.withValues(alpha: .5));
    } else {
      final y = s.height * .64 - 1.5 * 42;
      c.drawLine(Offset(34, y), Offset(s.width - 30, y),
          Paint()..color = _teal.withValues(alpha: .6));
      _label(c, 'y=L', Offset(s.width - 70, y - 18), _teal, bold: true);
    }
  }

  void _drawSets(Canvas c, Size s) {
    final a = Paint()..color = _purple.withValues(alpha: .23);
    final b = Paint()..color = _teal.withValues(alpha: .25);
    c.drawCircle(Offset(s.width * .42, s.height * .52), 67, a);
    c.drawCircle(Offset(s.width * .58, s.height * .52), 67, b);
    _label(c, 'A', Offset(s.width * .28, s.height * .36), _purple, bold: true);
    _label(c, 'B', Offset(s.width * .68, s.height * .36), _teal, bold: true);
    _label(c, 'A ∩ B', Offset(s.width * .46, s.height * .53), _ink, bold: true);
    _label(c, 'A ∪ B', Offset(s.width * .43, s.height * .82), _ink);
  }

  void _drawNumberLine(Canvas c, Size s) {
    final y = s.height * .55;
    final p = Paint()
      ..color = _ink
      ..strokeWidth = 2;
    c.drawLine(Offset(38, y), Offset(s.width - 30, y), p);
    for (var i = 0; i <= 6; i++) {
      final x = 55 + i * (s.width - 110) / 6;
      c.drawLine(Offset(x, y - 7), Offset(x, y + 7), p);
      _label(c, '${i - 3}', Offset(x - 4, y + 12), _ink);
    }
    final interval = Paint()
      ..color = _purple
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(55, y), Offset(s.width * .66, y), interval);
    c.drawCircle(Offset(s.width * .66, y), 7, Paint()..color = Colors.white);
    c.drawCircle(
        Offset(s.width * .66, y),
        7,
        Paint()
          ..color = _purple
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    _label(c, 'khoảng nghiệm', Offset(s.width * .36, y - 32), _purple,
        bold: true);
  }

  void _drawVector(Canvas c, Size s) {
    _drawAxes(c, s, y0: .7);
    final a = Offset(s.width * .22, s.height * .66);
    final b = Offset(s.width * .72, s.height * .28);
    final p = Paint()
      ..color = _purple
      ..strokeWidth = 3;
    c.drawLine(a, b, p);
    c.drawLine(b, Offset(b.dx - 14, b.dy + 4), p);
    c.drawLine(b, Offset(b.dx - 5, b.dy + 14), p);
    c.drawCircle(a, 5, Paint()..color = _gold);
    c.drawCircle(b, 5, Paint()..color = _teal);
    _label(c, 'A', a + const Offset(-18, 4), _gold, bold: true);
    _label(c, 'B', b + const Offset(8, -5), _teal, bold: true);
    _label(c, 'AB', Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 - 20), _purple,
        bold: true);
  }

  void _drawProbability(Canvas c, Size s) {
    final base = s.height * .78;
    final xs = [0.25, 0.42, 0.59, 0.76];
    final hs = [0.26, 0.55, 0.38, 0.7];
    for (var i = 0; i < xs.length; i++) {
      final rect = Rect.fromLTWH(s.width * xs[i], base - s.height * hs[i] * .55,
          30, s.height * hs[i] * .55);
      c.drawRect(rect, Paint()..color = [_purple, _teal, _gold, _blue][i]);
      _label(c, 'ω${i + 1}', Offset(rect.left + 5, base + 8), _ink);
    }
    c.drawLine(
        Offset(35, base),
        Offset(s.width - 25, base),
        Paint()
          ..color = _ink
          ..strokeWidth = 1.5);
    _label(c, 'P(A)=thuận lợi / Ω', Offset(42, 28), _purple, bold: true);
  }

  void _drawUnitCircle(Canvas c, Size s) {
    final center = Offset(s.width * .47, s.height * .54);
    final r = 72.0;
    c.drawCircle(
        center,
        r,
        Paint()
          ..color = _purple.withValues(alpha: .05)
          ..style = PaintingStyle.fill);
    c.drawCircle(
        center,
        r,
        Paint()
          ..color = _purple
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    c.drawLine(
        Offset(center.dx - r - 15, center.dy),
        Offset(center.dx + r + 15, center.dy),
        Paint()..color = _ink.withValues(alpha: .5));
    c.drawLine(
        Offset(center.dx, center.dy - r - 15),
        Offset(center.dx, center.dy + r + 15),
        Paint()..color = _ink.withValues(alpha: .5));
    final point = Offset(center.dx + r * .72, center.dy - r * .69);
    c.drawLine(
        center,
        point,
        Paint()
          ..color = _teal
          ..strokeWidth = 3);
    c.drawCircle(point, 5, Paint()..color = _gold);
    _label(c, 'M(cos x; sin x)', point + const Offset(6, -22), _teal,
        bold: true);
    _label(c, 'O', center + const Offset(-16, 5), _ink, bold: true);
  }

  void _drawSequence(Canvas c, Size s) {
    _drawAxes(c, s, y0: .78);
    for (var i = 0; i < 7; i++) {
      final x = 55 + i * 52.0;
      final y = s.height * .72 - i * 18.0;
      c.drawCircle(Offset(x, y), 5, Paint()..color = _purple);
      _label(c, 'u${i + 1}', Offset(x - 8, y - 22), _ink);
    }
    _label(c, 'uₙ = u₁ + (n−1)d', Offset(50, 25), _purple, bold: true);
  }

  void _drawSpaceGeometry(Canvas c, Size s) {
    final p = Paint()
      ..color = _purple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final a = Offset(s.width * .22, s.height * .68);
    final b = Offset(s.width * .69, s.height * .68);
    final d = Offset(s.width * .82, s.height * .44);
    final e = Offset(s.width * .35, s.height * .44);
    c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(d.dx, d.dy)
          ..lineTo(e.dx, e.dy)
          ..close(),
        p);
    c.drawLine(a, Offset(a.dx + 42, a.dy - 115), p);
    c.drawLine(b, Offset(b.dx + 42, b.dy - 115), p);
    c.drawLine(d, Offset(d.dx + 42, d.dy - 115), p);
    c.drawLine(e, Offset(e.dx + 42, e.dy - 115), p);
    c.drawPath(
        Path()
          ..moveTo(a.dx + 42, a.dy - 115)
          ..lineTo(b.dx + 42, b.dy - 115)
          ..lineTo(d.dx + 42, d.dy - 115)
          ..lineTo(e.dx + 42, e.dy - 115)
          ..close(),
        p);
    final foot = Offset(s.width * .57, s.height * .68);
    final top = Offset(s.width * .62, s.height * .25);
    c.drawLine(
        top,
        foot,
        Paint()
          ..color = _red
          ..strokeWidth = 3);
    _label(c, 'd ⟂ (P)', Offset(top.dx + 6, top.dy + 12), _red, bold: true);
    _label(c, '(P)', Offset(s.width * .5, s.height * .78), _purple, bold: true);
  }

  void _drawStatistics(Canvas c, Size s) {
    final base = s.height * .78;
    final values = [0.34, 0.58, 0.42, 0.75, 0.5, 0.3];
    for (var i = 0; i < values.length; i++) {
      final h = values[i] * 110;
      final rect = Rect.fromLTWH(52 + i * 42.0, base - h, 25, h);
      c.drawRect(rect, Paint()..color = i == 3 ? _gold : _blue);
    }
    c.drawLine(
        Offset(36, base),
        Offset(s.width - 25, base),
        Paint()
          ..color = _ink
          ..strokeWidth = 1.5);
    c.drawLine(
        Offset(36, base - 62),
        Offset(s.width - 25, base - 62),
        Paint()
          ..color = _red.withValues(alpha: .7)
          ..strokeWidth = 2);
    _label(c, 'x̄', Offset(s.width - 48, base - 78), _red, bold: true);
    _label(c, 'mẫu số liệu', Offset(44, 24), _purple, bold: true);
  }

  void _drawDerivative(Canvas c, Size s) {
    _drawAxes(c, s);
    final path = Path();
    for (var i = 0; i <= 160; i++) {
      final x = -3.2 + i * 6.4 / 160;
      final px = 34 + (x + 3.2) / 6.4 * (s.width - 62);
      final py = s.height * .64 - (0.18 * x * x * x - 0.8 * x) * 28;
      if (i == 0)
        path.moveTo(px, py);
      else
        path.lineTo(px, py);
    }
    c.drawPath(
        path,
        Paint()
          ..color = _purple
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
    final x0 = s.width * .5;
    c.drawLine(
        Offset(x0, 28),
        Offset(x0, s.height - 28),
        Paint()
          ..color = _gold
          ..strokeWidth = 2);
    _label(c, 'f′(x)>0', Offset(70, 35), _teal, bold: true);
    _label(c, 'f′(x)<0', Offset(s.width - 120, 35), _red, bold: true);
    _label(c, 'cực trị', Offset(x0 + 8, 70), _gold, bold: true);
  }

  void _drawIntegral(Canvas c, Size s) {
    _drawAxes(c, s, y0: .72);
    final path = Path()..moveTo(40, s.height * .72);
    for (var i = 0; i <= 150; i++) {
      final x = i / 150 * (s.width - 80);
      final y = s.height * .72 - (0.004 * (x - 120) * (x - 120) + 30);
      path.lineTo(40 + x, y);
    }
    path.lineTo(s.width - 40, s.height * .72);
    path.close();
    c.drawPath(path, Paint()..color = _teal.withValues(alpha: .23));
    final curve = Path()..moveTo(40, s.height * .72);
    for (var i = 0; i <= 150; i++) {
      final x = i / 150 * (s.width - 80);
      final y = s.height * .72 - (0.004 * (x - 120) * (x - 120) + 30);
      curve.lineTo(40 + x, y);
    }
    c.drawPath(
        curve,
        Paint()
          ..color = _purple
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
    _label(c, 'S = ∫ₐᵇ f(x)dx', Offset(48, 24), _purple, bold: true);
    _label(c, 'a', Offset(45, s.height * .75), _ink);
    _label(c, 'b', Offset(s.width - 44, s.height * .75), _ink);
  }

  void _drawCoordinate3d(Canvas c, Size s) {
    final axis = Paint()
      ..color = _purple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final o = Offset(s.width * .34, s.height * .72);
    final xEnd = Offset(s.width * .88, o.dy);
    final yEnd = Offset(s.width * .10, s.height * .43);
    final zEnd = Offset(o.dx, s.height * .16);

    // Ba trục có cùng gốc O; Oy được vẽ xiên theo quy ước phối cảnh.
    c.drawLine(o, xEnd, axis);
    c.drawLine(o, yEnd, axis);
    c.drawLine(o, zEnd, axis);
    _label(c, 'O', o + const Offset(-16, 5), _ink, bold: true);
    _label(c, 'Ox', xEnd + const Offset(-6, 5), _ink, bold: true);
    _label(c, 'Oy', yEnd + const Offset(-6, -4), _ink, bold: true);
    _label(c, 'Oz', zEnd + const Offset(8, -2), _ink, bold: true);

    // Mặt cầu: đường bao tròn, thêm xích đạo và kinh tuyến để không bị
    // hiểu nhầm là một đường tròn phẳng.
    final center = Offset(s.width * .61, s.height * .47);
    const radius = 55.0;
    final sphereFill = Paint()
      ..color = _teal.withValues(alpha: .11)
      ..style = PaintingStyle.fill;
    final sphereLine = Paint()
      ..color = _teal
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    c.drawCircle(center, radius, sphereFill);
    c.drawCircle(center, radius, sphereLine);

    final equator = Path()
      ..addOval(Rect.fromCenter(center: center, width: radius * 2, height: 28));
    c.drawPath(equator, sphereLine);
    final meridian = Path()
      ..addOval(Rect.fromCenter(center: center, width: 30, height: radius * 2));
    c.drawPath(meridian, sphereLine);

    final hidden = Paint()
      ..color = _teal.withValues(alpha: .42)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final lowerEquator = Path()
      ..addOval(Rect.fromCenter(
          center: center + const Offset(0, 4),
          width: radius * 1.65,
          height: 18));
    _drawDashedPath(c, lowerEquator, hidden);

    // Tâm C và điểm M nằm trên mặt cầu; đoạn CM chính là bán kính R.
    final pointM = center + const Offset(39, -33);
    c.drawLine(
        center,
        pointM,
        Paint()
          ..color = _gold
          ..strokeWidth = 3);
    c.drawCircle(center, 4, Paint()..color = _purple);
    c.drawCircle(pointM, 5, Paint()..color = _gold);
    _label(c, 'C(a;b;c)', center + const Offset(-22, 61), _purple, bold: true);
    _label(c, 'M(x;y;z)', pointM + const Offset(8, -18), _ink, bold: true);
    _label(
        c,
        'CM = R',
        Offset(
            (center.dx + pointM.dx) / 2 + 5, (center.dy + pointM.dy) / 2 - 12),
        _gold,
        bold: true);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + 5 < metric.length ? distance + 5 : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 10;
      }
    }
  }

  void _drawComplexPlane(Canvas c, Size s) {
    final center = Offset(s.width * .42, s.height * .6);
    final p = Paint()
      ..color = _ink.withValues(alpha: .55)
      ..strokeWidth = 1.4;
    c.drawLine(Offset(35, center.dy), Offset(s.width - 25, center.dy), p);
    c.drawLine(Offset(center.dx, 20), Offset(center.dx, s.height - 25), p);
    final z = Offset(center.dx + 78, center.dy - 62);
    c.drawLine(
        center,
        z,
        Paint()
          ..color = _purple
          ..strokeWidth = 3);
    c.drawCircle(z, 6, Paint()..color = _gold);
    _label(c, 'Re', Offset(s.width - 45, center.dy + 6), _ink, bold: true);
    _label(c, 'Im', Offset(center.dx + 7, 18), _ink, bold: true);
    _label(c, 'M(a;b)', z + const Offset(8, -18), _purple, bold: true);
    _label(c, '|z|',
        Offset((center.dx + z.dx) / 2, (center.dy + z.dy) / 2 - 16), _gold,
        bold: true);
  }

  void _drawRandomVariable(Canvas c, Size s) {
    final base = s.height * .78;
    final ps = [0.15, 0.35, 0.25, 0.25];
    for (var i = 0; i < ps.length; i++) {
      final h = ps[i] * 230;
      final rect = Rect.fromLTWH(50 + i * 48.0, base - h, 30, h);
      c.drawRect(rect, Paint()..color = [_purple, _teal, _gold, _blue][i]);
      _label(c, 'x${i + 1}', Offset(rect.left + 6, base + 8), _ink);
      _label(c, 'p${i + 1}', Offset(rect.left + 6, rect.top - 18), _ink);
    }
    c.drawLine(
        Offset(35, base),
        Offset(s.width - 25, base),
        Paint()
          ..color = _ink
          ..strokeWidth = 1.5);
    _label(c, 'Σpᵢ = 1', Offset(s.width - 82, 28), _purple, bold: true);
  }

  void _label(Canvas canvas, String text, Offset offset, Color color,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 180);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MathVisualPainter oldDelegate) =>
      oldDelegate.type != type;
}
