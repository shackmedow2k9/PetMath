import '../models/math_lesson_model.dart';

/// Catalog học liệu nguyên bản của PetMath.
///
/// Nội dung là phần tóm tắt do PetMath biên soạn, không phải bản sao của SGK
/// hay tài liệu bên ngoài. Các sourceUrls chỉ dẫn tới nguồn tham khảo.
class MathCurriculumCatalog {
  static const _montoan = 'https://montoan.com.vn/thpt-trung-hoc-pho-thong';
  static const _tailieu = 'https://tailieumontoan.com/tai-lieu-toan-thpt-1';

  static const List<MathLessonData> lessons = [
    // ----------------------------- TOÁN 10 -----------------------------
    MathLessonData(
      id: 'g10-menh-de-tap-hop',
      grade: 10,
      unit: 'Mệnh đề và tập hợp',
      title: 'Mệnh đề, tập hợp và các phép toán',
      overview:
          'Bài học xây nền cho ngôn ngữ toán học: nhận biết mệnh đề, phủ định, mệnh đề kéo theo và mô tả tập hợp bằng điều kiện.',
      objectives: [
        'Phân biệt câu là mệnh đề và xác định được giá trị đúng/sai.',
        'Sử dụng phủ định, kéo theo, tương đương trong lập luận.',
        'Biểu diễn hợp, giao, hiệu và phần bù của các tập hợp.',
      ],
      keyPoints: [
        'Mệnh đề là câu khẳng định có một giá trị chân lý xác định.',
        'A kéo theo B chỉ sai khi A đúng và B sai.',
        'Hợp gom phần tử thuộc ít nhất một tập; giao lấy phần tử chung.',
      ],
      formulas: [
        'A ⊂ B khi mọi phần tử của A đều thuộc B.',
        'n(A ∪ B) = n(A) + n(B) − n(A ∩ B).',
        'A\\B là tập phần tử thuộc A nhưng không thuộc B.',
      ],
      exampleTitle: 'Ví dụ: đếm phần tử của hợp hai tập',
      exampleSteps: [
        'Cho A là tập học sinh thích Đại số, B là tập học sinh thích Hình học.',
        'Xác định n(A), n(B) và n(A ∩ B) từ dữ kiện đề bài.',
        'Thay vào công thức n(A ∪ B) để tránh đếm phần giao hai lần.',
      ],
      checkpoints: [
        'Biết viết phủ định của mệnh đề chứa “mọi” và “tồn tại”.',
        'Vẽ được biểu đồ Ven cho hai tập hợp.',
        'Tính đúng số phần tử của hợp và giao.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g10-bat-phuong-trinh',
      grade: 10,
      unit: 'Bất phương trình và hệ thức',
      title: 'Bất phương trình bậc nhất và bậc hai',
      overview:
          'Học cách biến đổi bất phương trình, xét dấu tam thức bậc hai và biểu diễn miền nghiệm trên trục số.',
      objectives: [
        'Giải bất phương trình bậc nhất một ẩn.',
        'Lập bảng xét dấu cho tích, thương và tam thức bậc hai.',
        'Giải hệ bất phương trình và bài toán tham số cơ bản.',
      ],
      keyPoints: [
        'Nhân hoặc chia hai vế với số âm phải đổi chiều bất đẳng thức.',
        'Dấu của tam thức ax²+bx+c phụ thuộc vào a và hai nghiệm.',
        'Nghiệm hệ là phần giao của các miền nghiệm thành phần.',
      ],
      formulas: [
        'Δ = b² − 4ac.',
        'Nếu Δ > 0: ax²+bx+c cùng dấu a ngoài hai nghiệm, trái dấu a giữa hai nghiệm.',
        'Khoảng nghiệm phải viết kèm điều kiện xác định của biểu thức.',
      ],
      exampleTitle: 'Ví dụ: xét dấu tam thức',
      exampleSteps: [
        'Tìm nghiệm của 2x²−5x+2 bằng cách phân tích hoặc dùng Δ.',
        'Sắp xếp hai nghiệm trên trục số và xác định dấu hệ số đầu.',
        'Chọn các khoảng thỏa yêu cầu rồi kiểm tra điểm thử.',
      ],
      checkpoints: [
        'Không quên đổi chiều khi nhân/chia số âm.',
        'Phân biệt nghiệm của bất phương trình với nghiệm của phương trình biên.',
        'Biểu diễn tập nghiệm bằng khoảng và đoạn đúng quy ước.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g10-ham-so-do-thi',
      grade: 10,
      unit: 'Hàm số và đồ thị',
      title: 'Hàm số bậc hai, đồ thị và biến thiên',
      overview:
          'Từ bảng giá trị đến đồ thị, bài học giúp đọc đặc trưng của hàm số bậc nhất/bậc hai và ứng dụng vào bài toán thực tế.',
      objectives: [
        'Xác định tập xác định, giá trị và các điểm đặc biệt của hàm số.',
        'Vẽ parabol và tìm đỉnh, trục đối xứng, giao điểm với trục tọa độ.',
        'Dùng đồ thị để giải phương trình, bất phương trình và tối ưu đơn giản.',
      ],
      keyPoints: [
        'Đỉnh parabol là tâm đối xứng của đồ thị hàm bậc hai.',
        'Dấu của a quyết định parabol quay lên hay quay xuống.',
        'Giao điểm đồ thị với Ox liên quan đến nghiệm của f(x)=0.',
      ],
      formulas: [
        'x_đỉnh = −b/(2a), y_đỉnh = −Δ/(4a).',
        'Trục đối xứng: x = −b/(2a).',
        'f(x) = a(x−x₁)(x−x₂) khi có hai nghiệm phân biệt.',
      ],
      exampleTitle: 'Ví dụ: tìm giá trị lớn nhất',
      exampleSteps: [
        'Đưa biểu thức về dạng ax²+bx+c.',
        'Tìm hoành độ đỉnh và xét chiều mở của parabol.',
        'Kết luận giá trị lớn nhất/nhỏ nhất, nhớ kiểm tra miền biến thiên nếu có.',
      ],
      checkpoints: [
        'Đọc đúng tọa độ đỉnh.',
        'Liên hệ bảng biến thiên với hình dạng đồ thị.',
        'Kiểm tra miền xác định trước khi kết luận.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g10-vecto-toa-do',
      grade: 10,
      unit: 'Vectơ và tọa độ phẳng',
      title: 'Vectơ, tích vô hướng và đường thẳng',
      overview:
          'Biểu diễn hình học bằng tọa độ giúp giải bài toán thẳng hàng, vuông góc, khoảng cách và góc trong mặt phẳng.',
      objectives: [
        'Tính tọa độ vectơ, độ dài và tích vô hướng.',
        'Lập phương trình đường thẳng qua điểm hoặc song song/vuông góc đường cho trước.',
        'Tính khoảng cách từ điểm đến đường thẳng.',
      ],
      keyPoints: [
        'Vectơ AB có tọa độ (xB−xA; yB−yA).',
        'Hai vectơ vuông góc khi tích vô hướng bằng 0.',
        'Một đường thẳng có thể mô tả bằng vectơ pháp tuyến hoặc vectơ chỉ phương.',
      ],
      formulas: [
        'u·v = u₁v₁ + u₂v₂.',
        '|u| = √(u₁²+u₂²).',
        'd(M, Δ): |Ax₀+By₀+C|/√(A²+B²).',
      ],
      exampleTitle: 'Ví dụ: kiểm tra vuông góc',
      exampleSteps: [
        'Lập hai vectơ chỉ phương từ các điểm đã cho.',
        'Tính tích vô hướng của hai vectơ.',
        'Nếu kết quả bằng 0, kết luận hai đường vuông góc.',
      ],
      checkpoints: [
        'Xác định đúng thứ tự tọa độ x,y.',
        'Không nhầm vectơ pháp tuyến với vectơ chỉ phương.',
        'Rút gọn kết quả khoảng cách về dạng chính xác.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g10-xac-suat-co-ban',
      grade: 10,
      unit: 'Xác suất và thống kê',
      title: 'Quy tắc đếm và xác suất cơ bản',
      overview:
          'Mô hình hóa tình huống ngẫu nhiên bằng không gian mẫu, biến cố và các quy tắc đếm cơ bản.',
      objectives: [
        'Mô tả không gian mẫu và biến cố trong thí nghiệm đơn giản.',
        'Dùng quy tắc cộng, quy tắc nhân và hoán vị/chỉnh hợp khi phù hợp.',
        'Tính xác suất trong trường hợp các kết quả đồng khả năng.',
      ],
      keyPoints: [
        'Không gian mẫu gồm tất cả kết quả có thể xảy ra.',
        'Biến cố đối là phần còn lại của không gian mẫu.',
        'Luôn kiểm tra kết quả xác suất nằm trong đoạn [0;1].',
      ],
      formulas: [
        'P(A) = n(A)/n(Ω) khi các kết quả đồng khả năng.',
        'P(Ā) = 1 − P(A).',
        'Quy tắc nhân: m·n lựa chọn liên tiếp khi mỗi bước có số cách tương ứng.',
      ],
      exampleTitle: 'Ví dụ: chọn nhóm học tập',
      exampleSteps: [
        'Xác định tổng số cách chọn nhóm theo điều kiện đề bài.',
        'Đếm số cách thuận lợi, chú ý thứ tự có quan trọng hay không.',
        'Lập tỉ số thuận lợi trên tổng số và rút gọn.',
      ],
      checkpoints: [
        'Phân biệt chỉnh hợp và tổ hợp.',
        'Không đếm trùng cùng một kết quả.',
        'Nêu rõ Ω trước khi tính xác suất.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),

    // ----------------------------- TOÁN 11 -----------------------------
    MathLessonData(
      id: 'g11-luong-giac',
      grade: 11,
      unit: 'Hàm số lượng giác',
      title: 'Hàm số lượng giác và phương trình lượng giác',
      overview:
          'Hệ thống hóa đường tròn lượng giác, đồ thị sin/cos và các phương pháp giải phương trình lượng giác cơ bản.',
      objectives: [
        'Đọc giá trị lượng giác trên đường tròn đơn vị.',
        'Nhận biết chu kỳ, tập xác định và tập giá trị của sin, cos, tan.',
        'Giải phương trình lượng giác cơ bản và phương trình đưa về dạng cơ bản.',
      ],
      keyPoints: [
        'sin và cos có chu kỳ 2π; tan có chu kỳ π.',
        'Luôn giữ điều kiện xác định khi biến đổi phương trình.',
        'Nghiệm tổng quát phải chứa k thuộc Z.',
      ],
      formulas: [
        'sin²x + cos²x = 1.',
        'sin x = sin α ⇒ x = α + k2π hoặc x = π−α+k2π.',
        'cos x = cos α ⇒ x = ±α+k2π.',
      ],
      exampleTitle: 'Ví dụ: giải phương trình sin x = 1/2',
      exampleSteps: [
        'Xác định góc cơ bản α = π/6.',
        'Viết hai họ nghiệm đối xứng trên đường tròn lượng giác.',
        'Nếu đề giới hạn khoảng, lọc các nghiệm thuộc khoảng đó.',
      ],
      checkpoints: [
        'Đổi đúng độ/radian theo đề.',
        'Viết đủ hai họ nghiệm của sin/cos.',
        'Kiểm tra điều kiện của tan/cot.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g11-day-so-cap-so',
      grade: 11,
      unit: 'Dãy số và cấp số',
      title: 'Dãy số, cấp số cộng và cấp số nhân',
      overview:
          'Mô hình hóa quá trình tăng đều hoặc tăng theo tỉ lệ bằng số hạng tổng quát và tổng n số hạng đầu.',
      objectives: [
        'Tìm số hạng tổng quát của dãy qua quy luật hoặc truy hồi.',
        'Nhận biết và giải bài toán cấp số cộng/cấp số nhân.',
        'Ứng dụng dãy số vào lãi suất, tăng trưởng và chia đều.',
      ],
      keyPoints: [
        'Cấp số cộng có hiệu hai số hạng liên tiếp không đổi.',
        'Cấp số nhân có tỉ số hai số hạng liên tiếp không đổi.',
        'Chọn mô hình theo dữ kiện: cộng đều hay nhân theo tỉ lệ.',
      ],
      formulas: [
        'uₙ = u₁ + (n−1)d.',
        'Sₙ = n(u₁+uₙ)/2.',
        'uₙ = u₁qⁿ⁻¹; Sₙ = u₁(qⁿ−1)/(q−1), q ≠ 1.',
      ],
      exampleTitle: 'Ví dụ: tiền tiết kiệm tăng theo tỉ lệ',
      exampleSteps: [
        'Xác định số tiền ban đầu là u₁ và tỉ lệ tăng q.',
        'Dùng công thức uₙ để tìm số tiền ở kỳ n.',
        'Nếu cần tổng tiền, chuyển sang công thức Sₙ và nêu đơn vị.',
      ],
      checkpoints: [
        'Phân biệt d và q.',
        'Xác định đúng chỉ số bắt đầu.',
        'Kiểm tra q=1 trước khi dùng công thức tổng cấp số nhân.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g11-gioi-han-lien-tuc',
      grade: 11,
      unit: 'Giới hạn và liên tục',
      title: 'Giới hạn hàm số và tính liên tục',
      overview:
          'Làm quen với ý tưởng giá trị hàm tiến gần một số và dùng giới hạn để kiểm tra liên tục.',
      objectives: [
        'Tính giới hạn bằng thế trực tiếp, phân tích nhân tử và liên hợp.',
        'Nhận biết giới hạn vô cực và tiệm cận đơn giản.',
        'Kiểm tra điều kiện liên tục tại một điểm.',
      ],
      keyPoints: [
        'Giới hạn mô tả xu hướng, không nhất thiết là giá trị hàm tại điểm đó.',
        'Dạng 0/0 thường cần phân tích hoặc nhân liên hợp.',
        'Hàm liên tục tại a khi f(a) tồn tại, giới hạn tồn tại và bằng f(a).',
      ],
      formulas: [
        'lim[f(x)±g(x)] = lim f(x) ± lim g(x).',
        'lim(x→a)(xⁿ−aⁿ)/(x−a) = naⁿ⁻¹.',
        'Liên tục tại a: lim(x→a)f(x)=f(a).',
      ],
      exampleTitle: 'Ví dụ: khử dạng 0/0',
      exampleSteps: [
        'Thử thay trực tiếp để nhận dạng dạng vô định.',
        'Phân tích tử và mẫu, rút nhân tử chung x−a.',
        'Tính giới hạn biểu thức còn lại và kết luận.',
      ],
      checkpoints: [
        'Không thay trực tiếp khi mẫu bằng 0.',
        'Phân biệt giới hạn một bên khi cần.',
        'Kiểm tra cả giá trị hàm trong bài liên tục.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g11-hinh-hoc-khong-gian',
      grade: 11,
      unit: 'Hình học không gian',
      title: 'Đường thẳng, mặt phẳng và quan hệ vuông góc',
      overview:
          'Rèn khả năng hình dung không gian, xác định giao tuyến, góc và khoảng cách qua các định lý nền tảng.',
      objectives: [
        'Xác định giao điểm, giao tuyến và thiết diện cơ bản.',
        'Chứng minh đường thẳng vuông góc mặt phẳng.',
        'Tính góc giữa đường thẳng, mặt phẳng và khoảng cách trong tình huống quen thuộc.',
      ],
      keyPoints: [
        'Một đường thẳng vuông góc mặt phẳng khi vuông góc hai đường cắt nhau trong mặt phẳng.',
        'Góc giữa đường và mặt là góc giữa đường đó và hình chiếu lên mặt.',
        'Khi tính khoảng cách, hãy tìm đoạn vuông góc chung hoặc hình chiếu.',
      ],
      formulas: [
        'Nếu d ⟂ a và d ⟂ b với a,b cắt nhau trong (P) thì d ⟂ (P).',
        'Khoảng cách từ điểm đến mặt phẳng là độ dài đoạn vuông góc.',
        'Thể tích lăng trụ = diện tích đáy × chiều cao.',
      ],
      exampleTitle: 'Ví dụ: chứng minh đường vuông góc mặt',
      exampleSteps: [
        'Chọn hai đường thẳng cắt nhau nằm trong mặt phẳng cần xét.',
        'Chứng minh đường đã cho vuông góc từng đường đó.',
        'Áp dụng định lý ba đường vuông góc để kết luận.',
      ],
      checkpoints: [
        'Vẽ hình và ghi rõ mặt phẳng chứa đường.',
        'Không suy ra vuông góc chỉ từ hình vẽ.',
        'Chọn hình chiếu trước khi tính góc/khoảng cách.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g11-thong-ke-xac-suat',
      grade: 11,
      unit: 'Thống kê và xác suất',
      title: 'Đặc trưng mẫu số liệu và xác suất có điều kiện',
      overview:
          'Đọc dữ liệu bằng trung bình, trung vị, mốt, độ phân tán và mở rộng sang xác suất có điều kiện, độc lập.',
      objectives: [
        'Tính và diễn giải các đặc trưng đo xu thế trung tâm.',
        'Nhận biết độ phân tán và ảnh hưởng của ngoại lệ.',
        'Tính xác suất có điều kiện và dùng quy tắc nhân.',
      ],
      keyPoints: [
        'Trung vị bền vững hơn trung bình trước giá trị ngoại lệ.',
        'Phương sai càng lớn thì dữ liệu càng phân tán quanh trung bình.',
        'Xác suất có điều kiện thu hẹp không gian mẫu theo điều kiện B.',
      ],
      formulas: [
        'P(A|B)=P(A∩B)/P(B), P(B)>0.',
        'Nếu A,B độc lập: P(A∩B)=P(A)P(B).',
        'Phương sai là trung bình của bình phương độ lệch so với trung bình.',
      ],
      exampleTitle: 'Ví dụ: so sánh hai nhóm dữ liệu',
      exampleSteps: [
        'Tính trung bình và trung vị của từng nhóm.',
        'Tính khoảng biến thiên hoặc độ lệch để so độ phân tán.',
        'Viết kết luận bằng ngữ cảnh, không chỉ nêu một con số.',
      ],
      checkpoints: [
        'Sắp xếp dữ liệu trước khi tìm trung vị.',
        'Không gọi hai biến cố độc lập chỉ vì chúng không giao nhau.',
        'Kiểm tra điều kiện P(B)>0.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),

    // ----------------------------- TOÁN 12 -----------------------------
    MathLessonData(
      id: 'g12-ung-dung-dao-ham',
      grade: 12,
      unit: 'Ứng dụng đạo hàm',
      title: 'Đơn điệu, cực trị và khảo sát hàm số',
      overview:
          'Dùng đạo hàm để đọc biến thiên, tìm cực trị, tiếp tuyến và giải các bài toán tối ưu thường gặp.',
      objectives: [
        'Tính đạo hàm và lập bảng biến thiên.',
        'Tìm khoảng đơn điệu, cực trị, tiệm cận và phác họa đồ thị.',
        'Giải bài toán tiếp tuyến và tối ưu có điều kiện.',
      ],
      keyPoints: [
        'Dấu của f′ quyết định chiều biến thiên của f.',
        'Cực trị cần xét sự đổi dấu của đạo hàm hoặc bảng biến thiên.',
        'Tiếp tuyến tại x₀ có hệ số góc f′(x₀).',
      ],
      formulas: [
        'y−f(x₀)=f′(x₀)(x−x₀).',
        'Nếu f′ đổi dấu + sang −: cực đại; − sang +: cực tiểu.',
        'f′(x)=0 là điều kiện cần thường gặp, không phải điều kiện đủ.',
      ],
      exampleTitle: 'Ví dụ: tìm cực trị của hàm đa thức',
      exampleSteps: [
        'Tính f′ và giải f′(x)=0.',
        'Lập bảng dấu f′ trên các khoảng xác định.',
        'Kết luận cực trị kèm tọa độ điểm nếu đề yêu cầu.',
      ],
      checkpoints: [
        'Xét miền xác định trước khi đạo hàm.',
        'Không kết luận cực trị chỉ vì f′=0.',
        'Phân biệt điểm cực trị và giá trị cực trị.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g12-nguyen-ham-tich-phan',
      grade: 12,
      unit: 'Nguyên hàm và tích phân',
      title: 'Nguyên hàm, tích phân và ứng dụng',
      overview:
          'Hệ thống hóa bảng nguyên hàm, kỹ thuật đổi biến/từng phần và diện tích, thể tích qua tích phân.',
      objectives: [
        'Nhận biết họ nguyên hàm và dùng bảng nguyên hàm cơ bản.',
        'Tính tích phân xác định bằng tính chất và phương pháp phù hợp.',
        'Tính diện tích hình phẳng và thể tích khối tròn xoay đơn giản.',
      ],
      keyPoints: [
        'Hai nguyên hàm của cùng hàm số chỉ khác nhau một hằng số.',
        'Tích phân xác định có thể âm; diện tích cần dùng giá trị tuyệt đối khi cần.',
        'Chọn cận theo biến tích phân và kiểm tra giao điểm đồ thị.',
      ],
      formulas: [
        '∫f(x)dx=F(x)+C khi F′(x)=f(x).',
        '∫ₐᵇf(x)dx=F(b)−F(a).',
        'S=∫ₐᵇ|f(x)−g(x)|dx.',
      ],
      exampleTitle: 'Ví dụ: tính diện tích giữa hai đồ thị',
      exampleSteps: [
        'Giải phương trình f(x)=g(x) để tìm giao điểm.',
        'Xác định hàm nào nằm trên trong từng khoảng.',
        'Lập tích phân hiệu trên-trên dưới và tính giá trị dương.',
      ],
      checkpoints: [
        'Không quên hằng số C khi tìm nguyên hàm.',
        'Chọn đúng hàm trên/dưới.',
        'Kiểm tra đơn vị diện tích hoặc thể tích.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g12-hinh-hoc-toa-do',
      grade: 12,
      unit: 'Vectơ và hệ tọa độ trong không gian',
      title: 'Phương trình mặt phẳng, đường thẳng và mặt cầu',
      overview:
          'Chuyển bài toán hình học không gian sang đại số bằng tọa độ, tích vô hướng và phương trình.',
      objectives: [
        'Lập phương trình mặt phẳng qua điểm và có vectơ pháp tuyến.',
        'Lập phương trình đường thẳng theo điểm và vectơ chỉ phương.',
        'Tính góc, khoảng cách và nhận biết vị trí tương đối.',
      ],
      keyPoints: [
        'Vectơ pháp tuyến vuông góc mọi vectơ chỉ phương nằm trong mặt phẳng.',
        'Hai mặt phẳng song song khi các vectơ pháp tuyến cùng phương.',
        'Khoảng cách cần dùng đúng đối tượng: điểm-mặt, điểm-đường hoặc hai mặt.',
      ],
      formulas: [
        '(P): Ax+By+Cz+D=0 có pháp tuyến n=(A,B,C).',
        'Mặt cầu tâm I(a,b,c), bán kính R: (x−a)²+(y−b)²+(z−c)²=R².',
        'cos góc giữa hai vectơ = |u·v|/(|u||v|).',
      ],
      exampleTitle: 'Ví dụ: lập mặt phẳng qua ba điểm',
      exampleSteps: [
        'Tạo hai vectơ chỉ phương từ ba điểm.',
        'Tính tích có hướng để tìm vectơ pháp tuyến.',
        'Thay một điểm vào phương trình tổng quát để tìm hằng số.',
      ],
      checkpoints: [
        'Ba điểm phải không thẳng hàng.',
        'Kiểm tra điểm đã cho thỏa phương trình.',
        'Dùng trị tuyệt đối khi tính góc tùy quy ước.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g12-so-phuc',
      grade: 12,
      unit: 'Số phức',
      title: 'Biểu diễn và phương trình số phức',
      overview:
          'Làm việc với dạng đại số, liên hợp, môđun và biểu diễn hình học của số phức trên mặt phẳng Argand.',
      objectives: [
        'Thực hiện phép toán với số phức dạng a+bi.',
        'Tính liên hợp, môđun và giải phương trình số phức đơn giản.',
        'Diễn giải điều kiện số phức bằng hình học.',
      ],
      keyPoints: [
        'i²=−1 và hai số phức bằng nhau khi phần thực, phần ảo tương ứng bằng nhau.',
        'Liên hợp giúp khử i ở mẫu.',
        'Môđun là khoảng cách từ điểm biểu diễn đến gốc tọa độ.',
      ],
      formulas: [
        '|a+bi|=√(a²+b²).',
        'z·z̄=|z|².',
        '1/(a+bi)=(a−bi)/(a²+b²) khi a²+b²≠0.',
      ],
      exampleTitle: 'Ví dụ: chia hai số phức',
      exampleSteps: [
        'Nhân cả tử và mẫu với liên hợp của mẫu.',
        'Dùng i²=−1 và gom phần thực, phần ảo.',
        'Kiểm tra mẫu số thực khác 0 và kết luận dạng a+bi.',
      ],
      checkpoints: [
        'Không nhầm dấu khi dùng liên hợp.',
        'Tách đúng phần thực/phần ảo.',
        'Đọc môđun như độ dài, luôn không âm.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
    MathLessonData(
      id: 'g12-xac-suat-ung-dung',
      grade: 12,
      unit: 'Xác suất và thống kê',
      title: 'Xác suất, biến ngẫu nhiên và dữ liệu',
      overview:
          'Ôn tập mô hình xác suất, biến ngẫu nhiên rời rạc và đọc các chỉ số thống kê trong bối cảnh thực tế.',
      objectives: [
        'Mô hình hóa biến cố bằng sơ đồ cây hoặc bảng phân bố.',
        'Tính kỳ vọng, phương sai trong trường hợp rời rạc đơn giản.',
        'Đánh giá kết quả bằng xác suất và thông tin dữ liệu.',
      ],
      keyPoints: [
        'Phân bố xác suất phải có các xác suất không âm và tổng bằng 1.',
        'Kỳ vọng là giá trị trung bình có trọng số theo xác suất.',
        'Kết luận thống kê cần gắn với mẫu và bối cảnh, không suy diễn quá mức.',
      ],
      formulas: [
        'E(X)=Σxᵢpᵢ.',
        'Var(X)=E(X²)−[E(X)]².',
        'P(A)=ΣP(A|Bᵢ)P(Bᵢ) với hệ biến cố phân hoạch.',
      ],
      exampleTitle: 'Ví dụ: giá trị kỳ vọng của trò chơi',
      exampleSteps: [
        'Liệt kê các kết quả và xác suất tương ứng.',
        'Nhân mỗi giá trị với xác suất rồi cộng các tích.',
        'Diễn giải kỳ vọng là mức trung bình dài hạn, không phải kết quả chắc chắn.',
      ],
      checkpoints: [
        'Tổng xác suất bằng 1.',
        'Không nhầm kỳ vọng với trung vị.',
        'Đọc đúng điều kiện trong xác suất có điều kiện.'
      ],
      sourceUrls: [_montoan, _tailieu],
    ),
  ];

  static List<MathLessonData> lessonsForGrade(int grade) {
    return lessons.where((lesson) => lesson.grade == grade).toList();
  }

  static MathLessonData? find(String id) {
    for (final lesson in lessons) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }
}
