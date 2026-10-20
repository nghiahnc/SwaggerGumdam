# Voucher, đánh giá và thanh toán (FL-13 · FL-14 · FL-15)

Phần việc của **Trần Hiếu Nghĩa** theo bảng phân công Flutter PRM393 của nhóm (`PhanCong_Flutter_PRM393.xlsx`, nằm ngoài repo; bảng API PRN232 là phân công riêng): hai màn hình chính `VouchersScreen`, `ReviewsScreen` và màn bổ sung `PaymentScreen`. Ba màn hình giữ đúng file trong bảng phân công; logic kiểm tra được tách ra `lib/core/*_policy.dart` để unit test chạy không cần server.

| Task | Màn hình | Ai dùng, vào từ đâu | API |
| --- | --- | --- | --- |
| FL-13 | `VouchersScreen` · `lib/screens/vouchers.dart` | Admin · tab **Quản trị** → **Voucher** | `GET /api/v1/vouchers`, `GET /api/v1/vouchers/{id}`, `POST /api/v1/vouchers`, `PUT/DELETE /api/v1/vouchers/{id}` (chỉ Admin) |
| FL-14 | `ReviewsScreen` · `lib/screens/reviews.dart` | Mọi người · chi tiết sản phẩm → **Đánh giá sau mua** | `GET /api/v1/products/{id}/reviews`; `POST/PUT/DELETE /api/v1/reviews` (cần đăng nhập) |
| FL-15 | `PaymentScreen` · `lib/screens/payment.dart` | Khách · chi tiết đơn chờ thanh toán → **Thanh toán** (nút chỉ hiện với người đặt đơn) | `GET /api/v1/orders/{id}`; `POST /api/v1/payments/orders/{id}/session`; `POST /api/v1/payments/mock/orders/{id}/complete` (chỉ Development) |

## 1. Cách làm chung

- Màn hình đọc dữ liệu qua `ShopRepository` → `ApiClient`, hiển thị bằng `AsyncPanel` (đang tải / lỗi + Thử lại / dữ liệu).
- Form thêm/sửa tự gửi request qua `onSubmit` và **chỉ đóng khi thành công**. Khi API từ chối, form vẫn mở, giữ dữ liệu đã gõ và hiện lý do (ví dụ "Mã voucher đã tồn tại.").
- Lỗi hiện sau lần bấm Lưu đầu tiên, rồi cập nhật theo từng lần sửa.
- Khi đang lưu, nút Lưu bị khóa và không đóng được form. Bấm ra ngoài form cũng không đóng, để không mất dữ liệu đang nhập. Khi đang xóa hoặc gửi kết quả mock, thanh tiến trình hiện dưới tiêu đề, còn menu và nút bị khóa; lúc gửi kết quả mock thì nút Back cũng bị khóa.
- Sau mỗi lần ghi, danh sách hoặc đơn hàng được đọc lại từ API, vì dữ liệu có thể đổi ở chỗ khác: checkout tăng lượt dùng voucher, thanh toán đổi trạng thái đơn.
- 401/403 không có nội dung được đổi thành câu dễ hiểu (`lib/core/error_text.dart`). Màn Thanh toán đổi lỗi 5xx (thông báo cấu hình dành cho lập trình viên) thành "Thanh toán đang tạm gián đoạn, hãy thử lại sau.". Các lỗi khác hiện đúng câu tiếng Việt API trả về.
- Form dùng lề hẹp trên điện thoại; dòng lỗi được xuống tối đa 3 dòng thay vì bị cắt.
- **Ngày giờ:** API trả ngày đọc từ SQL Server **không có hậu tố `Z`**, dù đó là giờ UTC. Ví dụ: tạo voucher thì nhận `2026-10-20T07:00:00Z`, nhưng đọc danh sách thì nhận `2026-10-20T07:00:00`. `parseUtc` trong `lib/core/dates.dart` đọc cả hai dạng là UTC. Nếu không, hạn voucher hiện sớm 7 tiếng và mỗi lần sửa lại bị lùi thêm 7 tiếng.

## 2. FL-13 · Voucher (Admin)

- **Quyền:** tab Quản trị chỉ hiện với Admin. Màn hình vẫn kiểm tra lại: người không phải Admin chỉ thấy "Chỉ tài khoản quản trị mới quản lý được voucher." và **không request nào được gửi**.
- **Danh sách:** đọc hết mọi trang của API (mỗi trang tối đa 100 mã), nên mã mới xếp cuối vẫn hiện. Mỗi voucher có mã, số tiền giảm, đơn tối thiểu, số lượt đã dùng/tối đa, thời gian `dd/MM/yyyy HH:mm` theo giờ máy, và nhãn trạng thái. Nhãn dùng đúng các điều kiện checkout kiểm tra (`ShoppingService`: đang hoạt động, đã bắt đầu, chưa kết thúc, còn lượt). Khi nhiều điều kiện cùng sai, nhãn lấy theo thứ tự trong bảng:

  | Trạng thái | Điều kiện |
  | --- | --- |
  | Ngừng sử dụng | `isActive = false` |
  | Hết hạn | bây giờ ≥ thời gian kết thúc |
  | Hết lượt | đã dùng ≥ số lượt tối đa |
  | Chưa bắt đầu | bây giờ < thời gian bắt đầu |
  | Đang áp dụng | các trường hợp còn lại |

  Đầu danh sách ghi rõ: số lượt đã dùng tính cả đơn đang chờ thanh toán (checkout giữ lượt ngay khi tạo đơn); đơn bị hủy, hết hạn hoặc thanh toán thất bại sẽ trả lại lượt. Vì vậy "Hết lượt" có thể chỉ là tạm thời.

- **Quy tắc form** (`lib/core/voucher_policy.dart`):

  | Trường | Quy tắc |
  | --- | --- |
  | Mã | Bắt buộc, tối đa 64 ký tự, tự bỏ khoảng trắng hai đầu và viết hoa giống API; chỉ chữ không dấu, số, `-`, `_` (quy ước app để khách gõ được) |
  | Số tiền giảm | Số nguyên 1 – 1.000.000.000 ₫ |
  | Đơn tối thiểu | Số nguyên 0 – 1.000.000.000 ₫ |
  | Số lượt tối đa | 1 – 1.000.000; khi sửa không nhỏ hơn số lượt đã dùng |
  | Mã khi sửa | Không đổi được khi voucher còn lượt đã dùng (`VoucherPolicy.canChangeCode`, tức `usedCount > 0`: có đơn chờ thanh toán hoặc đã thanh toán; đơn bị hủy, hết hạn hay thất bại đã trả lượt nên không tính). Đơn chỉ lưu mã định danh của voucher, nên đổi mã sẽ làm mã khách đang biết thành "Không tìm thấy voucher" và nhả mã cũ cho voucher khác. Khi bấm Sửa, app đọc lại voucher (`GET /api/v1/vouchers/{id}`) để dùng số lượt mới nhất; nếu đọc lỗi thì dùng bản trong danh sách, còn nếu voucher vừa bị ngừng thì không mở form mà báo "Voucher … đã ngừng sử dụng" và tải lại danh sách. API không có quy tắc khóa mã, nên gọi thẳng API (Swagger) vẫn đổi được mã |
  | Thời gian | Bắt đầu trước kết thúc; kết thúc phải sau hiện tại |

  Khi số tiền giảm từ đơn tối thiểu trở lên (`VoucherPolicy.makesOrdersFree`), form hiện cảnh báo "Lưu ý: đơn từ X ₫ đến Y ₫ sẽ được giảm còn 0 ₫." vì checkout giới hạn mức giảm bằng tiền hàng. Cảnh báo không chặn việc lưu, để vẫn tạo được voucher miễn phí có chủ ý.

  Các quy tắc chặt hơn API (mẫu mã, mức tối đa) chỉ áp dụng cho giá trị mới nhập. Voucher tạo từ nơi khác (ví dụ Swagger) với mã có dấu vẫn sửa được ngày mà không phải đổi mã.

  Ô voucher ở màn đặt hàng (`CheckoutScreen`, phần của Gia Đạt) dùng `validateVoucherCode`/`normalizeVoucherCode` trong cùng file: được bỏ trống, tối đa 64 ký tự, viết hoa giống form Admin. Mọi mã Admin tạo được đều gõ được ở đó.

- **Chọn ngày giờ:** toàn bộ bộ chọn là tiếng Việt (tên tháng, thứ, nút chuyển tháng), giờ luôn ở dạng 24 giờ như trên form. Gõ ngày bằng tay theo dạng `dd/mm/yyyy` (ngày trước). Bản dịch lấy từ `flutter_localizations` và chỉ áp dụng cho hai bộ chọn này.
- **Ngừng sử dụng** là xóa mềm (`IsActive = false`), có hộp xác nhận. Voucher đã ngừng không còn menu, vì API không có cách bật lại.

## 3. FL-14 · Đánh giá

- **Ai làm được gì:**
  - Ai cũng xem được.
  - Muốn viết phải đăng nhập. Khách chưa đăng nhập thấy nút "Đăng nhập để viết đánh giá".
  - Mỗi khách một đánh giá cho mỗi sản phẩm. Khi đã có, nút đổi thành "Sửa đánh giá của bạn"; đánh giá của mình nằm đầu danh sách.
  - Chỉ đánh giá của mình mới có Sửa/Xóa. Admin chỉ có Xóa trên đánh giá của khách, vì API cho Admin xóa nhưng không cho sửa.
  - Admin không có nút viết đánh giá mà thấy dòng "Tài khoản quản trị chỉ xóa được đánh giá của khách, không viết đánh giá." API vẫn nhận đánh giá của Admin nếu Admin tự đặt đơn và tự chuyển sang Đã giao; ẩn nút để đánh giá của cửa hàng không trông như của người mua.
- **Danh sách** đọc hết mọi trang của API, nên đánh giá của mình luôn được tìm thấy (kể cả khi cũ hơn 100 đánh giá mới nhất), và điểm trung bình, số lượt tính trên tất cả đánh giá.
- **Điều kiện viết** do API quyết định: phải có đơn **đã giao** chứa sản phẩm. Nếu chưa, API trả 403 "Chỉ được đánh giá sản phẩm đã nhận." và form hiện câu này.
- **Quy tắc form** (`lib/core/review_policy.dart`):
  - chọn 1–5 sao bằng cách bấm ngôi sao;
  - nhận xét bắt buộc, tối đa 1000 ký tự;
  - form rỗng báo lỗi cả hai trường và không gửi gì.
- **API từ chối:**
  - viết mới bị 409 "Bạn đã đánh giá sản phẩm." (đã đánh giá từ máy khác);
  - sửa bị 404 "Không tìm thấy đánh giá." (đánh giá không còn hoặc không phải của mình).

  Hai trường hợp này form hiện lý do và danh sách được đọc lại. Xóa bị từ chối thì snackbar hiện lý do và danh sách cũng được đọc lại.

## 4. FL-15 · Thanh toán

- Màn hình đọc đơn trước. Chỉ khi đơn còn **Chờ thanh toán** mới xin phiên thanh toán, vì API từ chối các đơn khác bằng 409.
- Mã đơn ghi dạng `#48A8D86D` và nhãn trạng thái lấy từ `lib/core/order_status.dart`, giống màn đơn hàng. Số tiền ghi "Cần thanh toán" khi đơn còn chờ, các trường hợp khác ghi "Tổng đơn".
- **Tiền đến khi đơn đã đóng:** nếu khách trả tiền sau khi đơn bị hủy, hết hạn hoặc đã thất bại, API giữ trạng thái đơn và đặt `paymentStatus = RefundRequired`. Màn thanh toán không báo "hủy", "thất bại" hay "hãy tạo đơn mới": nhãn trạng thái ghi "Cần hoàn tiền", kèm biểu tượng cảnh báo và câu "Cửa hàng đã nhận tiền nhưng đơn đã đóng trước khi tiền về, nên tiền sẽ được hoàn lại thủ công. Hãy liên hệ cửa hàng; không thanh toán lại đơn này." Câu này chỉ hiện khi khách còn ở màn thanh toán lúc tiền về (màn hình tự đọc lại khi quay về từ Stripe, hoặc khách bấm tải lại). Đơn đã đóng thì không mở lại được màn thanh toán, nên ở màn chi tiết đơn (phần của Gia Đạt) khách chỉ thấy gợi ý theo trạng thái đơn và dòng Thanh toán – "Cần hoàn tiền".
- Nếu API vẫn từ chối mở phiên:
  - 409: màn hình đọc lại đơn. Đơn đã đổi trạng thái (đã trả qua Stripe, hết hạn) thì hiện trạng thái mới; đơn vẫn chờ (Stripe: "Đơn sắp hết hạn, hãy tạo đơn mới.") thì hiện thông tin đơn kèm lý do;
  - 404 "Không tìm thấy đơn hàng." (Admin mở màn thanh toán cho đơn của khách: đọc được đơn nhưng API chỉ cho chủ đơn mở phiên; từ chi tiết đơn thì không gặp, vì nút Thanh toán chỉ hiện với chủ đơn) và lỗi 5xx: vẫn hiện thông tin đơn kèm lý do. Khách mở đơn của người khác thì ngay lần đọc đơn đã bị 404, màn hình hiện lỗi và nút Thử lại.
- Với provider Stripe, đơn 0 ₫ được API đánh dấu đã thanh toán ngay khi mở phiên; màn hình hiện luôn kết quả thành công. Với Mock (Development), đơn 0 ₫ vẫn hiện hai nút mô phỏng.
- **Mock** (backend ở Development):
  - hai nút "Mô phỏng thanh toán thành công" và "Mô phỏng thanh toán thất bại";
  - sau khi gửi, màn hình **đọc lại đơn** và hiện trạng thái API báo: *Đã thanh toán*, hoặc *Thanh toán thất bại* kèm việc tồn kho và lượt voucher đã được hoàn;
  - có nút "Quay lại đơn hàng", và màn chi tiết đơn cũng tải lại.
- **Stripe:**
  - nút "Mở Stripe Checkout" mở trang thanh toán bằng `url_launcher`;
  - đơn chỉ đổi trạng thái khi Stripe gọi webhook về backend, nên có nút "Tôi đã thanh toán, tải lại trạng thái". Nếu đơn vẫn chờ, app báo "Chưa nhận được kết quả từ Stripe…";
  - sau khi đã mở Stripe Checkout, mỗi lần khách quay lại app (`AppLifecycleListener`, khi app hoạt động trở lại) màn hình tự đọc lại đơn. Lần đọc này không hiện vòng xoay hay thông báo, vì trên web và máy tính sự kiện này xảy ra mỗi khi cửa sổ được chọn lại; khi đơn không còn chờ thanh toán thì thôi đọc;
  - backend cần `Payments:Provider = Stripe`, test key, SuccessUrl/CancelUrl và webhook secret.

## 5. Kiểm thử

| File | Loại | Số test | Ứng với "Kiểm thử tối thiểu" |
| --- | --- | --- | --- |
| `test/voucher_policy_test.dart` | Unit | 14 | Ngày sai, voucher hết hạn (ranh giới bắt đầu/kết thúc), mã, số tiền, lượt; đọc ngày UTC; voucher làm đơn thành 0 ₫; khóa mã sau khi đã dùng |
| `test/review_payment_policy_test.dart` | Unit | 9 | Form rỗng, sửa/xóa của người khác; nhãn kết quả thanh toán; nhãn trạng thái đơn giống màn đơn hàng; tiền đến khi đơn đã đóng |
| `test/vouchers_screen_test.dart` | Widget | 24 | Quyền Admin (không gửi request; 403), voucher hết hạn và ngày hiển thị theo giờ máy, ngày sai, mã trùng (409), thêm (gửi đủ mức giảm và đơn tối thiểu), sửa (PUT giữ nguyên thời điểm), lượt tối đa không dưới số đã dùng, voucher có mã cũ, không đóng form khi đang lưu, ngừng sử dụng, danh sách rỗng, dòng lỗi được xuống dòng, bộ chọn ngày giờ tiếng Việt và 24 giờ, ngày gõ tay đọc theo ngày trước, cảnh báo đơn 0 ₫, khóa mã đã dùng (kể cả khi danh sách đã cũ), ghi chú lượt giữ bởi đơn chờ, đọc mã thứ 101 ở trang 2, mã mới xuất hiện giữa hai trang, trang thiếu `totalCount`, voucher vừa bị ngừng không mở form sửa |
| `test/reviews_screen_test.dart` | Widget | 17 | Đánh giá trước giao (403), sửa/xóa của người khác, form rỗng (cả trường hợp chỉ thiếu số sao), viết, sửa, xóa (danh sách cập nhật), 404 khi sửa, 409 khi viết, xóa bị từ chối, danh sách rỗng, 5 ngôi sao trên một dòng ở màn 320px, Admin không có nút viết (nhưng vẫn sửa được đánh giá đã có của mình), đánh giá của mình nằm sau 100 đánh giá mới nhất |
| `test/payment_screen_test.dart` | Widget | 22 | Hai kết quả mock, tải lại trạng thái đơn sau thanh toán, đơn không còn chờ, mock bị từ chối, đơn 0 ₫, phiên bị từ chối (409 đơn đã đổi / 409 đơn vẫn chờ / 404 / 5xx), mất kết nối rồi Thử lại, mở đúng URL Stripe, Stripe chưa báo kết quả, khóa nút và Back khi đang gửi, mã đơn ngắn hơn 8 ký tự, tiền đến khi đơn đã hủy/hết hạn/thất bại (3 test), tự đọc lại đơn khi quay về từ Stripe (lặng lẽ, thôi đọc khi đơn hết chờ), lần đọc cũ không đè kết quả tải lại mới hơn, phiên bị từ chối tạm thời không làm dừng việc đọc lại |

Widget test dùng `test/support/fake_shop_api.dart`: API giả qua `MockClient`, mỗi test tự khai báo câu trả lời. Các test quyền Admin, ngày sai, form rỗng và đơn không còn chờ kiểm tra cả việc **không** gửi request. Các câu trả lời giả đã được đối chiếu với API thật ngày 10/10/2026:
- "Mã voucher đã tồn tại." (409);
- 403 không có nội dung khi khách gọi API voucher;
- "Chỉ được đánh giá sản phẩm đã nhận." (403);
- "Không tìm thấy đánh giá." (404).

```powershell
flutter analyze
flutter test
```

Kết quả ngày 10/10/2026 (có AI hỗ trợ, sinh viên cần tự chạy lại):
- `flutter analyze` không có lỗi; `flutter test` qua **65/65**, gồm 62 test của phần này và 3 test cũ.
- Chạy với API thật (Development, LocalDB): 21/21 bước kiểm tra cả ba màn qua `ShopRepository` thật. Gồm tạo/sửa/ngừng voucher, mã trùng, khách bị 403, đánh giá trước và sau khi giao, sửa đánh giá của người khác bị 404, mock thất bại hoàn tồn kho, mock thành công.
- `flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5288` build được (APK khoảng 53,6 MB).

Trên bản gộp `nghiahnc/merge-prm393-features` (có AI hỗ trợ, sinh viên cần tự chạy lại):
- Ngày 15/10/2026: chạy bản gộp với API thật và bấm thử trên bản web; mọi bước kiểm thử tối thiểu của FL-13..15 đều qua.
- Ngày 19/10/2026, sau khi sửa các lỗi tìm được trên bản gộp (mã đơn và nhãn trạng thái giống màn đơn hàng, ô voucher ở checkout dùng chung quy tắc mã, bộ chọn ngày giờ tiếng Việt): `flutter analyze` không có lỗi; `flutter test` qua **141/141**, trong đó 66 test của phần này.
- Ngày 19/10/2026, sau khi soát nghiệp vụ với API thật (tiền đến khi đơn đã đóng, danh sách hơn 100 mục, voucher làm đơn thành 0 ₫, đổi mã voucher đã dùng, Admin viết đánh giá, quay lại từ Stripe): `flutter analyze` không có lỗi; `flutter test` qua **161/161**, trong đó 86 test của phần này. Gài 18 lỗi cố ý vào các phần mới, cả 18 lần test đều báo lỗi.

**Phép thử ngược.** Gài lần lượt 16 lỗi cố ý vào code, mỗi lần chạy lại test của màn đó. Cả 16 lần test đều báo lỗi. Có thể tự lặp lại bằng cách sửa đúng dòng rồi chạy `flutter test <file>`:

| # | File | Lỗi gài vào | Test bắt được |
| --- | --- | --- | --- |
| 1 | `vouchers.dart` | `id: old?.id` → `id: null` (sửa lại thành tạo mới) | `vouchers_screen_test.dart` |
| 2 | `dates.dart` | bỏ `toLocal()` (hiện ngày theo UTC) | `vouchers_screen_test.dart` |
| 3 | `dates.dart` | không thêm `Z` cho ngày thiếu múi giờ | `voucher_policy_test.dart` |
| 4 | `vouchers.dart` | `canPop: true` (đóng được form khi đang lưu) | `vouchers_screen_test.dart` |
| 5 | `vouchers.dart` | bỏ kiểm tra Admin | `vouchers_screen_test.dart` |
| 6 | `vouchers.dart` | `usedCount: 0` (bỏ qua số lượt đã dùng) | `vouchers_screen_test.dart` |
| 7 | `vouchers.dart` | luôn gửi `minSubtotalVnd: 0` | `vouchers_screen_test.dart` |
| 8 | `reviews.dart` | không tải lại sau khi xóa | `reviews_screen_test.dart` |
| 9 | `review_policy.dart` | ai cũng sửa được đánh giá | `reviews_screen_test.dart` |
| 10 | `reviews.dart` | bỏ chặn khi chưa chọn sao | `reviews_screen_test.dart` |
| 11 | `payment.dart` | không đọc lại đơn sau mock | `payment_screen_test.dart` |
| 12 | `payment.dart` | bỏ nhánh đơn 0 ₫ | `payment_screen_test.dart` |
| 13 | `payment.dart` | nút mock không bị khóa khi đang gửi | `payment_screen_test.dart` |
| 14 | `payment.dart` | nút "Mở Stripe Checkout" không làm gì | `payment_screen_test.dart` |
| 15 | `payment.dart` | tải lại Stripe không báo khi đơn vẫn chờ | `payment_screen_test.dart` |
| 16 | `payment.dart` | hiện nguyên văn lỗi 5xx | `payment_screen_test.dart` |

Lỗi 2 và 3 chỉ bị bắt khi máy chạy test không ở múi giờ UTC (ví dụ máy giờ Việt Nam), vì ở UTC giờ máy và giờ UTC trùng nhau.

## 6. Giới hạn đã biết (backend)

- Ngày đọc từ database không có hậu tố `Z`. App đọc đúng là UTC: voucher và đánh giá dùng `parseUtc` (`lib/core/dates.dart`), đơn hàng dùng `asUtcDate` (`lib/core/models.dart`, phần của Gia Đạt). Hai hàm cho cùng kết quả với mọi dạng ngày API trả về.
- API so sánh hai ngày của voucher trước khi đổi về UTC (`Validate` trong `GundamShop.Bll/PromotionService.cs`), và coi ngày không có múi giờ là giờ của máy chạy API (`Copy`, `ToUniversalTime`). Trên máy giờ Việt Nam (UTC+7), gọi API trực tiếp (ví dụ Swagger) với `…Z` cùng `…+07:00` hoặc cùng ngày không có `Z` có thể lưu voucher kết thúc trước khi bắt đầu; ngày không có `Z` bị lùi 7 tiếng. App luôn gửi ngày có `Z` nên không gặp.
- `PUT /api/v1/vouchers/{id}` không có `isActive`, nên voucher đã ngừng không bật lại được.
- Mã voucher đã ngừng vẫn tính là trùng khi tạo mới.
- Danh sách đánh giá không có tên người viết. App chỉ đánh dấu được "Đánh giá của bạn".
- Mock chỉ có trong Development. Stripe cần cấu hình riêng.
- Hủy đơn không đóng phiên Stripe Checkout (phiên chỉ hết hạn theo `expires_at`, đặt bằng hạn của đơn), nên khách vẫn trả được tiền cho đơn đã hủy; đơn chuyển `paymentStatus = RefundRequired`. API chưa có thao tác hoàn tiền. Màn thanh toán chỉ báo câu ở mục 4 nếu khách còn ở màn đó; màn chi tiết đơn chỉ hiện dòng Thanh toán – "Cần hoàn tiền".
- `PaymentService.Start` tính `expires_at` của phiên Stripe từ hạn đơn đọc ra không kèm múi giờ (`new DateTimeOffset(order.ExpiresAtUtc)`), nên trên máy chạy API giờ Việt Nam (UTC+7) phiên hết hạn sớm hơn đơn 7 tiếng: đơn bị đánh dấu thanh toán thất bại sớm, còn đơn chỉ còn dưới khoảng 7,5 tiếng thì không mở được phiên (API trả 502, app báo "Thanh toán đang tạm gián đoạn"). Cách sửa ở backend: `DateTime.SpecifyKind(order.ExpiresAtUtc, DateTimeKind.Utc)`.
- `PUT /api/v1/vouchers/{id}` vẫn cho đổi mã của voucher đã có đơn dùng; chỉ app chặn việc này.
- Đơn chưa trả giữ tồn kho và lượt voucher tới 24 giờ; API chưa giới hạn số đơn chưa trả hay số lần dùng voucher của mỗi khách.
- Mọi lý do từ chối voucher ở checkout (chưa đến ngày, hết hạn, hết lượt, đã ngừng, chưa đủ tiền) đều trả chung "Voucher không còn hợp lệ.".
- Admin xóa đánh giá là xóa hẳn, không lưu lý do; khách có thể viết lại ngay.

## 7. Demo nhanh

1. Chạy API ở Development, cổng 5288 (xem `README.md` gốc), rồi chạy app.
2. **FL-13:**
   - Đăng nhập Admin → **Quản trị** → **Voucher**.
   - "Thêm voucher", nhập mã ` sale10` → form hiện "Sẽ lưu là SALE10". Nhập số tiền giảm rồi Lưu.
   - Thêm lại cùng mã → form vẫn mở với "Mã voucher đã tồn tại.".
   - Sửa một voucher hết hạn rồi Lưu → "Thời gian kết thúc đã qua".
   - Ngừng sử dụng → nhãn "Ngừng sử dụng".
3. **FL-14:**
   - Mở một sản phẩm → **Đánh giá sau mua**.
   - Khách chưa nhận hàng: "Viết đánh giá" → Lưu khi để trống thấy 2 lỗi → chọn sao, viết nhận xét → API trả "Chỉ được đánh giá sản phẩm đã nhận.".
   - Khách đã nhận hàng: viết được đánh giá; đánh giá đó có nhãn "Đánh giá của bạn" và có Sửa/Xóa.
4. **FL-15:**
   - Khách đặt đơn → **Đơn** → chi tiết đơn → **Thanh toán**.
   - "Mô phỏng thanh toán thành công" → trạng thái "Đã thanh toán".
   - Với một đơn khác, "Mô phỏng thanh toán thất bại" → "Thanh toán thất bại", tồn kho được hoàn.
