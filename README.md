# PetMath — Learn · Play · Grow

Khung dự án Flutter + Firebase cho ứng dụng học tập kết hợp nuôi thú cưng, dựa trên tài liệu đặc tả gốc.

## Đã hoàn thành trong bản khởi tạo này

**Kiến trúc & luồng dữ liệu**
- `lib/models/` — `StudentModel`, `PetModel` (HP/Happiness/Hunger/Energy/EXP/Level), `ItemModel`
- `lib/services/` — `AuthService` (đăng ký/đăng nhập 4 cấp quyền), `FirestoreService` (pet, streak, coin, cửa hàng)
- `lib/providers/` — `AuthProvider`, `PetProvider` (state management bằng Provider)
- `lib/theme/` — bảng màu & typography (Google Fonts Baloo2, tươi vui cho học sinh)

**Màn hình đã dựng (13/100 theo tài liệu)**
1. Splash Screen — điều hướng theo trạng thái đăng nhập
2. Login Screen
3. Register Screen
4. Pet Selection Screen — chọn 1 trong 7 loài thú cưng
5. Pet Home Screen — màn hình trung tâm: chỉ số pet, EXP ring, coin/gem/streak, 4 lối vào
6. **Subject Selection Screen** — chọn môn học (9 môn theo đặc tả)
7. **Exam Screen** — làm bài trắc nghiệm, có feedback đúng/sai ngay lập tức
8. **Exam Result Screen** — điểm số + confetti khi làm tốt (≥70%)
9. **Shop Screen** — mua đồ theo danh mục (Áo/Mũ/Kính/Giày/Cánh/Nhà...), tự mặc cho pet sau khi mua
10. **Mini Game Hub** — trung tâm chọn mini game
11. **Lucky Spin** — vòng quay may mắn nhận Coin ngẫu nhiên (canvas vẽ tay, animation quay thật)
12. **Guess Picture** — đoán từ qua emoji, 5 câu/lượt
13. **Leaderboard Screen** — BXH theo Lớp/Trường/Toàn quốc, 3 tab, huy chương 🥇🥈🥉

**Logic nghiệp vụ đã cài đặt**
- Vòng lặp động lực: làm đúng câu → +EXP → pet lên level (không giới hạn, độ khó lên level tăng dần 15%/lần)
- Streak học mỗi ngày: 3 ngày → 100 Coin, 7 ngày → 500 Coin (mốc 30 ngày mở pet hiếm — đã có chỗ để cắm logic)
- Pet **không bao giờ "chết"** — chỉ số có sàn tối thiểu 10, đúng như tinh thần "tránh áp lực cho học sinh" trong tài liệu
- Giao dịch mua đồ trong cửa hàng dùng Firestore transaction (an toàn khi nhiều request cùng lúc)
- `firestore.rules` — phân quyền cơ bản theo 4 cấp: Admin / Nhà sản xuất / Giáo viên / Học sinh

## Cách chạy dự án

```bash
# 1. Cài Flutter SDK (nếu chưa có): https://docs.flutter.dev/get-started/install

# 2. Cài dependencies
cd edupet
flutter pub get

# 3. Cấu hình Firebase cho project của bạn (bắt buộc trước khi chạy)
dart pub global activate flutterfire_cli
flutterfire configure
# Lệnh này sẽ ghi đè lib/firebase_options.dart với API key thật

# 4. Chạy thử
flutter run
```

Trên Firebase Console, cần bật thủ công:
- **Authentication** → Email/Password
- **Firestore Database** → tạo ở chế độ production, rồi deploy `firestore.rules`
- **Storage** (để lưu ảnh pet, item, avatar)

## Cấu trúc thư mục

```
lib/
├── main.dart                    # Entry point, khởi tạo Firebase + Provider
├── firebase_options.dart        # MẪU - sẽ bị ghi đè bởi flutterfire configure
├── models/
│   ├── student_model.dart
│   ├── pet_model.dart
│   └── item_model.dart
├── services/
│   ├── auth_service.dart
│   └── firestore_service.dart
├── providers/
│   ├── auth_provider.dart
│   └── pet_provider.dart
├── theme/
│   └── app_theme.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── pet_selection_screen.dart
│   └── pet_home_screen.dart
└── widgets/
    └── stat_bar.dart
```

## Việc tiếp theo (theo đúng thứ tự nên làm)

1. **Cổng Giáo viên** — Dashboard lớp học, giao bài, theo dõi học sinh, tự tạo câu hỏi thật cho collection `questions` (hiện đang dùng bộ câu hỏi mẫu dự phòng khi chưa có dữ liệu)
2. **Cổng Nhà sản xuất** — quản lý môn học/câu hỏi/sự kiện/vật phẩm thật cho collection `items` (hiện đang dùng 8 vật phẩm mẫu dự phòng)
3. **Cloud Functions cho AI** — sinh câu hỏi, chấm tự luận, gợi ý bài học dựa trên `wrongQuestionIds` đã lưu trong `examResults`
4. **Thanh toán** — Google Play Billing / Apple In-App Purchase cho Gem/Coin
5. **2 mini game còn thiếu** — Đào kho báu, Câu cá (khung UI đã có sẵn trong `minigame_hub_screen.dart`, đang hiện "Sắp ra mắt")

## Ghi chú kỹ thuật quan trọng (cập nhật)

- **Không gọi API key AI trực tiếp từ Flutter app** — luôn qua Cloud Functions để tránh lộ key
- **Custom claims cho role** cần được set qua Cloud Function `onCreate`, không lưu role chỉ ở Firestore vì `firestore.rules` đang giả định `request.auth.token.role` đã tồn tại
- **Firestore Composite Index**: màn Bảng xếp hạng dùng `where(classId/schoolId) + orderBy(totalExp)`. Lần đầu chạy, Firebase sẽ báo lỗi kèm 1 link trong Console/log — bấm vào link đó để tự động tạo index (mất khoảng 1-2 phút để build xong)
- **Bộ câu hỏi & vật phẩm mẫu**: `fetchQuestions()` và `watchShopItems()` tự động dùng dữ liệu mẫu (`_sampleQuestions`, `_sampleItems`) khi Firestore chưa có dữ liệu thật — giúp bạn test được ngay app mà không cần nhập tay. Khi Giáo viên/Nhà sản xuất bắt đầu thêm nội dung thật vào Firestore, app sẽ tự động ưu tiên dùng dữ liệu thật
- Môi trường hiện tại của tôi không có kết nối mạng nên tôi **chưa chạy được `flutter pub get`** để xác minh biên dịch — bạn cần chạy bước này ở máy của bạn trước khi build
