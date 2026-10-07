import '../models/math_lesson_model.dart';

/// Nội dung học tập nguyên bản PetMath. Mỗi chuyên đề có các mục đọc sâu hơn
/// và ví dụ định hướng; dữ liệu được đóng gói trong app, không phụ thuộc link.
class MathStudyContent {
  static const Map<String, List<MathStudySection>> sections = {
    'g10-menh-de-tap-hop': [
      MathStudySection(
        title: '1. Mệnh đề và phủ định',
        explanation:
            'Mệnh đề là một câu khẳng định có giá trị đúng hoặc sai xác định. Khi gặp câu chứa biến, cần xét điều kiện để biến câu đó thành mệnh đề. Phủ định của mệnh đề phải làm đảo giá trị chân lý của mệnh đề ban đầu.',
        keyIdeas: [
          '“Mọi x” đổi thành “tồn tại x” khi phủ định.',
          'A ⇒ B chỉ sai ở trường hợp A đúng, B sai.',
          'A ⇔ B đúng khi hai mệnh đề cùng giá trị chân lý.'
        ],
        workedExample: [
          'Mệnh đề P: “Với mọi x thuộc R, x² ≥ 0”.',
          'Phủ định là: “Tồn tại x thuộc R sao cho x² < 0”.',
          'Vì không có x thực như vậy nên P đúng.'
        ],
      ),
      MathStudySection(
        title: '2. Biểu diễn tập hợp',
        explanation:
            'Một tập hợp có thể được mô tả bằng cách liệt kê phần tử, nêu tính chất đặc trưng hoặc biểu diễn trên trục số. Khi giải bài toán chứa điều kiện, hãy đưa điều kiện về dạng khoảng trước khi thực hiện phép toán tập hợp.',
        keyIdeas: [
          'A ∩ B là phần chung của hai tập.',
          'A ∪ B chứa mọi phần tử thuộc ít nhất một tập.',
          'A\\B giữ lại phần tử của A nhưng loại phần tử thuộc B.'
        ],
        workedExample: [
          'Cho A = [−2; 3) và B = (1; 5].',
          'A ∩ B = (1; 3), còn A ∪ B = [−2; 5].',
          'Khi viết đáp án, chú ý ngoặc tròn/vuông theo điều kiện biên.'
        ],
      ),
      MathStudySection(
        title: '3. Chiến lược giải bài',
        explanation:
            'Đọc kỹ lượng từ “mọi”, “tồn tại”, “ít nhất”, “chỉ khi”. Đây là những từ quyết định phép phủ định và hướng kéo theo. Với bài đếm phần tử, nên vẽ biểu đồ Ven trước khi thay số.',
        keyIdeas: [
          'Tách phần giao trước khi tính hợp.',
          'Kiểm tra phần tử biên bằng cách thử trực tiếp.',
          'Kết luận bằng đúng ngôn ngữ của đề bài.'
        ],
      ),
    ],
    'g10-bat-phuong-trinh': [
      MathStudySection(
        title: '1. Bất phương trình bậc nhất',
        explanation:
            'Biến đổi tương đương được phép cộng cùng một số vào hai vế hoặc nhân/chia với số dương. Nếu nhân hoặc chia với số âm, chiều bất đẳng thức phải đổi.',
        keyIdeas: [
          'Đưa ẩn về một vế và hằng số về vế còn lại.',
          'Khi hệ số của ẩn âm, nhớ đổi chiều ở bước cuối.',
          'Nghiệm được biểu diễn trên trục số.'
        ],
        workedExample: [
          'Giải −2x + 5 > 1.',
          'Suy ra −2x > −4.',
          'Chia −2: x < 2.'
        ],
      ),
      MathStudySection(
        title: '2. Tam thức bậc hai',
        explanation:
            'Tam thức ax²+bx+c có dấu được quyết định bởi hệ số a và nghiệm. Bảng xét dấu là công cụ an toàn hơn việc suy luận trực tiếp từ một vài giá trị.',
        keyIdeas: [
          'Tính Δ để biết số nghiệm.',
          'Nếu có hai nghiệm, dấu đổi qua mỗi nghiệm đơn.',
          'Nghiệm kép không làm đổi dấu tam thức.'
        ],
        workedExample: [
          'Với f(x)=x²−5x+6, ta có f(x)=(x−2)(x−3).',
          'f(x)>0 khi x<2 hoặc x>3.',
          'f(x)<0 khi 2<x<3.'
        ],
      ),
      MathStudySection(
        title: '3. Hệ bất phương trình và tham số',
        explanation:
            'Giải từng bất phương trình rồi lấy giao các tập nghiệm. Với tham số, hãy xác định điều kiện để miền nghiệm có số phần tử, độ dài hoặc vị trí theo yêu cầu.',
        keyIdeas: [
          'Vẽ trục số chung cho các điều kiện.',
          'Giao rỗng cũng là một kết luận hợp lệ.',
          'Kiểm tra điều kiện xác định trước khi xét dấu.'
        ],
      ),
    ],
    'g10-ham-so-do-thi': [
      MathStudySection(
        title: '1. Tập xác định và biến thiên',
        explanation:
            'Tập xác định cho biết những giá trị x được phép sử dụng. Từ bảng biến thiên, ta đọc được khoảng tăng giảm, cực trị và xu hướng của hàm số.',
        keyIdeas: [
          'Mẫu số khác 0.',
          'Biểu thức dưới căn bậc chẵn không âm.',
          'Tập xác định phải được ghi trước mọi kết luận về đồ thị.'
        ],
        workedExample: [
          'Với f(x)=√(x−1)/(x−3), điều kiện là x≥1 và x≠3.',
          'Tập xác định là [1;3) ∪ (3;+∞).',
          'Không được bỏ điều kiện x≠3 sau khi biến đổi.'
        ],
      ),
      MathStudySection(
        title: '2. Hàm số bậc hai',
        explanation:
            'Đồ thị y=ax²+bx+c là một parabol. Đỉnh và trục đối xứng giúp vẽ nhanh, còn giao điểm với các trục giúp kiểm tra kết quả.',
        keyIdeas: [
          'a>0: parabol quay lên; a<0: quay xuống.',
          'Đỉnh có hoành độ −b/(2a).',
          'Δ quyết định số giao điểm với trục Ox.'
        ],
        workedExample: [
          'Với y=x²−4x+3, đỉnh là I(2;−1).',
          'Trục đối xứng x=2.',
          'Hai nghiệm 1 và 3 cho hai giao điểm với Ox.'
        ],
      ),
      MathStudySection(
        title: '3. Đọc đồ thị trong bài toán thực tế',
        explanation:
            'Đồ thị có thể mô tả chi phí, quãng đường, doanh thu hoặc chiều cao. Mỗi giao điểm, cực trị và khoảng biến thiên cần được diễn giải bằng đơn vị của bài toán.',
        keyIdeas: [
          'Điểm cực đại có thể là doanh thu lớn nhất.',
          'Miền xét phải phù hợp thời gian hoặc số lượng thực tế.',
          'Luôn kiểm tra đơn vị sau khi tính.'
        ],
      ),
    ],
    'g10-vecto-toa-do': [
      MathStudySection(
        title: '1. Tọa độ vectơ',
        explanation:
            'Trong mặt phẳng tọa độ, mọi bài toán về độ dài và phương hướng có thể chuyển thành phép tính trên hai thành phần. Việc chọn đúng điểm đầu và điểm cuối giúp tránh sai dấu.',
        keyIdeas: [
          'AB = (xB−xA; yB−yA).',
          'Hai vectơ cùng phương khi các tọa độ tỉ lệ.',
          'Độ dài vectơ là căn bậc hai tổng bình phương thành phần.'
        ],
        workedExample: [
          'A(1;2), B(4;6) thì AB=(3;4).',
          '|AB|=√(3²+4²)=5.',
          'Nếu C(−2;−1), AC=(−3;−3) không cùng phương AB.'
        ],
      ),
      MathStudySection(
        title: '2. Tích vô hướng và góc',
        explanation:
            'Tích vô hướng nối đại số với hình học: dấu của tích cho biết góc nhọn, vuông hoặc tù. Đây là công cụ nhanh để kiểm tra vuông góc.',
        keyIdeas: [
          'u·v=0 tương đương u vuông góc v.',
          'u·v>0 cho góc nhọn.',
          'Khi tính cos, lấy đúng mẫu là |u||v|.'
        ],
        workedExample: [
          'u=(2;1), v=(1;−2).',
          'u·v=2−2=0.',
          'Suy ra hai vectơ vuông góc.'
        ],
      ),
      MathStudySection(
        title: '3. Đường thẳng và khoảng cách',
        explanation:
            'Phương trình tổng quát Ax+By+C=0 có vectơ pháp tuyến (A;B). Khoảng cách điểm–đường được dùng để xử lý bài toán tiếp xúc, tối ưu và hình học.',
        keyIdeas: [
          'Vectơ chỉ phương vuông góc vectơ pháp tuyến.',
          'Thay tọa độ điểm vào phương trình để kiểm tra thuộc đường.',
          'Khoảng cách luôn không âm.'
        ],
      ),
    ],
    'g10-xac-suat-co-ban': [
      MathStudySection(
        title: '1. Không gian mẫu và biến cố',
        explanation:
            'Hãy liệt kê mọi kết quả có thể trước khi chọn cách đếm. Một mô hình tốt phải phân biệt rõ kết quả cơ bản và biến cố cần quan tâm.',
        keyIdeas: [
          'Ω là tập tất cả kết quả.',
          'A là tập con của Ω.',
          'Biến cố đối Ā gồm những kết quả không làm A xảy ra.'
        ],
        workedExample: [
          'Tung một đồng xu hai lần: Ω={NN,NS,SN,SS}.',
          'Biến cố có đúng một lần ngửa là {NS,SN}.',
          'Xác suất bằng 2/4=1/2 nếu các kết quả đồng khả năng.'
        ],
      ),
      MathStudySection(
        title: '2. Quy tắc đếm',
        explanation:
            'Quy tắc cộng dùng cho các lựa chọn loại trừ nhau; quy tắc nhân dùng cho các công đoạn liên tiếp. Trước khi tính, cần trả lời câu hỏi “thứ tự có quan trọng không?”.',
        keyIdeas: [
          'Chọn một trong m cách hoặc n cách: cộng.',
          'Thực hiện hai bước liên tiếp: nhân.',
          'Tổ hợp không xét thứ tự; chỉnh hợp có xét thứ tự.'
        ],
      ),
      MathStudySection(
        title: '3. Xác suất trong tình huống thực tế',
        explanation:
            'Sau khi đếm, hãy diễn giải kết quả bằng ngữ cảnh. Xác suất là mức độ có thể xảy ra, không phải lời khẳng định chắc chắn cho một lần thử.',
        keyIdeas: [
          '0≤P(A)≤1.',
          'P(Ā)=1−P(A).',
          'Kiểm tra các kết quả có đồng khả năng trước khi dùng n(A)/n(Ω).'
        ],
      ),
    ],
    'g11-luong-giac': [
      MathStudySection(
        title: '1. Đường tròn lượng giác',
        explanation:
            'Đường tròn đơn vị giúp xác định dấu và giá trị của sin, cos theo góc phần tư. Hãy ghi nhớ các góc đặc biệt và dùng đối xứng thay vì học thuộc rời rạc.',
        keyIdeas: [
          'cos là hoành độ, sin là tung độ.',
          'tan x=sin x/cos x khi cos x khác 0.',
          'Góc cùng điểm cuối sai khác bội 2π.'
        ],
        workedExample: [
          'Góc 5π/6 nằm ở góc phần tư II.',
          'sin 5π/6=1/2, cos 5π/6=−√3/2.',
          'Dấu được kiểm tra trước khi dùng giá trị tuyệt đối.'
        ],
      ),
      MathStudySection(
        title: '2. Phương trình lượng giác cơ bản',
        explanation:
            'Mỗi dạng sin, cos, tan có họ nghiệm riêng. Sau khi viết nghiệm tổng quát, cần lọc nghiệm nếu đề cho khoảng hoặc điều kiện số nguyên.',
        keyIdeas: [
          'Sin có hai họ nghiệm.',
          'Cos có hai hướng đối xứng ±α.',
          'Tan có chu kỳ π.'
        ],
      ),
      MathStudySection(
        title: '3. Biến đổi lượng giác',
        explanation:
            'Các công thức cộng, nhân đôi và hạ bậc giúp đưa phương trình về dạng cơ bản. Nên chọn công thức làm giảm số loại hàm xuất hiện.',
        keyIdeas: [
          'sin²x+cos²x=1.',
          'sin 2x=2sin x cos x.',
          'Đặt t=sin x hoặc cos x khi phương trình có cấu trúc bậc hai.'
        ],
      ),
    ],
    'g11-day-so-cap-so': [
      MathStudySection(
        title: '1. Dãy số và truy hồi',
        explanation:
            'Dãy số là một hàm xác định trên tập số tự nhiên. Công thức truy hồi mô tả số hạng sau từ một hoặc nhiều số hạng trước.',
        keyIdeas: [
          'Xác định rõ u₁ hay u₀.',
          'Tính vài số hạng đầu để phát hiện quy luật.',
          'Không suy ra công thức tổng quát chỉ từ hai số hạng.'
        ],
      ),
      MathStudySection(
        title: '2. Cấp số cộng',
        explanation:
            'Trong cấp số cộng, mỗi số hạng sau hơn số trước một lượng không đổi d. Đồ thị các số hạng theo n là các điểm thẳng hàng.',
        keyIdeas: [
          'uₙ=u₁+(n−1)d.',
          'Tổng dùng trung bình cộng số đầu và số cuối.',
          'Số hạng giữa là trung bình cộng hai số cách đều.'
        ],
        workedExample: [
          'Dãy 3,7,11,... có d=4.',
          'u₁₀=3+9·4=39.',
          'S₁₀=10(3+39)/2=210.'
        ],
      ),
      MathStudySection(
        title: '3. Cấp số nhân và tăng trưởng',
        explanation:
            'Cấp số nhân phù hợp với mô hình tăng theo phần trăm, lãi suất hoặc khấu hao. Tỉ số q cần được xác định theo cùng một đơn vị thời gian.',
        keyIdeas: [
          'uₙ=u₁qⁿ⁻¹.',
          'q>1 biểu thị tăng theo tỉ lệ.',
          'Tổng cấp số nhân cần tách trường hợp q=1.'
        ],
      ),
    ],
    'g11-gioi-han-lien-tuc': [
      MathStudySection(
        title: '1. Ý nghĩa của giới hạn',
        explanation:
            'Giới hạn mô tả xu hướng của hàm khi biến tiến gần một giá trị hoặc ra vô cực. Nó không nhất thiết bằng giá trị hàm tại điểm đang xét.',
        keyIdeas: [
          'Thế trực tiếp nếu biểu thức liên tục tại điểm.',
          'Dạng 0/0 cần biến đổi trước.',
          'Giới hạn một bên quan trọng tại điểm gián đoạn.'
        ],
        workedExample: [
          'lim(x→2)(x²−4)/(x−2) có dạng 0/0.',
          'Phân tích x²−4=(x−2)(x+2).',
          'Rút gọn rồi nhận giới hạn bằng 4.'
        ],
      ),
      MathStudySection(
        title: '2. Hàm số liên tục',
        explanation:
            'Liên tục tại a nghĩa là đồ thị không bị đứt tại a theo nghĩa giới hạn. Với hàm từng đoạn, phải so sánh giới hạn trái, phải và giá trị tại điểm nối.',
        keyIdeas: [
          'lim trái = lim phải là điều kiện tồn tại giới hạn.',
          'Giá trị hàm tại điểm nối phải được kiểm tra riêng.',
          'Đa thức liên tục trên R.'
        ],
      ),
      MathStudySection(
        title: '3. Kỹ thuật tính giới hạn',
        explanation:
            'Phân tích nhân tử, nhân liên hợp và chia cho lũy thừa cao nhất là ba kỹ thuật cốt lõi. Chọn kỹ thuật theo dạng vô định xuất hiện.',
        keyIdeas: [
          '0/0: phân tích hoặc liên hợp.',
          '∞/∞: chia cho lũy thừa lớn nhất.',
          'Biểu thức chứa căn: ưu tiên liên hợp.'
        ],
      ),
    ],
    'g11-hinh-hoc-khong-gian': [
      MathStudySection(
        title: '1. Vị trí tương đối',
        explanation:
            'Trong không gian, hai đường thẳng có thể cắt nhau, song song hoặc chéo nhau. Hai mặt phẳng có thể cắt nhau theo giao tuyến hoặc song song.',
        keyIdeas: [
          'Muốn chứng minh hai đường chéo nhau, cần loại trừ cắt và song song.',
          'Giao tuyến là đường chung của hai mặt phẳng.',
          'Một điểm và một đường đủ xác định một mặt phẳng nếu điểm không thuộc đường.'
        ],
      ),
      MathStudySection(
        title: '2. Quan hệ vuông góc',
        explanation:
            'Để chứng minh đường thẳng vuông góc mặt phẳng, tìm hai đường cắt nhau trong mặt phẳng và chứng minh vuông góc với cả hai.',
        keyIdeas: [
          'Định lý ba đường vuông góc giúp chuyển từ không gian về hình chiếu.',
          'Mặt phẳng trung trực gồm các điểm cách đều hai đầu đoạn.',
          'Góc giữa đường và mặt dùng hình chiếu.'
        ],
        workedExample: [
          'Cho d vuông góc a và b, trong đó a,b cắt nhau thuộc (P).',
          'Theo định lý, d vuông góc (P).',
          'Từ đó suy ra d vuông góc mọi đường trong (P) đi qua chân giao thích hợp.'
        ],
      ),
      MathStudySection(
        title: '3. Góc và khoảng cách',
        explanation:
            'Bài toán không gian thường cần dựng hình chiếu hoặc tìm đoạn vuông góc chung. Hãy xác định đối tượng cần đo trước khi chọn công thức.',
        keyIdeas: [
          'Khoảng cách điểm–mặt là đoạn vuông góc.',
          'Khoảng cách hai mặt phẳng song song lấy từ điểm bất kỳ trên mặt này.',
          'Thể tích thường quy về diện tích đáy và chiều cao.'
        ],
      ),
    ],
    'g11-thong-ke-xac-suat': [
      MathStudySection(
        title: '1. Đặc trưng trung tâm',
        explanation:
            'Trung bình, trung vị và mốt cung cấp các góc nhìn khác nhau về vị trí điển hình của dữ liệu. Không nên dùng một chỉ số duy nhất cho mọi tình huống.',
        keyIdeas: [
          'Trung bình dùng mọi giá trị.',
          'Trung vị ít bị ảnh hưởng bởi ngoại lệ.',
          'Mốt là giá trị xuất hiện nhiều nhất.'
        ],
      ),
      MathStudySection(
        title: '2. Độ phân tán',
        explanation:
            'Khoảng biến thiên, phương sai và độ lệch chuẩn cho biết dữ liệu trải rộng thế nào quanh trung tâm. Hai nhóm có cùng trung bình vẫn có thể rất khác mức ổn định.',
        keyIdeas: [
          'Độ lệch chuẩn cùng đơn vị với dữ liệu.',
          'Phương sai không âm.',
          'Ngoại lệ có thể làm trung bình và phương sai tăng mạnh.'
        ],
      ),
      MathStudySection(
        title: '3. Xác suất có điều kiện',
        explanation:
            'Khi biết B đã xảy ra, không gian mẫu được thu hẹp còn B. Đây là cách đọc đúng của P(A|B), không phải phép chia tùy ý.',
        keyIdeas: [
          'P(A|B)=P(A∩B)/P(B).',
          'Độc lập nghĩa là biết B không làm đổi xác suất A.',
          'Sơ đồ cây giúp kiểm soát thứ tự điều kiện.'
        ],
      ),
    ],
    'g12-ung-dung-dao-ham': [
      MathStudySection(
        title: '1. Đạo hàm và biến thiên',
        explanation:
            'Đạo hàm biểu diễn tốc độ thay đổi tức thời. Dấu của đạo hàm cho biết hàm đang tăng hay giảm trên từng khoảng.',
        keyIdeas: [
          'f′>0: hàm đồng biến; f′<0: hàm nghịch biến.',
          'Điểm f′=0 chỉ là điểm tới hạn, chưa chắc là cực trị.',
          'Cần xét cả điểm không xác định nếu chúng chia miền.'
        ],
        workedExample: [
          'f(x)=x³−3x²+2 có f′(x)=3x(x−2).',
          'Bảng dấu f′ cho biết các khoảng tăng giảm.',
          'So sánh dấu hai phía của 0 và 2 để kết luận cực trị.'
        ],
      ),
      MathStudySection(
        title: '2. Khảo sát và phác họa đồ thị',
        explanation:
            'Một bài khảo sát đầy đủ gồm tập xác định, giới hạn, tiệm cận, đạo hàm, cực trị, bảng biến thiên và giao điểm. Các bước cần được trình bày theo thứ tự.',
        keyIdeas: [
          'Tiệm cận đứng thường xuất hiện tại điểm làm mẫu bằng 0.',
          'Tiệm cận ngang dựa vào giới hạn ở vô cực.',
          'Giao trục giúp kiểm tra phác họa.'
        ],
      ),
      MathStudySection(
        title: '3. Tiếp tuyến và tối ưu',
        explanation:
            'Tiếp tuyến là xấp xỉ tuyến tính gần điểm tiếp xúc. Bài toán tối ưu cần đưa đại lượng cần tìm về một hàm một biến rồi xét cực trị trên miền phù hợp.',
        keyIdeas: [
          'Hệ số góc tiếp tuyến là f′(x₀).',
          'Cực trị trong miền đóng cần so sánh cả biên.',
          'Kết luận phải gắn với đại lượng thực tế.'
        ],
      ),
    ],
    'g12-nguyen-ham-tich-phan': [
      MathStudySection(
        title: '1. Họ nguyên hàm',
        explanation:
            'Nguyên hàm của f là hàm F có F′=f. Khi tìm nguyên hàm, hằng số C là bắt buộc vì có vô số hàm cùng đạo hàm.',
        keyIdeas: [
          'Tách tổng và đưa hằng số ra ngoài dấu tích phân.',
          'Đổi biến khi thấy hàm hợp cùng đạo hàm của phần trong.',
          'Từng phần phù hợp với tích của hai loại hàm.'
        ],
        workedExample: [
          '∫(2x+1)³·2dx: đặt u=2x+1.',
          'Khi đó du=2dx và tích phân thành ∫u³du.',
          'Kết quả là u⁴/4+C rồi thay u trở lại.'
        ],
      ),
      MathStudySection(
        title: '2. Tích phân xác định',
        explanation:
            'Tích phân xác định là hiệu F(b)−F(a), không phụ thuộc hằng số C. Tính chất đổi cận và cộng đoạn giúp chia bài toán phức tạp thành phần nhỏ.',
        keyIdeas: [
          'Đổi cận làm đổi dấu.',
          '∫ₐᵃf=0.',
          'Nếu f≥0 trên đoạn thì tích phân không âm.'
        ],
      ),
      MathStudySection(
        title: '3. Diện tích và thể tích',
        explanation:
            'Diện tích giữa hai đồ thị là tích phân của hàm trên trừ hàm dưới. Nếu thứ tự đổi trên đoạn, phải chia tại giao điểm.',
        keyIdeas: [
          'Tìm giao điểm trước khi lập cận.',
          'Dùng giá trị tuyệt đối hoặc chia đoạn để diện tích dương.',
          'Thể tích tròn xoay quanh Ox dùng π∫[f(x)]²dx trong mô hình phù hợp.'
        ],
      ),
    ],
    'g12-hinh-hoc-toa-do': [
      MathStudySection(
        title: '1. Hệ tọa độ trong không gian',
        explanation:
            'Mỗi điểm được xác định bởi ba tọa độ. Vectơ trong không gian có ba thành phần và các phép tính được mở rộng tương tự mặt phẳng.',
        keyIdeas: [
          'AB=(xB−xA;yB−yA;zB−zA).',
          'Độ dài dùng tổng ba bình phương.',
          'Tích vô hướng bằng tổng tích các thành phần tương ứng.'
        ],
      ),
      MathStudySection(
        title: '2. Mặt phẳng và đường thẳng',
        explanation:
            'Mặt phẳng được xác định bởi một điểm và một vectơ pháp tuyến. Đường thẳng được xác định bởi một điểm và vectơ chỉ phương.',
        keyIdeas: [
          'Thay tọa độ điểm vào để kiểm tra thuộc mặt.',
          'Hai vectơ pháp tuyến cùng phương cho hai mặt song song hoặc trùng.',
          'Giải hệ để tìm giao điểm hoặc giao tuyến.'
        ],
        workedExample: [
          'Mặt phẳng qua A(1;0;2) có pháp tuyến n=(2;−1;1).',
          'Dùng n·AM=0 với M(x;y;z).',
          'Thu được 2(x−1)−y+(z−2)=0.'
        ],
      ),
      MathStudySection(
        title: '3. Mặt cầu, góc và khoảng cách',
        explanation:
            'Mặt cầu gắn với khoảng cách từ điểm đến tâm. Các bài góc/khoảng cách được quy về tích vô hướng, hình chiếu hoặc khoảng cách điểm–mặt.',
        keyIdeas: [
          'Bán kính là khoảng cách tâm đến mọi điểm trên mặt cầu.',
          'Góc giữa hai đường dùng vectơ chỉ phương.',
          'Khoảng cách luôn lấy trị tuyệt đối ở tử số.'
        ],
      ),
    ],
    'g12-so-phuc': [
      MathStudySection(
        title: '1. Dạng đại số',
        explanation:
            'Số phức z=a+bi gồm phần thực a và phần ảo b. Quy tắc bằng nhau cho phép tách một phương trình phức thành hai phương trình thực.',
        keyIdeas: [
          'i²=−1.',
          'Re(z)=a, Im(z)=b.',
          'Hai số phức bằng nhau khi cùng phần thực và phần ảo.'
        ],
        workedExample: [
          '(2+3i)+(1−5i)=3−2i.',
          'Phần thực cộng với phần thực, phần ảo cộng với phần ảo.',
          'Kiểm tra lại bằng cách thay i² chỉ khi có phép nhân.'
        ],
      ),
      MathStudySection(
        title: '2. Liên hợp và môđun',
        explanation:
            'Liên hợp của a+bi là a−bi. Tích một số phức với liên hợp của nó là số thực không âm, giúp xử lý phép chia và hình học.',
        keyIdeas: [
          'z·z̄=|z|².',
          '|z| là khoảng cách từ điểm biểu diễn đến O.',
          'Phương trình |z−z₀|=R là đường tròn tâm z₀ bán kính R.'
        ],
      ),
      MathStudySection(
        title: '3. Phương trình số phức',
        explanation:
            'Có thể giải bằng dạng đại số, đặt ẩn thực–ảo hoặc chuyển sang môđun/hình học. Hãy kiểm tra nghiệm bằng cách thay ngược vào phương trình.',
        keyIdeas: [
          'Khử mẫu bằng liên hợp.',
          'Tách phần thực và phần ảo.',
          'Đọc tập nghiệm hình học khi đề cho môđun.'
        ],
      ),
    ],
    'g12-xac-suat-ung-dung': [
      MathStudySection(
        title: '1. Biến ngẫu nhiên rời rạc',
        explanation:
            'Biến ngẫu nhiên gán một giá trị số cho mỗi kết quả của phép thử. Bảng phân bố ghi rõ giá trị và xác suất đi kèm.',
        keyIdeas: [
          'Mỗi xác suất không âm.',
          'Tổng các xác suất bằng 1.',
          'Có thể dùng bảng hoặc sơ đồ cây để mô tả.'
        ],
      ),
      MathStudySection(
        title: '2. Kỳ vọng và phương sai',
        explanation:
            'Kỳ vọng là trung bình có trọng số; phương sai đo mức độ phân tán quanh kỳ vọng. Hai đại lượng này hỗ trợ đánh giá trò chơi hoặc rủi ro.',
        keyIdeas: [
          'E(X)=Σxᵢpᵢ.',
          'Var(X)=E(X²)−E(X)².',
          'Độ lệch chuẩn là căn phương sai.'
        ],
        workedExample: [
          'Trò chơi nhận 0 điểm xác suất 1/2 và 10 điểm xác suất 1/2.',
          'E(X)=0·1/2+10·1/2=5.',
          '5 là mức trung bình dài hạn, không phải điểm chắc chắn mỗi lượt.'
        ],
      ),
      MathStudySection(
        title: '3. Đọc dữ liệu và ra quyết định',
        explanation:
            'Kết quả xác suất cần được diễn giải trong bối cảnh. Khi đọc bảng hoặc biểu đồ, hãy phân biệt tần số, tần suất, giá trị trung tâm và độ phân tán.',
        keyIdeas: [
          'Không suy ra nguyên nhân chỉ từ tương quan.',
          'So sánh cùng đơn vị và cùng quy mô mẫu.',
          'Nêu rõ giới hạn của dữ liệu khi kết luận.'
        ],
      ),
    ],
  };

  static List<MathStudySection> forLesson(String id) =>
      sections[id] ?? const [];
}
