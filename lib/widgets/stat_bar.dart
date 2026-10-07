import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../theme/app_theme.dart';

/// Thanh hiển thị 1 chỉ số của pet: HP, Happiness, Hunger, Energy.
class StatBar extends StatelessWidget {
  final String emoji;
  final String label;
  final int value; // 0-100
  final Color color;
  // Cho phép dùng trên nền tối (ảnh nền) mà vẫn đọc rõ chữ.
  final Color labelColor;
  final Color valueColor;

  const StatBar({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    this.labelColor = AppColors.textSecondary,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child:
                Text(label, style: TextStyle(fontSize: 13, color: labelColor)),
          ),
          Expanded(
            child: LinearPercentIndicator(
              lineHeight: 10,
              percent: value / 100,
              progressColor: color,
              backgroundColor: color.withValues(alpha: 0.15),
              barRadius: const Radius.circular(8),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: valueColor)),
          ),
        ],
      ),
    );
  }
}
