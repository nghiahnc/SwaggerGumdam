# Kiểm tra bản demo · 2026-10-05

| Kiểm tra | Kết quả |
| --- | --- |
| `flutter pub get --offline` | Thành công với package đã có trong Pub cache |
| `flutter analyze` | Không có issue |
| `flutter test` | 3 test pass: số lượng/tồn kho, retry UI, JWT/Problem Details |
| API backend `GET /health` | `{"status":"ok"}` |
| API backend OData + login admin + products | JSON đúng contract của app |
| `flutter build apk --release --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:5288` | Thành công, APK 53.367.212 byte |
| `adb install -r` và mở `MainActivity` trên Medium_Phone Android Emulator | Thành công; catalog và chi tiết Freedom Gundam tải dữ liệu API thật |
| Luồng Android Release | Đăng nhập admin demo → thêm Freedom Gundam vào giỏ → chọn địa chỉ → tạo đơn PendingPayment → mock thành công/Paid → Admin chuyển Shipped → Delivered. Mọi bước hiển thị trạng thái từ API. |

Ảnh chụp Release: `release-home.png`, `release-product.png`, `release-cart.png`, `release-checkout-address.png`, `release-order.png`, `release-payment.png`, `release-paid.png`, `release-delivered.png`. Địa chỉ `PRM393 QA` được tạo qua API để thử checkout; đơn thử `e7bcd17a...` và địa chỉ vẫn nằm trong LocalDB demo. Đây là bằng chứng kiểm tra kỹ thuật do AI thực hiện; **không thay cho QA hoặc Git evidence cá nhân của thành viên**. Review, các form CRUD admin và mock thất bại chưa được kiểm thử trực tiếp trong giao diện Android ở lần kiểm tra này; hãy kiểm tra chúng khi nhóm nhận phần việc.

## Kiểm tra FL-13..15 · 2026-11-08

Thực hiện trên nhánh local `nghiahnc/merge-prm393-features`, nền `dbfa118`, sau khi bổ sung UC39/UC44 và sửa lỗi đọc voucher/nhận webhook. Phạm vi là Voucher, Đánh giá, Stripe của Trần Hiếu Nghĩa.

| Kiểm tra | Kết quả |
| --- | --- |
| `flutter analyze --no-pub` | Không có issue |
| Toàn bộ Flutter test, chạy từng file với `--no-pub --concurrency=1` | **172/172 đạt**, 19 file; tăng 10 test so với nền 162 test |
| Các màn Voucher/Chi tiết voucher/Đánh giá/Thanh toán | **74/74 widget test đạt**: 25 + 6 + 20 + 23 |
| Unit test voucher/đánh giá/thanh toán | **23/23 đạt**: 14 + 9 |
| Build ASP.NET API (`dotnet build`) | Thành công, **0 lỗi, 0 cảnh báo**; chạy một worker, tắt shared compilation, giới hạn GC 256 MB |
| Stripe giả lập, `tests/stripe_e2e.py` | **57/57 đạt**, mã thoát 0; gồm 13 kiểm tra hồi quy mới cho webhook sai dữ liệu và các trường sai kiểu |

Các lần khởi động và lần chạy toàn bộ ban đầu gặp thiếu bộ nhớ ảo trên máy. Lần đầu cũng bắt được lỗi callback `setState` trả về Future trong hai màn chi tiết mới; lỗi này đã được sửa trước đợt 172 test đạt. Đợt kiểm tra cuối gọi Flutter tool với giới hạn heap 192 MB và khởi động lại công cụ cho từng file để giải phóng bộ nhớ; kết quả tổng hợp chỉ dùng các lần chạy cuối có mã thoát 0. Log chạy cuối trên máy: `D:/Temp/swaggergumdam-flutter-20261108-yxw66qnf/results.json`.

Cách thử các màn mới:

1. Admin → Quản trị → Voucher → bấm một voucher: mở **Chi tiết voucher** (UC39), không mở form Sửa. Kiểm tra mức giảm, đơn tối thiểu, lượt dùng, thời hạn và trạng thái; thử **Tải lại**, quay về danh sách. Voucher đã ngừng vẫn xem được.
2. Chi tiết sản phẩm → Đánh giá sau mua → bấm một đánh giá: mở **Chi tiết đánh giá** (UC44), đọc `GET /api/v1/reviews/{id}`. Khách chưa đăng nhập vẫn xem được. Đánh giá đã xóa hiện lỗi cùng **Thử lại**; quay về sẽ tải lại danh sách.
3. Khi bấm Sửa voucher mà GET theo ID thất bại, form không mở bằng bản cũ. Bấm Sửa để thử lại; số lượt mới nhất quyết định khóa mã.

Các kết quả trên do AI thực hiện. Sinh viên chưa xác nhận đã tự chạy thử. Bằng chứng ảnh Android Release ở phần 05/10 là lần chạy cũ; đợt này chưa cập nhật APK hoặc ảnh Release. Stripe với tài khoản thật vẫn cần test key và webhook thật; kiểm thử bằng máy chủ giả lập không thay thế bằng chứng đó.

Stripe giả lập chạy với API `http://127.0.0.1:5298`, máy chủ giả lập `http://127.0.0.1:12118` và database riêng `GundamShopPaymentAudit20261108`. Đã dừng hai tiến trình kiểm thử sau khi hoàn tất; database thử được giữ lại. [Log Stripe 57/57](stripe-e2e-2026-11-08.txt) chứa dữ liệu thử, không chứa token hoặc khóa Stripe thật.
