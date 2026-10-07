import 'package:flutter/material.dart' hide Text;

import '../l10n/tr.dart';
import '../models/class_model.dart';
import '../services/curriculum.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'tr_text.dart';

/// Thẻ lớp học dùng chung (danh sách lớp + Hồ sơ giáo viên). Mọi loại lớp đều
/// dùng ĐÚNG bộ icon của lớp 11a3 trong ảnh minh họa: ô vuông xanh mint có
/// icon mũ cử nhân + sách, icon sinh viên đội mũ ở bên phải. Chỉ màu nền thẻ
/// đổi theo thứ tự (xanh dương → cam → xanh lá).
class ClassCard extends StatelessWidget {
  final ClassModel klass;
  final int colorIndex;
  final VoidCallback onTap;

  const ClassCard({
    super.key,
    required this.klass,
    required this.colorIndex,
    required this.onTap,
  });

  static const _tints = [
    (bg: Color(0xFFEAF0FF), border: Color(0xFFC9D6F5), accent: Color(0xFF5A6BD6)),
    (bg: Color(0xFFFFF0E2), border: Color(0xFFF6D2AE), accent: Color(0xFFE59A3E)),
    (bg: Color(0xFFE6F8EE), border: Color(0xFFBFE8D0), accent: Color(0xFF1FA463)),
  ];

  @override
  Widget build(BuildContext context) {
    final tint = _tints[colorIndex % _tints.length];
    return Material(
      color: tint.bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tint.border),
          ),
          child: Row(
            children: [
              // Icon lớp — giống hệt lớp 11a3 trong ảnh minh họa.
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6F2E3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset('assets/ui/ic_book_cap.png',
                    fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(klass.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.vpn_key_rounded,
                              size: 13, color: tint.accent),
                          const SizedBox(width: 4),
                          Text(klass.joinCode,
                              style: TextStyle(
                                  color: tint.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1)),
                        ]),
                        if (klass.grade != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tint.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(Curriculum.gradeLabel(klass.grade!),
                                style: TextStyle(
                                    color: tint.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              FutureBuilder<int>(
                future: FirestoreService().countClassStudents(klass.id),
                builder: (context, snap) {
                  final count = snap.data;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/ui/ic_students.png',
                          width: 26, height: 26),
                      const SizedBox(width: 4),
                      Text(count == null ? '…' : '$count HS',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ]),
                  );
                },
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
