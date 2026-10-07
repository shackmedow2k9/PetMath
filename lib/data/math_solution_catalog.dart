class MathSolutionMethod {
  final String title;
  final String whenToUse;
  final List<String> steps;

  const MathSolutionMethod({
    required this.title,
    required this.whenToUse,
    required this.steps,
  });
}

class MathSolutionCatalog {
  static const Map<String, List<MathSolutionMethod>> _byLessonId = {
    'g10-menh-de-tap-hop': [
      MathSolutionMethod(
        title: 'Dạng 1: Xác định mệnh đề và phủ định',
        whenToUse:
            'Dùng khi đề yêu cầu xét đúng/sai, viết phủ định hoặc tìm điều kiện để câu chứa biến trở thành mệnh đề.',
        steps: [
          'Bước 1: Đọc câu khẳng định và xác định đối tượng đang được xét.',
          'Bước 2: Kiểm tra câu có một giá trị đúng hoặc sai xác định hay chưa; nếu còn biến tự do thì tìm điều kiện của biến.',
          'Bước 3: Khi phủ định, đổi “mọi” thành “tồn tại”, “tồn tại” thành “mọi” và đổi quan hệ đúng thành quan hệ đối lập.',
          'Bước 4: Kiểm tra lại bằng một phản ví dụ hoặc một giá trị cụ thể trước khi kết luận.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Phép toán trên tập hợp',
        whenToUse:
            'Dùng khi các tập được cho bằng khoảng, đoạn, điều kiện hoặc biểu đồ Ven.',
        steps: [
          'Bước 1: Đưa mỗi tập về cùng một cách biểu diễn, ưu tiên khoảng/đoạn trên trục số.',
          'Bước 2: Xác định phần chung để tính giao, toàn bộ vùng để tính hợp và phần còn lại để tính hiệu.',
          'Bước 3: Kiểm tra riêng các đầu mút bằng cách thay trực tiếp vào điều kiện.',
          'Bước 4: Viết kết quả theo đúng quy ước ngoặc tròn, ngoặc vuông và hợp các khoảng rời nhau.',
        ],
      ),
    ],
    'g10-bat-phuong-trinh': [
      MathSolutionMethod(
        title: 'Dạng 1: Bất phương trình bậc nhất',
        whenToUse:
            'Dùng khi ẩn chỉ xuất hiện ở bậc nhất và không có mẫu chứa ẩn.',
        steps: [
          'Bước 1: Thu gọn và chuyển các hạng tử chứa ẩn về một vế, hằng số về vế còn lại.',
          'Bước 2: Chia cho hệ số của ẩn; nếu hệ số âm thì đổi chiều bất đẳng thức.',
          'Bước 3: Biểu diễn nghiệm trên trục số và đổi sang khoảng/đoạn.',
          'Bước 4: Thử một giá trị trong miền nghiệm để kiểm tra chiều bất đẳng thức.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Tích, thương và tam thức bậc hai',
        whenToUse:
            'Dùng khi biểu thức đã phân tích được thành các nhân tử hoặc có dạng A(x)/B(x).',
        steps: [
          'Bước 1: Tìm tất cả nghiệm của tử số và mẫu số; loại các nghiệm làm mẫu bằng 0.',
          'Bước 2: Sắp xếp các điểm tới hạn trên trục số và lập bảng xét dấu từng nhân tử.',
          'Bước 3: Nhân các dấu để xác định dấu của toàn biểu thức trên từng khoảng.',
          'Bước 4: Chọn khoảng phù hợp với dấu >, <, ≥ hoặc ≤, chú ý nghiệm kép và điều kiện xác định.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 3: Hệ bất phương trình và bài toán tham số',
        whenToUse:
            'Dùng khi có nhiều bất phương trình hoặc cần tìm tham số để miền nghiệm thỏa một điều kiện.',
        steps: [
          'Bước 1: Giải riêng từng bất phương trình theo tham số nếu có.',
          'Bước 2: Lấy giao các miền nghiệm trên cùng một trục số.',
          'Bước 3: Chuyển yêu cầu về độ dài, số nguyên hoặc vị trí của giao thành điều kiện tham số.',
          'Bước 4: Kiểm tra các giá trị biên của tham số và kết luận theo đúng yêu cầu đề.',
        ],
      ),
    ],
    'g10-ham-so-do-thi': [
      MathSolutionMethod(
        title: 'Dạng 1: Khảo sát nhanh hàm số bậc hai',
        whenToUse:
            'Dùng khi cần tìm đỉnh, trục đối xứng, chiều biến thiên hoặc phác họa parabol.',
        steps: [
          'Bước 1: Xác định a, b, c và tính Δ.',
          'Bước 2: Tính đỉnh I(−b/(2a); −Δ/(4a)) và trục đối xứng x=−b/(2a).',
          'Bước 3: Dựa vào dấu của a để xác định parabol quay lên hay quay xuống.',
          'Bước 4: Tìm giao điểm với Ox, Oy nếu cần rồi nối các điểm đối xứng để vẽ đồ thị.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Giải phương trình, bất phương trình bằng đồ thị',
        whenToUse:
            'Dùng khi đề cho hoặc yêu cầu đọc số giao điểm giữa đồ thị và đường thẳng ngang.',
        steps: [
          'Bước 1: Đưa phương trình về dạng f(x)=g(x), sau đó xét giao điểm của y=f(x) và y=g(x).',
          'Bước 2: Đọc hoành độ các giao điểm để lấy nghiệm.',
          'Bước 3: Với bất phương trình, xác định đoạn đồ thị nằm trên hoặc dưới đồ thị đối chiếu.',
          'Bước 4: Kiểm tra đầu mút theo dấu lớn hơn, nhỏ hơn hoặc bằng.',
        ],
      ),
    ],
    'g10-vecto-toa-do': [
      MathSolutionMethod(
        title: 'Dạng 1: Tính tọa độ và độ dài vectơ',
        whenToUse:
            'Dùng khi đề cho tọa độ điểm và hỏi vectơ, trung điểm, trọng tâm hoặc khoảng cách.',
        steps: [
          'Bước 1: Viết vectơ theo công thức điểm cuối trừ điểm đầu.',
          'Bước 2: Tính độ dài bằng căn tổng bình phương các thành phần.',
          'Bước 3: Với trung điểm, lấy trung bình cộng từng tọa độ; với trọng tâm, lấy trung bình cộng ba đỉnh.',
          'Bước 4: Rút gọn căn và kiểm tra dấu của từng tọa độ.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Đường thẳng, vuông góc và khoảng cách',
        whenToUse:
            'Dùng khi cần lập phương trình đường thẳng, kiểm tra vuông góc/song song hoặc tính khoảng cách.',
        steps: [
          'Bước 1: Chọn vectơ chỉ phương hoặc vectơ pháp tuyến phù hợp với dữ kiện.',
          'Bước 2: Lập phương trình qua điểm đã biết và thay tọa độ để kiểm tra.',
          'Bước 3: Dùng tích vô hướng bằng 0 cho vuông góc hoặc định thức bằng 0 cho song song.',
          'Bước 4: Dùng công thức khoảng cách điểm–đường và lấy giá trị tuyệt đối ở tử số.',
        ],
      ),
    ],
    'g10-xac-suat-co-ban': [
      MathSolutionMethod(
        title: 'Dạng 1: Bài toán đếm',
        whenToUse:
            'Dùng khi đề hỏi số cách chọn, sắp xếp hoặc thực hiện nhiều công đoạn.',
        steps: [
          'Bước 1: Xác định đối tượng và xem thứ tự có quan trọng hay không.',
          'Bước 2: Nếu các lựa chọn loại trừ nhau thì dùng quy tắc cộng; nếu liên tiếp thì dùng quy tắc nhân.',
          'Bước 3: Dùng hoán vị khi sắp xếp toàn bộ, chỉnh hợp khi chọn có thứ tự, tổ hợp khi chọn không thứ tự.',
          'Bước 4: Kiểm tra trường hợp trùng hoặc thiếu bằng cách đếm theo một cách khác.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Tính xác suất cổ điển',
        whenToUse: 'Dùng khi các kết quả cơ bản đồng khả năng.',
        steps: [
          'Bước 1: Xây dựng không gian mẫu Ω và xác định số kết quả cơ bản.',
          'Bước 2: Mô tả biến cố A bằng điều kiện rõ ràng.',
          'Bước 3: Đếm số kết quả thuận lợi n(A), có thể dùng tổ hợp/chỉnh hợp.',
          'Bước 4: Tính P(A)=n(A)/n(Ω), sau đó kiểm tra kết quả nằm trong [0;1].',
        ],
      ),
    ],
    'g11-luong-giac': [
      MathSolutionMethod(
        title: 'Dạng 1: Đọc giá trị trên đường tròn lượng giác',
        whenToUse:
            'Dùng khi cần xác định dấu hoặc giá trị sin, cos, tan của góc đặc biệt.',
        steps: [
          'Bước 1: Đưa góc về góc chuẩn trong một vòng 2π và xác định góc phần tư.',
          'Bước 2: Ghi giá trị tuyệt đối theo góc liên quan và xác định dấu theo góc phần tư.',
          'Bước 3: Với tan hoặc cot, kiểm tra điều kiện mẫu khác 0.',
          'Bước 4: Đối chiếu lại bằng sin²x+cos²x=1 nếu cần.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Phương trình lượng giác cơ bản',
        whenToUse:
            'Dùng cho sin x=a, cos x=a, tan x=a hoặc phương trình đưa được về các dạng này.',
        steps: [
          'Bước 1: Đưa tất cả biểu thức về cùng một loại hàm nếu có thể.',
          'Bước 2: Chọn góc mẫu α sao cho sin α, cos α hoặc tan α bằng vế phải.',
          'Bước 3: Viết nghiệm tổng quát đúng dạng của sin, cos hoặc tan.',
          'Bước 4: Nếu đề cho khoảng, liệt kê các giá trị k nguyên và lọc nghiệm thuộc khoảng.',
        ],
      ),
    ],
    'g11-day-so-cap-so': [
      MathSolutionMethod(
        title: 'Dạng 1: Cấp số cộng',
        whenToUse:
            'Dùng khi hiệu hai số hạng liên tiếp không đổi hoặc dữ kiện mô tả tăng/giảm đều.',
        steps: [
          'Bước 1: Tìm u₁ và công sai d từ dữ kiện.',
          'Bước 2: Dùng uₙ=u₁+(n−1)d để tìm số hạng cần hỏi.',
          'Bước 3: Dùng Sₙ=n(u₁+uₙ)/2 nếu đề hỏi tổng.',
          'Bước 4: Thay ngược một số hạng vào công thức để kiểm tra.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Cấp số nhân và tăng trưởng',
        whenToUse:
            'Dùng khi đại lượng tăng theo cùng một tỉ lệ phần trăm hoặc có thương không đổi.',
        steps: [
          'Bước 1: Xác định số ban đầu u₁ và công bội q; đổi phần trăm về số thập phân.',
          'Bước 2: Dùng uₙ=u₁qⁿ⁻¹ để tìm giá trị ở kỳ n.',
          'Bước 3: Nếu cần tổng, tách trường hợp q=1 trước khi dùng công thức Sₙ.',
          'Bước 4: Kiểm tra đơn vị thời gian và xem q<1 có biểu thị giảm hay không.',
        ],
      ),
    ],
    'g11-gioi-han-lien-tuc': [
      MathSolutionMethod(
        title: 'Dạng 1: Giới hạn dạng 0/0',
        whenToUse: 'Dùng khi thế trực tiếp cho tử và mẫu cùng bằng 0.',
        steps: [
          'Bước 1: Thế giá trị giới hạn để nhận dạng dạng vô định.',
          'Bước 2: Phân tích nhân tử, rút gọn nhân tử chung hoặc nhân liên hợp.',
          'Bước 3: Thế lại sau khi biểu thức đã hết dạng 0/0.',
          'Bước 4: Ghi điều kiện điểm đang tiến tới nếu có mẫu hoặc căn.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Giới hạn ở vô cực',
        whenToUse: 'Dùng khi x tiến tới +∞ hoặc −∞ trong phân thức đa thức.',
        steps: [
          'Bước 1: Xác định bậc cao nhất của tử và mẫu.',
          'Bước 2: Chia cả tử và mẫu cho lũy thừa cao nhất của x.',
          'Bước 3: Cho các số hạng chứa 1/x, 1/x²,... tiến về 0.',
          'Bước 4: Kết luận giới hạn và tiệm cận ngang nếu có.',
        ],
      ),
    ],
    'g11-hinh-hoc-khong-gian': [
      MathSolutionMethod(
        title: 'Dạng 1: Chứng minh đường thẳng vuông góc mặt phẳng',
        whenToUse:
            'Dùng khi đường thẳng vuông góc với hai đường cắt nhau cùng nằm trong một mặt phẳng.',
        steps: [
          'Bước 1: Xác định mặt phẳng cần chứng minh và tìm hai đường cắt nhau trong mặt phẳng đó.',
          'Bước 2: Chứng minh đường thẳng đã cho vuông góc với đường thứ nhất.',
          'Bước 3: Chứng minh tiếp đường thẳng đó vuông góc với đường thứ hai.',
          'Bước 4: Áp dụng định lý để kết luận đường thẳng vuông góc mặt phẳng.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Tính góc và khoảng cách',
        whenToUse:
            'Dùng khi đề hỏi góc giữa đường và mặt, khoảng cách điểm–mặt hoặc khoảng cách hai mặt phẳng.',
        steps: [
          'Bước 1: Dựng hình chiếu vuông góc hoặc tìm đoạn vuông góc chung.',
          'Bước 2: Chuyển góc không gian về góc trong tam giác phẳng thích hợp.',
          'Bước 3: Dùng hệ thức lượng, diện tích hoặc thể tích để tính độ dài.',
          'Bước 4: Kiểm tra đoạn kết quả có là khoảng cách ngắn nhất và ghi đơn vị.',
        ],
      ),
    ],
    'g11-thong-ke-xac-suat': [
      MathSolutionMethod(
        title: 'Dạng 1: Tính trung bình, trung vị và mốt',
        whenToUse:
            'Dùng khi đề yêu cầu tìm đặc trưng trung tâm của bảng số liệu hoặc bảng tần số.',
        steps: [
          'Bước 1: Sắp xếp dữ liệu nếu cần và xác định tần số của từng giá trị.',
          'Bước 2: Tính trung bình bằng tổng giá trị nhân tần số chia tổng tần số.',
          'Bước 3: Tìm trung vị theo vị trí giữa của dãy đã sắp xếp.',
          'Bước 4: Chọn mốt là giá trị có tần số lớn nhất và nêu rõ nếu có nhiều mốt.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Phương sai, độ lệch chuẩn và xác suất có điều kiện',
        whenToUse:
            'Dùng khi cần đo độ phân tán hoặc cập nhật xác suất sau khi biết một biến cố đã xảy ra.',
        steps: [
          'Bước 1: Tính trung bình trước để làm mốc so sánh.',
          'Bước 2: Tính phương sai bằng trung bình của bình phương độ lệch.',
          'Bước 3: Lấy căn bậc hai phương sai để được độ lệch chuẩn cùng đơn vị dữ liệu.',
          'Bước 4: Với xác suất có điều kiện, thu hẹp không gian mẫu về B rồi dùng P(A|B)=P(A∩B)/P(B).',
        ],
      ),
    ],
    'g12-ung-dung-dao-ham': [
      MathSolutionMethod(
        title: 'Dạng 1: Xét đơn điệu và cực trị',
        whenToUse:
            'Dùng khi cần lập bảng biến thiên, tìm khoảng tăng giảm hoặc điểm cực trị.',
        steps: [
          'Bước 1: Tìm tập xác định và tính đạo hàm f′(x).',
          'Bước 2: Giải f′(x)=0 và tìm thêm các điểm f′ không xác định nhưng thuộc miền xét.',
          'Bước 3: Lập bảng dấu f′ trên các khoảng được chia bởi các điểm tới hạn.',
          'Bước 4: Đọc khoảng đồng biến/nghịch biến; điểm đổi dấu từ + sang − là cực đại, từ − sang + là cực tiểu.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Khảo sát và phác họa đồ thị',
        whenToUse:
            'Dùng cho bài khảo sát hàm số đầy đủ hoặc cần xác định tiệm cận và giao điểm.',
        steps: [
          'Bước 1: Viết tập xác định và tính các giới hạn ở biên miền xác định, ở vô cực.',
          'Bước 2: Tìm tiệm cận đứng, ngang hoặc xiên nếu có.',
          'Bước 3: Tính đạo hàm, lập bảng biến thiên và xác định cực trị.',
          'Bước 4: Tìm giao với Ox, Oy, chọn một vài điểm kiểm tra rồi vẽ đồ thị theo bảng biến thiên.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 3: Tiếp tuyến và tối ưu',
        whenToUse:
            'Dùng khi tìm tiếp tuyến hoặc giá trị lớn nhất/nhỏ nhất của đại lượng thực tế.',
        steps: [
          'Bước 1: Với tiếp tuyến, xác định điểm tiếp xúc x₀ và tính f′(x₀).',
          'Bước 2: Viết y=f′(x₀)(x−x₀)+f(x₀).',
          'Bước 3: Với tối ưu, biểu diễn đại lượng cần tối ưu thành hàm một biến trên miền phù hợp.',
          'Bước 4: Tính đạo hàm, xét điểm tới hạn và so sánh cả hai đầu mút nếu miền đóng.',
        ],
      ),
    ],
    'g12-nguyen-ham-tich-phan': [
      MathSolutionMethod(
        title: 'Dạng 1: Tính nguyên hàm',
        whenToUse: 'Dùng khi cần tìm F(x) sao cho F′(x)=f(x).',
        steps: [
          'Bước 1: Tách tổng, đưa hằng số ra ngoài và đưa biểu thức về các dạng cơ bản.',
          'Bước 2: Dùng công thức lũy thừa, mũ, lượng giác hoặc đổi biến nếu là hàm hợp.',
          'Bước 3: Nếu có tích hai hàm, cân nhắc phương pháp từng phần.',
          'Bước 4: Luôn thêm hằng số C và lấy đạo hàm kiểm tra kết quả.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Tích phân xác định',
        whenToUse: 'Dùng khi đề cho cận a,b và yêu cầu tính giá trị tích phân.',
        steps: [
          'Bước 1: Tìm một nguyên hàm F của hàm dưới dấu tích phân.',
          'Bước 2: Áp dụng ∫ₐᵇf(x)dx=F(b)−F(a); không cần viết C trong phép tính cuối.',
          'Bước 3: Rút gọn chính xác rồi kiểm tra dấu của kết quả theo tính chất hàm.',
          'Bước 4: Nếu đổi biến, đổi cả cận hoặc đổi ngược về biến cũ trước khi thế.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 3: Diện tích và thể tích',
        whenToUse:
            'Dùng khi tính diện tích giới hạn bởi đồ thị hoặc thể tích khối tròn xoay.',
        steps: [
          'Bước 1: Tìm giao điểm để xác định cận và xem hàm nào nằm trên.',
          'Bước 2: Nếu thứ tự hai đồ thị đổi, chia đoạn tại giao điểm hoặc dùng giá trị tuyệt đối.',
          'Bước 3: Lập tích phân diện tích S=∫(hàm trên−hàm dưới)dx.',
          'Bước 4: Với thể tích, xác định trục quay và dùng công thức lát cắt phù hợp.',
        ],
      ),
    ],
    'g12-hinh-hoc-toa-do': [
      MathSolutionMethod(
        title: 'Dạng 1: Lập phương trình mặt phẳng',
        whenToUse:
            'Dùng khi biết một điểm và vectơ pháp tuyến, hoặc biết ba điểm không thẳng hàng.',
        steps: [
          'Bước 1: Tìm vectơ pháp tuyến n=(A;B;C) từ dữ kiện vuông góc hoặc tích có hướng.',
          'Bước 2: Dùng điều kiện n·AM=0 với M(x;y;z).',
          'Bước 3: Khai triển và thu phương trình Ax+By+Cz+D=0.',
          'Bước 4: Thay lại điểm đã cho để kiểm tra mặt phẳng đi qua điểm đó.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Đường thẳng, giao điểm và khoảng cách',
        whenToUse:
            'Dùng khi cần lập đường thẳng, tìm giao với mặt phẳng hoặc tính khoảng cách trong Oxyz.',
        steps: [
          'Bước 1: Chọn điểm đi qua và vectơ chỉ phương của đường thẳng.',
          'Bước 2: Viết phương trình tham số hoặc chính tắc.',
          'Bước 3: Tìm giao bằng cách thế tham số vào phương trình mặt phẳng hoặc giải hệ.',
          'Bước 4: Dùng công thức khoảng cách điểm–mặt; với hai đường chéo nhau, tìm vectơ chung và dùng tích hỗn tạp.',
        ],
      ),
    ],
    'g12-so-phuc': [
      MathSolutionMethod(
        title: 'Dạng 1: Phép tính đại số với số phức',
        whenToUse: 'Dùng khi cộng, trừ, nhân, chia hoặc tìm phần thực/phần ảo.',
        steps: [
          'Bước 1: Đưa mọi số phức về dạng a+bi và thay i²=−1 khi khai triển.',
          'Bước 2: Gom riêng phần thực và phần chứa i.',
          'Bước 3: Với phép chia, nhân cả tử và mẫu với số phức liên hợp của mẫu.',
          'Bước 4: Đọc Re(z), Im(z) sau khi rút gọn về dạng chuẩn.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Môđun và biểu diễn hình học',
        whenToUse:
            'Dùng khi đề có |z−z₀|, số phức liên hợp hoặc yêu cầu mô tả tập điểm.',
        steps: [
          'Bước 1: Viết z=x+yi và chuyển môđun về khoảng cách trong mặt phẳng phức.',
          'Bước 2: Nhận dạng đường tròn, đường thẳng hoặc miền giới hạn bởi bất đẳng thức.',
          'Bước 3: Dùng z·z̄=|z|² để biến đổi đại số nếu cần.',
          'Bước 4: Kiểm tra điểm biên và mô tả tập điểm bằng hình học.',
        ],
      ),
    ],
    'g12-xac-suat-ung-dung': [
      MathSolutionMethod(
        title: 'Dạng 1: Lập bảng phân bố của biến ngẫu nhiên',
        whenToUse:
            'Dùng khi mỗi kết quả của phép thử được gán một giá trị số và cần lập bảng X, P(X=x).',
        steps: [
          'Bước 1: Liệt kê các kết quả cơ bản và giá trị X tương ứng.',
          'Bước 2: Gom các kết quả cho cùng một giá trị X.',
          'Bước 3: Tính xác suất của từng giá trị và kiểm tra tổng bằng 1.',
          'Bước 4: Trình bày bảng theo thứ tự tăng của x để tránh bỏ sót.',
        ],
      ),
      MathSolutionMethod(
        title: 'Dạng 2: Kỳ vọng, phương sai và quyết định',
        whenToUse:
            'Dùng khi so sánh trò chơi, lợi nhuận, rủi ro hoặc mức điểm trung bình dài hạn.',
        steps: [
          'Bước 1: Viết đầy đủ các cặp giá trị xi và xác suất pi.',
          'Bước 2: Tính E(X)=Σxi pi.',
          'Bước 3: Tính E(X²)=Σxi²pi rồi suy ra Var(X)=E(X²)−E(X)².',
          'Bước 4: So sánh kỳ vọng để đánh giá mức trung bình và độ lệch chuẩn để đánh giá độ ổn định.',
        ],
      ),
    ],
  };

  static List<MathSolutionMethod> forLesson(String lessonId) =>
      _byLessonId[lessonId] ?? const [];
}
