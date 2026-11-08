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

## Kiểm tra chi tiết mục giỏ hàng · 2026-11-08

Nguồn đối chiếu: `G04_PRM393_Backlog.xlsx`, sheet `Backlog`, dòng 37 (`B37`: UC30, `C37`: View Cart Item Details, `K37`: yêu cầu). Người đã đăng nhập chọn một mục giỏ theo ID; API chỉ trả mục thuộc tài khoản hiện tại và trả không tìm thấy nếu ID sai hoặc thuộc tài khoản khác. Workbook được đọc để đối chiếu, giữ nguyên file gốc.

Bấm một món trong Giỏ hàng để mở **Chi tiết món trong giỏ**. Màn hình gọi `GET /api/v1/cart/items/{id}` và hiển thị tên sản phẩm, SKU, đơn giá hiện tại, số lượng, thành tiền. Có **Tải lại**, lỗi có **Thử lại**; quay về sẽ tải lại danh sách để phản ánh món đã đổi hoặc bị xóa ở nơi khác. Màn hình kiểm tra đăng nhập; quyền sở hữu do API hiện có kiểm tra.

| Kiểm tra | Kết quả |
| --- | --- |
| `flutter analyze --no-pub` | Không có issue |
| `test/cart_item_detail_test.dart` | **8/8 đạt**: đọc mới theo ID, refresh, 404/thử lại, khách chưa đăng nhập, 401, quay về tải lại giỏ, nút Tăng/Xóa không mở chi tiết, màn 320px |
| Các test liên quan hiện có | **26/26 đạt**: `cart_orders_edge_test.dart` (20), `cart_checkout_widget_test.dart` (4), `cart_policy_test.dart` (2) |
| Nhóm test giỏ hàng/đặt hàng | **34/34 đạt** |
| Toàn bộ Flutter sau cập nhật nhánh gộp | **197/197 đạt** với `flutter test --no-pub --concurrency=1`; mã tại `7daff9e`, nền quản trị `ef75a0d` |
| Build API trên bản gộp cuối | **0 lỗi, 0 cảnh báo**; không thay đổi backend cho tính năng chi tiết giỏ |

API thật đã qua **12/12 kiểm tra** với database thử riêng `GundamShopCartDetailAudit20261108`, cổng `5299`: khách chưa đăng nhập 401, chủ giỏ đọc đúng trường/giá/số lượng, GET riêng sau khi đổi số lượng và giá SKU trả dữ liệu mới, khách khác 404, xóa 204 và đọc lại 404. Đã dừng API thử; giữ database thử. [Log kiểm tra API](cart-item-detail-api-2026-11-08.txt) chỉ chứa dữ liệu thử, không chứa token hoặc mật khẩu.

Đây là kiểm tra do AI thực hiện; chưa có xác nhận sinh viên đã tự chạy lại. Tính năng sử dụng API hiện có; chưa build lại APK trong đợt này.
