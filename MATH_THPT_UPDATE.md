Cập nhật khu vực Toán THPT

Edupet hiện ưu tiên trải nghiệm Toán THPT. Khi học sinh chọn môn Toán, ứng dụng mở vào trung tâm Toán THPT thay vì đi thẳng vào bộ câu hỏi chung.

Các khu vực đã triển khai

Khu vực
Nội dung
Học tập
Lộ trình theo khối 10, 11, 12; chuyên đề; thời lượng dự kiến; gợi ý cách học và mở phiên luyện tập.
Luyện tập
Luyện nhanh, củng cố phần chưa vững, thử thách nâng cao; thống kê mẫu về số câu, độ chính xác và chuỗi ngày học.
Bài giáo viên giao
Điều hướng tới danh sách bài tập giáo viên giao hiện có, giữ nguyên kết quả và hạn nộp của luồng Firestore.
Đề kiểm tra
Các dạng 15 phút, giữa kỳ, cuối kỳ và ôn thi tốt nghiệp THPT; sử dụng lại màn hình làm bài và chấm điểm hiện có.
Thư viện
Hai nguồn tham khảo ngoài ứng dụng, nhóm chủ đề đề xuất và lưu ý bản quyền.




Nội dung mẫu offline

Ngân hàng câu hỏi mẫu đã bổ sung nội dung Toán THPT theo từng khối. Mỗi khối có các câu về những chủ đề chính: hàm số, bất phương trình, lượng giác, dãy số/cấp số, hình học không gian, đạo hàm, tích phân, số phức, xác suất và thống kê. Cơ chế Firestore hiện tại vẫn ưu tiên câu hỏi giáo viên tạo, đồng thời dùng nội dung mẫu khi chưa có dữ liệu thật.

Tệp mã nguồn chính

•
lib/screens/math_thpt_screen.dart: trung tâm Toán THPT và các khu vực nội dung.

•
lib/screens/subject_selection_screen.dart: điều hướng thẻ Toán vào trung tâm mới; các môn khác hiển thị trạng thái “Sắp ra mắt”.

•
lib/screens/exam_screen.dart: hỗ trợ tên hiển thị cho phiên luyện tập/đề kiểm tra.

•
lib/services/firestore_service.dart: ngân hàng câu hỏi mẫu theo khối 10, 11, 12.

Nguồn tham khảo

[1] Môn Toán – Trung học phổ thông. Nguồn này được dùng để định hướng các nhánh Toán 10/11/12, SGK/SBT theo bộ sách, chuyên đề và nhóm đề thi.
[2] Tài liệu Toán THPT – Tài liệu Môn Toán. Nguồn này được dùng để định hướng các chuyên đề, lý thuyết, đề giữa kỳ/ học kỳ và tài liệu ôn thi.
Kiểm thử

Môi trường đóng gói không cài Flutter/Dart SDK nên chưa thể chạy flutter analyze hoặc build APK tại đây. Nên chạy flutter pub get, flutter analyze và flutter test trên máy phát triển có Flutter SDK trước khi phát hành.

