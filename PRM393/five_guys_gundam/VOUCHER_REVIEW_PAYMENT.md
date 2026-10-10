# Voucher, đánh giá và thanh toán (FL-13 · FL-14 · FL-15)

Phần việc của **Trần Hiếu Nghĩa** theo `PhanCong_Flutter_PRM393.xlsx`: hai màn hình chính `VouchersScreen`, `ReviewsScreen` và màn bổ sung `PaymentScreen`. Ba màn hình giữ đúng file trong bảng phân công; logic kiểm tra được tách ra `lib/core/*_policy.dart` để unit test chạy không cần server.

| Task | Màn hình | Ai dùng, vào từ đâu | API |
| --- | --- | --- | --- |
| FL-13 | `VouchersScreen` · `lib/screens/vouchers.dart` | Admin · tab **Quản trị** → **Voucher** | `GET/POST/PUT/DELETE /api/v1/vouchers` (chỉ Admin) |
| FL-14 | `ReviewsScreen` · `lib/screens/reviews.dart` | Mọi người · chi tiết sản phẩm → **Đánh giá sau mua** | `GET /api/v1/products/{id}/reviews`; `POST/PUT/DELETE /api/v1/reviews` (cần đăng nhập) |
| FL-15 | `PaymentScreen` · `lib/screens/payment.dart` | Khách · chi tiết đơn chờ thanh toán → **Thanh toán** | `GET /api/v1/orders/{id}`; `POST /api/v1/payments/orders/{id}/session`; `POST /api/v1/payments/mock/orders/{id}/complete` (chỉ Development) |

## 1. Cách làm chung

- Màn hình đọc dữ liệu qua `ShopRepository` → `ApiClient`, hiển thị bằng `AsyncPanel` (đang tải / lỗi + Thử lại / dữ liệu).
- Form thêm/sửa tự gửi request qua `onSubmit` và **chỉ đóng khi thành công**. Khi API từ chối, form vẫn mở, giữ dữ liệu đã gõ và hiện lý do (ví dụ "Mã voucher đã tồn tại.").
- Lỗi hiện sau lần bấm Lưu đầu tiên, rồi cập nhật theo từng lần sửa.
- Khi đang lưu, nút Lưu bị khóa và không đóng được form. Bấm ra ngoài form cũng không đóng, để không mất dữ liệu đang nhập. Khi đang xóa hoặc gửi kết quả mock, thanh tiến trình hiện dưới tiêu đề, còn menu và nút bị khóa; lúc gửi kết quả mock thì nút Back cũng bị khóa.
- Sau mỗi lần ghi, danh sách hoặc đơn hàng được đọc lại từ API, vì dữ liệu có thể đổi ở chỗ khác: checkout tăng lượt dùng voucher, thanh toán đổi trạng thái đơn.
- 401/403 không có nội dung được đổi thành câu dễ hiểu (`lib/core/error_text.dart`). Các lỗi khác hiện đúng câu tiếng Việt API trả về.
- **Ngày giờ:** API trả ngày đọc từ SQL Server **không có hậu tố `Z`**, dù đó là giờ UTC. Ví dụ: tạo voucher thì nhận `2026-10-20T07:00:00Z`, nhưng đọc danh sách thì nhận `2026-10-20T07:00:00`. `parseUtc` trong `lib/core/dates.dart` đọc cả hai dạng là UTC. Nếu không, hạn voucher hiện sớm 7 tiếng và mỗi lần sửa lại bị lùi thêm 7 tiếng.

## 2. FL-13 · Voucher (Admin)

- **Quyền:** tab Quản trị chỉ hiện với Admin. Màn hình vẫn kiểm tra lại: người không phải Admin chỉ thấy "Chỉ tài khoản quản trị mới quản lý được voucher." và **không request nào được gửi**.
- **Danh sách:** mã, số tiền giảm, đơn tối thiểu, số lượt đã dùng/tối đa, thời gian `dd/MM/yyyy HH:mm` theo giờ máy, và nhãn trạng thái. Nhãn dùng đúng các điều kiện checkout kiểm tra (`ShoppingService`: đang hoạt động, đã bắt đầu, chưa kết thúc, còn lượt). Khi nhiều điều kiện cùng sai, nhãn lấy theo thứ tự trong bảng:

  | Trạng thái | Điều kiện |
  | --- | --- |
  | Ngừng sử dụng | `isActive = false` |
  | Hết hạn | bây giờ ≥ thời gian kết thúc |
  | Hết lượt | đã dùng ≥ số lượt tối đa |
  | Chưa bắt đầu | bây giờ < thời gian bắt đầu |
  | Đang áp dụng | các trường hợp còn lại |

- **Quy tắc form** (`lib/core/voucher_policy.dart`):

  | Trường | Quy tắc |
  | --- | --- |
  | Mã | Bắt buộc, tối đa 64 ký tự, tự bỏ khoảng trắng hai đầu và viết hoa giống API; chỉ chữ không dấu, số, `-`, `_` (quy ước app để khách gõ được) |
  | Số tiền giảm | Số nguyên 1 – 1.000.000.000 ₫ |
  | Đơn tối thiểu | Số nguyên 0 – 1.000.000.000 ₫ |
  | Số lượt tối đa | 1 – 1.000.000; khi sửa không nhỏ hơn số lượt đã dùng |
  | Thời gian | Bắt đầu trước kết thúc; kết thúc phải sau hiện tại |

  Các quy tắc chặt hơn API (mẫu mã, mức tối đa) chỉ áp dụng cho giá trị mới nhập. Voucher tạo từ nơi khác (ví dụ Swagger) với mã có dấu vẫn sửa được ngày mà không phải đổi mã.

- **Ngừng sử dụng** là xóa mềm (`IsActive = false`), có hộp xác nhận. Voucher đã ngừng không còn menu, vì API không có cách bật lại.

## 3. FL-14 · Đánh giá

- **Ai làm được gì:**
  - Ai cũng xem được.
  - Muốn viết phải đăng nhập. Khách chưa đăng nhập thấy nút "Đăng nhập để viết đánh giá".
  - Mỗi khách một đánh giá cho mỗi sản phẩm. Khi đã có, nút đổi thành "Sửa đánh giá của bạn"; đánh giá của mình nằm đầu danh sách.
  - Chỉ đánh giá của mình mới có Sửa/Xóa. Admin chỉ có Xóa trên đánh giá của khách, vì API cho Admin xóa nhưng không cho sửa.
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
- Nếu API vẫn từ chối mở phiên:
  - 409 vì đơn vừa đổi trạng thái: màn hình đọc lại đơn và hiện trạng thái mới;
  - lý do khác (đơn sắp hết hạn, không phải đơn của mình): màn hình vẫn hiện thông tin đơn kèm lý do.
- Đơn 0 ₫ được API đánh dấu đã thanh toán ngay khi mở phiên; màn hình hiện luôn kết quả thành công.
- **Mock** (backend ở Development):
  - hai nút "Mô phỏng thanh toán thành công" và "Mô phỏng thanh toán thất bại";
  - sau khi gửi, màn hình **đọc lại đơn** và hiện trạng thái API báo: *Đã thanh toán*, hoặc *Thanh toán thất bại* kèm việc tồn kho và lượt voucher đã được hoàn;
  - có nút "Quay lại đơn hàng", và màn chi tiết đơn cũng tải lại.
- **Stripe:**
  - nút "Mở Stripe Checkout" mở trang thanh toán bằng `url_launcher`;
  - đơn chỉ đổi trạng thái khi Stripe gọi webhook về backend, nên có nút "Tôi đã thanh toán, tải lại trạng thái";
  - backend cần `Payments:Provider = Stripe`, test key, SuccessUrl/CancelUrl và webhook secret.

## 5. Kiểm thử

| File | Loại | Số test | Ứng với "Kiểm thử tối thiểu" |
| --- | --- | --- | --- |
| `test/voucher_policy_test.dart` | Unit | 12 | Ngày sai, voucher hết hạn (ranh giới bắt đầu/kết thúc), mã, số tiền, lượt; đọc ngày UTC |
| `test/review_payment_policy_test.dart` | Unit | 7 | Form rỗng, sửa/xóa của người khác; nhãn kết quả thanh toán |
| `test/vouchers_screen_test.dart` | Widget | 12 | Quyền Admin (không gửi request; 403), voucher hết hạn và ngày hiển thị theo giờ máy, ngày sai, mã trùng (409), thêm, sửa (PUT giữ nguyên thời điểm), lượt tối đa không dưới số đã dùng, voucher có mã cũ, không đóng form khi đang lưu, ngừng sử dụng |
| `test/reviews_screen_test.dart` | Widget | 10 | Đánh giá trước giao (403), sửa/xóa của người khác, form rỗng, viết, sửa, xóa (danh sách cập nhật), 404 khi sửa, 409 khi viết |
| `test/payment_screen_test.dart` | Widget | 11 | Hai kết quả mock, tải lại trạng thái đơn sau thanh toán, đơn không còn chờ, mock bị từ chối, đơn 0 ₫, phiên bị từ chối (409/404), mở đúng URL Stripe, khóa nút và Back khi đang gửi |

Widget test dùng `test/support/fake_shop_api.dart`: API giả qua `MockClient`, mỗi test tự khai báo câu trả lời. Các test quyền Admin, ngày sai, form rỗng và đơn không còn chờ kiểm tra cả việc **không** gửi request. Các câu trả lời giả đã được đối chiếu với API thật ngày 10/10/2026:
- "Mã voucher đã tồn tại." (409);
- 403 không có nội dung khi khách gọi API voucher;
- "Chỉ được đánh giá sản phẩm đã nhận." (403);
- "Không tìm thấy đánh giá." (404).

```powershell
flutter analyze
flutter test
```

Kết quả ngày 10/10/2026 (có AI hỗ trợ, sinh viên cần tự chạy lại): `flutter analyze` không có lỗi; `flutter test` qua **55/55**, gồm 52 test của phần này và 3 test cũ. Phép thử ngược: gài lần lượt 12 lỗi cố ý vào code (ví dụ sửa voucher lại gửi POST, hiển thị ngày theo UTC, bỏ chặn Admin, bỏ tải lại sau mock); cả 12 lần test đều báo lỗi.

## 6. Giới hạn đã biết (backend)

- Ngày đọc từ database không có hậu tố `Z`. App đã xử lý cho voucher và đánh giá. Màn đơn hàng của thành viên khác (`ShopOrder` trong `models.dart`) vẫn dùng `DateTime.parse`, nên giờ tạo đơn và hạn thanh toán hiện sớm 7 tiếng.
- `PUT /api/v1/vouchers/{id}` không có `isActive`, nên voucher đã ngừng không bật lại được.
- Mã voucher đã ngừng vẫn tính là trùng khi tạo mới.
- Danh sách đánh giá không có tên người viết. App chỉ đánh dấu được "Đánh giá của bạn".
- App chỉ tải 100 đánh giá mới nhất (`pageSize=100` trong `ShopRepository.reviews`, file dùng chung). Sản phẩm có hơn 100 đánh giá thì điểm trung bình chỉ tính trên 100 đánh giá đó.
- Mock chỉ có trong Development. Stripe cần cấu hình riêng.

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
