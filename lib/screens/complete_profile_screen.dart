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

/// Hiện ĐÚNG 1 LẦN cho tài khoản học sinh được tạo TRƯỚC khi app có Khối
/// lớp/Tỉnh-Xã/Trường (SplashScreen kiểm tra `currentStudent.grade == null`
/// để quyết định có hiện màn này hay không) — sau khi nhập xong, `grade`
/// sẽ luôn khác null nên màn này không bao giờ hiện lại, kể cả những lần
/// đăng nhập sau.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _schoolController = TextEditingController(
      text: context.read<AuthProvider>().currentStudent?.schoolName ?? '');

  int? _grade;
  List<Province> _provinces = [];
  List<Ward> _wards = [];
  Province? _selectedProvince;
  Ward? _selectedWard;
  bool _loadingProvinces = true;
  bool _loadingWards = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _loadingProvinces = true;
      _error = null;
    });
    try {
      final provinces = await LocationService.getProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        // Nếu học sinh đã có sẵn tỉnh (đăng ký từ trước khi có Khối lớp
        // nhưng SAU khi đã có Tỉnh/Xã) thì chọn sẵn, đỡ phải chọn lại.
        final existingCode =
            context.read<AuthProvider>().currentStudent?.provinceCode;
        if (existingCode != null) {
          for (final p in provinces) {
            if (p.code == existingCode) _selectedProvince = p;
          }
        }
      });
      if (_selectedProvince != null)
        await _onProvinceChanged(_selectedProvince, keepWard: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          'Không tải được danh sách Tỉnh/Thành. Kiểm tra kết nối mạng và thử lại.');
    } finally {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _onProvinceChanged(Province? province,
      {bool keepWard = false}) async {
    setState(() {
      _selectedProvince = province;
      if (!keepWard) {
        _selectedWard = null;
        _schoolController.clear();
      }
      _wards = [];
    });
    if (province == null) return;
    setState(() => _loadingWards = true);
    try {
      final wards = await LocationService.getWards(province.code);
      if (!mounted) return;
      setState(() {
        _wards = wards;
        final existingWardCode =
            context.read<AuthProvider>().currentStudent?.wardCode;
        if (keepWard && existingWardCode != null) {
          for (final w in wards) {
            if (w.code == existingWardCode) _selectedWard = w;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          'Không tải được danh sách Xã/Phường. Kiểm tra kết nối mạng và thử lại.');
    } finally {
      if (mounted) setState(() => _loadingWards = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null || _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Tỉnh/Thành và Xã/Phường')),
      );
      return;
    }
    if (_grade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn khối lớp')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final schoolName = _schoolController.text.trim();

    final success = await auth.completeStudentProfile(
      grade: _grade!,
      provinceCode: _selectedProvince!.code,
      provinceName: _selectedProvince!.name,
      wardCode: _selectedWard!.code,
      wardName: _selectedWard!.name,
      schoolName: schoolName.isEmpty ? null : schoolName,
    );

    if (success && schoolName.isNotEmpty) {
      SchoolService.ensureSchoolExists(
        name: schoolName,
        provinceCode: _selectedProvince!.code,
        provinceName: _selectedProvince!.name,
        wardCode: _selectedWard!.code,
        wardName: _selectedWard!.name,
      ).catchError((_) {});
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Có lỗi xảy ra')),
      );
    }
    // Không cần tự điều hướng: SplashScreen theo dõi currentStudent.grade
    // và sẽ tự chuyển sang trang chính ngay khi grade hết null.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(
        title: const Text('Bổ sung thông tin'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'PetMath vừa có thêm Khối lớp, Tỉnh/Thành và Trường để '
                  'bài tập và bảng xếp hạng phù hợp hơn với bạn. Vui lòng '
                  'nhập 1 lần — lần sau đăng nhập sẽ không hỏi lại.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                const Text('Khối lớp',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _grade,
                  decoration:  InputDecoration(
                    labelText: tr('Lớp mấy?'),
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: Curriculum.gradeDropdownItems(),
                  onChanged: (v) => setState(() => _grade = v),
                  validator: (v) => v == null ? 'Vui lòng chọn khối lớp' : null,
                ),
                const SizedBox(height: 20),
                const Text('Địa chỉ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_error != null) ...[
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12)),
                  TextButton(
                      onPressed: _loadProvinces, child: const Text('Thử lại')),
                ],
                _loadingProvinces
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    : DropdownButtonFormField<Province>(
                        initialValue: _selectedProvince,
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
                    initialValue: _selectedWard,
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
                TextFormField(
                  controller: _schoolController,
                  decoration:  InputDecoration(
                    labelText: tr('Trường (không bắt buộc)'),
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Hoàn tất'),
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
