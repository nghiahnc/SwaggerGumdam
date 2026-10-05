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
