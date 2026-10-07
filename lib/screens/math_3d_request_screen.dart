import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';

import '../theme/app_theme.dart';
import '../widgets/math_3d_visuals.dart';

class Math3DRequestScreen extends StatefulWidget {
  const Math3DRequestScreen({super.key});

  @override
  State<Math3DRequestScreen> createState() => _Math3DRequestScreenState();
}

class _Math3DRequestScreenState extends State<Math3DRequestScreen> {
  final _promptController = TextEditingController();
  Parametric3DShape? _shapeOverride;
  Math3DConfig? _config;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _draw() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() =>
          _error = 'Hãy dán hoặc nhập nguyên văn đề bài hình học cần vẽ.');
      return;
    }
    setState(() {
      _error = null;
      _config = Math3DConfig.fromPrompt(
        prompt,
        overrideShape: _shapeOverride,
      );
    });
  }

  void _clear() {
    setState(() {
      _promptController.clear();
      _shapeOverride = null;
      _config = null;
      _error = null;
    });
  }

  String _shapeLabel(Parametric3DShape shape) => Math3DConfig.shapeLabel(shape);

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.light, 
      appBar: AppBar(
        title: const Text('Vẽ hình 3D theo bài toán'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            color: AppColors.primary.withValues(alpha: 0.07),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Dán nguyên văn đề bài vào ô dưới đây. PetMath sẽ tự nhận diện hình, điểm, mặt phẳng, quan hệ vuông góc/song song và các số đo nếu đề có nêu. Không cần điền từng tham số riêng lẻ.',
                style: TextStyle(height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _promptController,
            maxLines: 7,
            textInputAction: TextInputAction.newline,
            decoration:  InputDecoration(
              labelText: tr('Dán hoặc nhập nguyên văn đề bài'),
              hintText:
                  tr('Ví dụ: Cho hình chóp S.ABCD có đáy ABCD là hình chữ nhật và SA vuông góc (ABCD)...'),
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 72),
                child: Icon(Icons.description_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.only(bottom: 4),
            leading: const Icon(Icons.tune),
            title: const Text('Tùy chọn nâng cao — không bắt buộc'),
            subtitle: Text(
              _shapeOverride == null
                  ? 'Đang tự nhận diện loại hình từ đề'
                  : 'Đang ưu tiên: ${_shapeLabel(_shapeOverride!)}',
            ),
            children: [
              DropdownButtonFormField<Parametric3DShape>(
                value: _shapeOverride,
                isExpanded: true,
                decoration:  InputDecoration(
                  labelText:
                      tr('Ghi đè loại hình nếu hệ thống nhận diện chưa đúng'),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                hint: const Text('Tự nhận diện từ đề bài'),
                items: [
                  const DropdownMenuItem<Parametric3DShape>(
                    value: null,
                    child: Text('Tự nhận diện từ đề bài'),
                  ),
                  ...Parametric3DShape.values.map(
                    (shape) => DropdownMenuItem(
                      value: shape,
                      child: Text(_shapeLabel(shape)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _shapeOverride = value),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kích thước không cần nhập riêng. Nếu đề chỉ cho quan hệ hình học mà không cho số đo, hệ thống sẽ dùng tỉ lệ minh họa và ghi rõ điều đó dưới hình.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12, height: 1.35),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _draw,
            icon: const Icon(Icons.view_in_ar),
            label: const Text('Phân tích đề và vẽ hình 3D'),
          ),
          if (_config != null || _error != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.refresh),
                label: const Text('Nhập đề khác'),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          if (_config != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mô hình theo đề bài',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                  label: Text(Math3DConfig.shapeLabel(_config!.shape)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Parametric3DCard(config: _config!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
