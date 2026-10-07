import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model rút gọn cho 1 Tỉnh/Thành phố.
class Province {
  final int code;
  final String name;
  const Province({required this.code, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) =>
      Province(code: json['code'] as int, name: json['name'] as String);
}

/// Model rút gọn cho 1 Xã/Phường.
class Ward {
  final int code;
  final String name;
  final int provinceCode;
  const Ward({required this.code, required this.name, required this.provinceCode});

  factory Ward.fromJson(Map<String, dynamic> json) => Ward(
        code: json['code'] as int,
        name: json['name'] as String,
        provinceCode: json['province_code'] as int,
      );
}

/// Lấy dữ liệu Tỉnh/Thành phố và Xã/Phường thật của Việt Nam từ API mở
/// chính thức (provinces.open-api.vn — nguồn Tổng cục Thống kê), theo cơ
/// cấu hành chính 2 cấp áp dụng từ 01/07/2025 (Tỉnh -> Xã/Phường, không
/// còn cấp Huyện). Nhờ vậy danh sách luôn đầy đủ 34 tỉnh/thành và toàn bộ
/// xã/phường thật, không cần tự gõ tay (dễ sai & khó cập nhật khi sáp nhập).
class LocationService {
  static const _baseUrl = 'https://provinces.open-api.vn/api/v2';

  static List<Province>? _provinceCache;
  static final Map<int, List<Ward>> _wardCache = {};

  /// Lấy danh sách toàn bộ 34 tỉnh/thành phố.
  static Future<List<Province>> getProvinces() async {
    if (_provinceCache != null) return _provinceCache!;
    final res = await http.get(Uri.parse('$_baseUrl/p/'));
    if (res.statusCode != 200) {
      throw Exception('Không tải được danh sách tỉnh/thành (${res.statusCode})');
    }
    final List data = jsonDecode(utf8.decode(res.bodyBytes));
    final provinces = data.map((e) => Province.fromJson(e)).toList();
    _provinceCache = provinces;
    return provinces;
  }

  /// Lấy danh sách xã/phường thuộc 1 tỉnh/thành (theo [provinceCode]).
  static Future<List<Ward>> getWards(int provinceCode) async {
    if (_wardCache.containsKey(provinceCode)) return _wardCache[provinceCode]!;
    final res =
        await http.get(Uri.parse('$_baseUrl/p/$provinceCode?depth=2'));
    if (res.statusCode != 200) {
      throw Exception('Không tải được danh sách xã/phường (${res.statusCode})');
    }
    final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
    final List wardsJson = data['wards'] ?? [];
    final wards = wardsJson.map((e) => Ward.fromJson(e)).toList();
    _wardCache[provinceCode] = wards;
    return wards;
  }
}
