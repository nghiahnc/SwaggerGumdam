# FiveGuysGundam · PRM393 Flutter

Ứng dụng Flutter cho cửa hàng mô hình Gundam, dùng REST API của dự án PRN232. Bản API đi kèm nằm ở gốc repo này; [repo API/Swagger độc lập](https://github.com/nghiahnc/GundamShop-PRN232-API) cũng cung cấp cùng endpoint. Android là nền tảng demo chính của PRM393; Edge có thể dùng để thử nhanh trên máy tính. Ứng dụng Flutter không chứa database SQL Server.

- [Giải thích dự án và danh sách chức năng](PROJECT_GUIDE.md)
- [Map code, màn hình, API và luồng dữ liệu](CODE_MAP.md)
- [Voucher, đánh giá và thanh toán (FL-13..15)](VOUCHER_REVIEW_PAYMENT.md)
- [AI Assistance Log](AI_ASSISTANCE_LOG.md)

## Chạy nhanh

1. Cài Flutter 3.47.2 hoặc bản tương thích Dart 3.13 và Android SDK. Đảm bảo lệnh `flutter` có trong PATH; trên máy tạo dự án SDK nằm ở `D:\PRM393\flutter_windows_3.47.2-stable\flutter`.
2. Tại **thư mục gốc repository**, chạy backend PRN232 ở **Development**, bật migration/seed và cổng 5288:

   ```powershell
   $env:ASPNETCORE_ENVIRONMENT = 'Development'
   $env:Database__AutoMigrate = 'true'
   dotnet run --project GundamShop.Api --urls http://0.0.0.0:5288
   ```

   Backend cần SQL Server LocalDB hoặc connection string SQL Server đã cấu hình. Chi tiết: [hướng dẫn database PRN232](https://github.com/nghiahnc/GundamShop-PRN232-API/blob/main/VISUAL_STUDIO_DATABASE_SETUP.md).

3. Mở terminal PowerShell thứ hai trong thư mục ứng dụng. Với Android Emulator, chạy:

   ```powershell
   flutter pub get
   flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://10.0.2.2:5288
   ```

   Xem ID bằng `flutter devices`. Lần chạy Android đầu có thể mất thời gian để Gradle tải và build; hãy đợi tới khi Flutter in địa chỉ debug service. Với điện thoại thật, thay `10.0.2.2` bằng IP LAN của máy chạy API và cho phép cổng 5288 qua firewall.

   Nếu demo trong Edge trên **cùng máy** với API, dùng:

   ```powershell
   flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:5288
   ```

   `10.0.2.2` chỉ dành cho Android Emulator; Edge cần `127.0.0.1`. Có thể bỏ `--dart-define` khi dùng hai cấu hình mặc định này. Hãy kiểm tra `http://127.0.0.1:5288/health` trên máy trước khi đăng nhập. Backend cho phép CORS từ `localhost` và `127.0.0.1` trong **Development** để Flutter Web gọi API. Nếu backend đang chạy từ trước khi cập nhật mã, dừng bằng `Ctrl+C` và chạy lại để nhận cấu hình CORS mới.

4. Đăng ký tài khoản khách trong ứng dụng. Admin demo do backend seed trong Development: `admin@gundam.local` / `Admin123!`.

## Kiểm tra và đóng gói

```powershell
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5288
```

APK nằm ở `build/app/outputs/flutter-apk/app-release.apk` sau khi build. File APK không lưu trong Git; [bằng chứng kiểm tra Release](qa/VERIFICATION.md) có ảnh và kết quả luồng mua hàng chạy trên Android Emulator với API thật. Bản Flutter scaffold hiện dùng **debug signing cho release build**, chỉ phù hợp demo trên thiết bị kiểm thử. Trước khi phát hành thực tế cần keystore riêng, HTTPS và cấu hình máy chủ có thể truy cập ngoài LAN.

## Giới hạn hiện tại

- Token JWT chỉ giữ trong bộ nhớ; mở lại ứng dụng cần đăng nhập. Không lưu mật khẩu hay token vào bộ nhớ không an toàn.
- Thanh toán mock chỉ chạy khi backend ở Development. Stripe cần test key/webhook secret ở backend; ứng dụng chỉ mở Checkout URL và tải lại trạng thái đơn từ API.
- Android cho phép HTTP nội bộ để demo API trên máy host. Khi triển khai thật hãy chuyển sang HTTPS và bỏ quyền cleartext.
- Backend v1 chưa trả lịch sử điều chỉnh tồn kho, chưa có API khách tự xem danh sách voucher, chưa có refresh token và chưa hoàn tiền tự động.
- Dữ liệu mẫu của backend rất nhỏ (2 sản phẩm, 2 SKU). Nhóm nên tạo thêm qua màn hình admin để thử phân trang, tìm kiếm, tồn kho và voucher.

**Bằng chứng nhóm PRM393:** commit của từng người, checkpoint, review, báo cáo PDF, slide và thử nghiệm trên máy thật phải do nhóm tạo trong quá trình làm việc. Nếu môn học yêu cầu repository Git riêng, nhóm cần tách thư mục PRM393 này sang repository đó và lưu lịch sử làm việc thật. Mã nguồn hiện tại là scaffold có hỗ trợ AI; không được ghi công tác giả cá nhân hoặc tự tạo lịch sử Git giả.
