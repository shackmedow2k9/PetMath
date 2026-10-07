import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/curriculum.dart';
import '../services/location_service.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _schoolController = TextEditingController();

  RegisterRole _role = RegisterRole.student;
  int? _grade; // Khối lớp (1-12) — chỉ áp dụng cho Học sinh

  // Tỉnh/Thành + Xã/Phường lấy trực tiếp từ API hành chính Việt Nam thật
  // (2 cấp: Tỉnh -> Xã/Phường, áp dụng từ 01/07/2025) — không gõ tay để
  // tránh sai sót và tự cập nhật khi có thay đổi địa giới.
  List<Province> _provinces = [];
  List<Ward> _wards = [];
  Province? _selectedProvince;
  Ward? _selectedWard;
  bool _loadingProvinces = true;
  bool _loadingWards = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _loadingProvinces = true;
      _locationError = null;
    });
    try {
      final provinces = await LocationService.getProvinces();
      if (!mounted) return;
      setState(() => _provinces = provinces);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationError =
          'Không tải được danh sách Tỉnh/Thành. Kiểm tra kết nối mạng và thử lại.');
    } finally {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _onProvinceChanged(Province? province) async {
    setState(() {
      _selectedProvince = province;
      _selectedWard = null;
      _wards = [];
      _schoolController.clear();
    });
    if (province == null) return;
    setState(() => _loadingWards = true);
    try {
      final wards = await LocationService.getWards(province.code);
      if (!mounted) return;
      setState(() => _wards = wards);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationError =
          'Không tải được danh sách Xã/Phường. Kiểm tra kết nối mạng và thử lại.');
    } finally {
      if (mounted) setState(() => _loadingWards = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null || _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Tỉnh/Thành và Xã/Phường')),
      );
      return;
    }
    if (_role == RegisterRole.student && _grade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn khối lớp')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final schoolName = _schoolController.text.trim();

    final success = await auth.register(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role,
      provinceCode: _selectedProvince!.code,
      provinceName: _selectedProvince!.name,
      wardCode: _selectedWard!.code,
      wardName: _selectedWard!.name,
      schoolName: schoolName.isEmpty ? null : schoolName,
      grade: _role == RegisterRole.student ? _grade : null,
    );

    // Lưu lại tên trường (nếu có) để những người đăng ký sau cùng
    // xã/phường thấy ngay trong gợi ý — không chặn luồng đăng ký nếu lỗi.
    if (success && schoolName.isNotEmpty) {
      SchoolService.ensureSchoolExists(
        name: schoolName,
        provinceCode: _selectedProvince!.code,
        provinceName: _selectedProvince!.name,
        wardCode: _selectedWard!.code,
        wardName: _selectedWard!.name,
      ).catchError((_) {});
    }

    // LƯU Ý: RegisterScreen được Navigator.push từ LoginScreen (không giống
    // LoginScreen — màn hình được SplashScreen hiển thị TRỰC TIẾP tại chỗ
    // dựa theo auth.status). Vì vậy dù SplashScreen phía dưới đã tự build
    // lại đúng màn hình (Chọn thú cưng/Trang giáo viên) ngay khi đăng ký
    // thành công, RegisterScreen vẫn còn đè lên trên nên người dùng không
    // thấy gì thay đổi — PHẢI pop() để lộ lại SplashScreen bên dưới.
    if (success && mounted) {
      Navigator.of(context).pop();
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Đăng ký thất bại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 12),
                Text('Bắt đầu hành trình nuôi thú cưng',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 24),

                // ----- Vai trò -----
                const Text('Bạn là',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<RegisterRole>(
                  segments: const [
                    ButtonSegment(
                      value: RegisterRole.student,
                      label: Text('Học sinh'),
                      icon: Icon(Icons.backpack_outlined),
                    ),
                    ButtonSegment(
                      value: RegisterRole.teacher,
                      label: Text('Giáo viên'),
                      icon: Icon(Icons.school_outlined),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() {
                    _role = s.first;
                    if (_role == RegisterRole.teacher) _grade = null;
                  }),
                ),
                if (_role == RegisterRole.student) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _grade,
                    decoration:  InputDecoration(
                      labelText: tr('Khối lớp'),
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: Curriculum.gradeDropdownItems(),
                    onChanged: (v) => setState(() => _grade = v),
                    validator: (v) =>
                        v == null ? 'Vui lòng chọn khối lớp' : null,
                  ),
                ],
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  decoration:  InputDecoration(
                    labelText: tr('Họ và tên'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập họ tên'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email không hợp lệ'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration:  InputDecoration(
                    labelText: tr('Mật khẩu'),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null,
                ),
                const SizedBox(height: 20),

                // ----- Địa chỉ -----
                const Text('Địa chỉ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_locationError != null) ...[
                  Text(_locationError!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12)),
                  TextButton(
                    onPressed: _loadProvinces,
                    child: const Text('Thử tải lại'),
                  ),
                ],
                _loadingProvinces
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    : DropdownButtonFormField<Province>(
                        value: _selectedProvince,
                        isExpanded: true,
                        decoration:  InputDecoration(
                          labelText: tr('Tỉnh / Thành phố'),
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                        items: _provinces
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p.name)))
                            .toList(),
                        onChanged: _onProvinceChanged,
                        validator: (v) =>
                            v == null ? 'Vui lòng chọn Tỉnh/Thành' : null,
                      ),
                const SizedBox(height: 16),
                if (_loadingWards)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  )
                else
                  DropdownButtonFormField<Ward>(
                    value: _selectedWard,
                    isExpanded: true,
                    decoration:  InputDecoration(
                      labelText: tr('Xã / Phường'),
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    items: _wards
                        .map((w) =>
                            DropdownMenuItem(value: w, child: Text(w.name)))
                        .toList(),
                    onChanged: _selectedProvince == null
                        ? null
                        : (w) => setState(() => _selectedWard = w),
                    validator: (v) =>
                        v == null ? 'Vui lòng chọn Xã/Phường' : null,
                  ),
                const SizedBox(height: 16),

                // ----- Trường: gõ + gợi ý tự học từ cộng đồng cùng xã -----
                _SchoolField(
                  controller: _schoolController,
                  ward: _selectedWard,
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleRegister,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Đăng ký'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô nhập tên trường: gợi ý các trường đã có người nhập trước trong cùng
/// xã/phường (lưu trên Firestore), nhưng vẫn cho gõ tự do nếu trường
/// chưa có trong gợi ý — vì không có danh sách đầy đủ mọi trường học
/// Việt Nam để hiển thị sẵn.
class _SchoolField extends StatefulWidget {
  final TextEditingController controller;
  final Ward? ward;
  const _SchoolField({required this.controller, required this.ward});

  @override
  State<_SchoolField> createState() => _SchoolFieldState();
}

class _SchoolFieldState extends State<_SchoolField> {
  List<String> _suggestions = [];
  final FocusNode _focusNode = FocusNode(); // 👈 thêm mới

  @override
  void didUpdateWidget(covariant _SchoolField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ward?.code != widget.ward?.code) {
      widget.controller.clear();
      _loadSuggestions();
    }
  }

  @override
  void dispose() {
    // 👈 thêm mới
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    if (widget.ward == null) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final list = await SchoolService.getSchoolSuggestions(widget.ward!.code);
      if (mounted) setState(() => _suggestions = list);
    } catch (_) {
      // Không chặn đăng ký nếu tải gợi ý thất bại — cứ để học sinh gõ tay.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ward == null) {
      return TextFormField(
        controller: widget.controller,
        enabled: false,
        decoration:  InputDecoration(
          labelText: tr('Trường (chọn Xã/Phường trước)'),
          prefixIcon: Icon(Icons.apartment_outlined),
        ),
      );
    }

    return Autocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode, // 👈 thêm mới
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return _suggestions;
        return _suggestions.where((s) =>
            s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (s) => widget.controller.text = s,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration:  InputDecoration(
            labelText: tr('Trường (gõ tên trường của bạn)'),
            helperText:
                tr('Chưa thấy trường của bạn? Cứ gõ tên trường mới vào đây.'),
            helperMaxLines: 2,
            prefixIcon: Icon(Icons.apartment_outlined),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: options
                    .map((o) => ListTile(
                          title: Text(o),
                          onTap: () => onSelected(o),
                        ))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
