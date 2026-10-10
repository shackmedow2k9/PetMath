import 'dart:math';
import 'package:flutter/material.dart';

/// Thời tiết ngoài trời của Nhà pet.
enum HouseWeather { sunny, cloudy, rain }

extension HouseWeatherInfo on HouseWeather {
  String get emoji => switch (this) {
        HouseWeather.sunny => '☀️',
        HouseWeather.cloudy => '☁️',
        HouseWeather.rain => '🌧️',
      };

  String get label => switch (this) {
        HouseWeather.sunny => 'Nắng đẹp',
        HouseWeather.cloudy => 'Nhiều mây',
        HouseWeather.rain => 'Trời mưa',
      };

  /// Thời tiết đổi mỗi 2 phút thật (~6 giờ game), chọn theo hạt giống nên
  /// mọi thiết bị trong cùng khoảng thời gian thấy cùng 1 kiểu trời.
  static HouseWeather now() {
    final block = DateTime.now().millisecondsSinceEpoch ~/ 120000;
    final roll = Random(block * 7919 + 13).nextInt(100);
    if (roll < 50) return HouseWeather.sunny;
    if (roll < 75) return HouseWeather.cloudy;
    return HouseWeather.rain;
  }
}

/// Lớp phủ khí quyển cho khung cảnh phòng: đổi tông màu theo giờ game
/// (bình minh, ban ngày, hoàng hôn, đêm), sao nhấp nháy ban đêm, nắng ban
/// ngày, mây trôi và mưa rơi. Không nhận chạm (đặt trong IgnorePointer).
class HouseAmbience extends StatelessWidget {
  /// Giờ game dạng số thực, 0.0–24.0.
  final double hour;
  final HouseWeather weather;

  /// Animation lặp 0→1 để mây trôi, sao nhấp nháy, mưa rơi.
  final Animation<double> tick;

  const HouseAmbience({
    super.key,
    required this.hour,
    required this.weather,
    required this.tick,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _AmbiencePainter(hour: hour, weather: weather, tick: tick),
        ),
      ),
    );
  }
}

class _Seed {
  final double a;
  final double b;
  final double c;
  const _Seed(this.a, this.b, this.c);
}

class _AmbiencePainter extends CustomPainter {
  final double hour;
  final HouseWeather weather;
  final Animation<double> tick;

  _AmbiencePainter({
    required this.hour,
    required this.weather,
    required this.tick,
  }) : super(repaint: tick);

  static final List<_Seed> _stars = _seeds(30, 1);
  static final List<_Seed> _drops = _seeds(70, 2);
  static final List<_Seed> _clouds = _seeds(4, 3);

  static List<_Seed> _seeds(int n, int seed) {
    final r = Random(seed);
    return List.generate(
        n, (_) => _Seed(r.nextDouble(), r.nextDouble(), r.nextDouble()));
  }

  // (giờ, màu) — nội suy tuyến tính giữa 2 mốc liền kề.
  static const List<(double, Color)> _tints = [
    (0.0, Color(0x400D1B52)),
    (5.0, Color(0x330D1B52)),
    (6.5, Color(0x1FFF9A5C)),
    (8.0, Color(0x00FFFFFF)),
    (16.5, Color(0x00FFFFFF)),
    (18.0, Color(0x2BFF7A45)),
    (19.5, Color(0x380D1B52)),
    (24.0, Color(0x400D1B52)),
  ];

  Color _tint() {
    final h = hour.clamp(0.0, 24.0);
    for (var i = 0; i < _tints.length - 1; i++) {
      final (h0, c0) = _tints[i];
      final (h1, c1) = _tints[i + 1];
      if (h >= h0 && h <= h1) {
        final t = h1 == h0 ? 0.0 : (h - h0) / (h1 - h0);
        return Color.lerp(c0, c1, t) ?? c0;
      }
    }
    return _tints.last.$2;
  }

  bool get _isNight => hour >= 19 || hour < 5;
  bool get _isDay => hour >= 7 && hour < 17.5;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tick.value;
    final w = size.width;
    final h = size.height;

    // 1) Tông màu theo giờ + xám nhẹ khi âm u/mưa.
    canvas.drawRect(Offset.zero & size, Paint()..color = _tint());
    if (weather != HouseWeather.sunny) {
      final gray = weather == HouseWeather.rain ? 0x2E : 0x16;
      canvas.drawRect(Offset.zero & size,
          Paint()..color = Color.fromARGB(gray, 70, 90, 110));
    }

    // 2) Sao nhấp nháy ban đêm (trời quang/ít mây).
    if (_isNight && weather != HouseWeather.rain) {
      for (final s in _stars) {
        final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin((t + s.c) * 2 * pi * 2));
        canvas.drawCircle(
          Offset(s.a * w, s.b * h * 0.35),
          0.8 + s.c * 1.4,
          Paint()..color = Colors.white.withValues(alpha: twinkle * 0.85),
        );
      }
    }

    // 3) Quầng nắng ban ngày khi trời nắng.
    if (_isDay && weather == HouseWeather.sunny) {
      final center = Offset(w * 0.18, h * 0.04);
      canvas.drawCircle(
        center,
        w * 0.55,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0x55FFE9A8),
            const Color(0x00FFE9A8),
          ]).createShader(Rect.fromCircle(center: center, radius: w * 0.55)),
      );
    }

    // 4) Mây trôi (cloudy + rain).
    if (weather != HouseWeather.sunny) {
      for (final c in _clouds) {
        final speed = 0.5 + c.c;
        final x = ((c.a + t * speed * 0.6) % 1.0) * (w + 160) - 80;
        final y = h * (0.04 + c.b * 0.16);
        final p = Paint()
          ..color = Colors.white.withValues(
              alpha: weather == HouseWeather.rain ? 0.22 : 0.3);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 120, height: 34), p);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(x + 30, y - 12), width: 80, height: 34),
            p);
      }
    }

    // 5) Mưa rơi.
    if (weather == HouseWeather.rain) {
      final p = Paint()
        ..color = const Color(0xFFBFD8FF).withValues(alpha: 0.55)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (final d in _drops) {
        final speed = 1.6 + d.c * 1.2;
        final y = ((d.b + t * speed) % 1.0) * (h + 40) - 20;
        final x = d.a * (w + 40) - 20 + y * 0.12;
        canvas.drawLine(Offset(x, y), Offset(x - 3, y + 14), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbiencePainter old) =>
      old.hour != hour || old.weather != weather;
}
