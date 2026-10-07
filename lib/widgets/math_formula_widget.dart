import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../theme/app_theme.dart';

class MathFormulaWidget extends StatelessWidget {
  final String tex;
  final bool display;

  const MathFormulaWidget({
    super.key,
    required this.tex,
    this.display = true,
  });

  @override
  Widget build(BuildContext context) {
    if (tex.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.11)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          tex,
          mathStyle: display ? MathStyle.display : MathStyle.text,
          textStyle: const TextStyle(
            fontSize: 20,
            color: AppColors.textPrimary,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

class MathFormulaList extends StatelessWidget {
  final List<String> formulas;

  const MathFormulaList({super.key, required this.formulas});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          formulas.map((formula) => MathFormulaWidget(tex: formula)).toList(),
    );
  }
}
