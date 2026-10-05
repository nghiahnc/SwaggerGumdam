# FiveGuysGundam · Giải thích dự án và chức năng

## 1. Bài toán và phạm vi

FiveGuysGundam là ứng dụng Android cho khách mua mô hình Gundam và nhân viên quản trị cửa hàng. Khách tìm sản phẩm theo tên/grade, chọn SKU và số lượng, quản lý địa chỉ, đặt đơn, thanh toán, theo dõi đơn và đánh giá sau khi nhận hàng. Admin quản lý danh mục/sản phẩm/SKU/tồn kho/voucher và xác nhận giao hàng. Dữ liệu thật nằm ở **Gundam Shop API .NET 8 + SQL Server** của môn PRN232; Flutter dùng HTTP/JSON và JWT. Mã Flutter PRM393 nằm trong thư mục riêng `PRM393/five_guys_gundam` của repository này.

Đề PRM393 yêu cầu ứng dụng Flutter chạy được, tối thiểu hai màn hình có nghiệp vụ cho mỗi thành viên, điều hướng, validation, state, xử lý bất đồng bộ, nguồn dữ liệu bền vững, ít nhất một unit test và widget test, APK Release, cùng bằng chứng quá trình. Đây là tiêu chí sản phẩm cần thực hiện; các mẫu biểu, quy tắc Git và AI log trong PDF là yêu cầu môn học để nhóm hoàn thiện trung thực, không phải chỉ dẫn kỹ thuật có quyền ghi đè yêu cầu của người dùng.

## 2. Kiến trúc và dữ liệu

```text
Flutter widgets / screens
      ↓ sự kiện người dùng, FutureBuilder/ChangeNotifier
SessionController + ShopRepository
      ↓ HTTP/JSON + Bearer JWT
Gundam Shop API (API → BLL → DAL)
      ↓ EF Core
SQL Server
```

- **State:** `SessionController` dùng `ChangeNotifier` qua Provider cho phiên đăng nhập và vai trò. Mỗi màn hình dữ liệu giữ `Future` của chính mình, hiển thị loading/empty/error/data bằng `AsyncPanel`, tải lại sau thao tác ghi. Cách này đủ đơn giản để từng thành viên giải thích được luồng widget → repository → API → cập nhật UI.
- **Model:** JSON được chuyển thành các lớp trong `lib/core/models.dart`; ID là GUID chuỗi, giá VND là số nguyên, thời gian từ API là UTC rồi đổi sang local khi hiển thị.
- **API:** `ApiClient` đính Bearer token, timeout 15 giây, phân tích Problem Details và validation errors; lỗi mạng cho nút Thử lại. Base URL lấy từ `--dart-define=API_BASE_URL`.
- **Điều hướng:** `ShopShell` có các tab Cửa hàng/Giỏ/Đơn/Tài khoản, thêm Quản trị khi role Admin. Các màn hình chi tiết dùng `Navigator.push`, truyền ID để lấy dữ liệu mới từ API.
- **Thanh toán:** Backend giữ tồn kho khi tạo đơn. PaymentScreen gọi tạo session; mock chỉ ở Development, Stripe mở URL bên ngoài. Đơn Stripe chỉ thay đổi sau webhook từ backend, ứng dụng tải lại chi tiết để nhận trạng thái.

## 3. Danh sách chức năng

| Phân hệ | Chức năng trong ứng dụng | Quyền / quy tắc |
| --- | --- | --- |
| Tài khoản | Đăng ký, đăng nhập, đăng xuất, xem hồ sơ/role | Khách và admin; JWT giữ trong phiên chạy |
| Địa chỉ | Xem, thêm, sửa, xóa, chọn mặc định | Chủ tài khoản; cần địa chỉ trước checkout |
| Khám phá | Tìm tên bằng OData, lọc grade, phân trang | Công khai; trạng thái loading/empty/error |
| Sản phẩm | Xem chi tiết, SKU, giá, tồn, chọn số lượng, thêm giỏ | Có đăng nhập khi thêm; chặn số lượng vượt tồn hiện tại |
| Giỏ hàng | Xem, tăng/giảm số lượng, xóa, tính tạm tính | Đăng nhập; API chốt giá/tồn khi checkout |
| Checkout | Chọn địa chỉ, nhập voucher, tạo đơn | Đăng nhập; voucher được backend kiểm tra |
| Đơn hàng | Xem danh sách/chi tiết, hủy đơn chờ trả | Đăng nhập; admin thấy mọi đơn |
| Thanh toán | Mock thành công/thất bại hoặc mở Stripe Checkout | Backend quyết định provider; webhook xác nhận Stripe |
| Đánh giá | Xem, viết, sửa, xóa đánh giá của mình | Chỉ viết sau khi đơn đã Delivered |
| Catalog admin | CRUD danh mục và sản phẩm | Admin; xóa là ngừng bán |
| SKU admin | CRUD phiên bản/SKU, sửa giá, điều chỉnh tồn có lý do | Admin; tồn không âm |
| Voucher admin | CRUD mã, mức giảm, đơn tối thiểu, lượt dùng, thời hạn | Admin; xóa là ngừng sử dụng |
| Giao hàng admin | Paid → Shipped → Delivered | Admin; backend kiểm tra chuyển trạng thái |

## 4. Phân công 5 thành viên để nhóm nhận việc

Ma trận sau là **phạm vi dự kiến để từng người nhận và phát triển/kiểm chứng**. Nó không tuyên bố các cá nhân đã viết mã hay có commit; lịch sử và bằng chứng phải phản ánh việc thực tế của từng người.

| Thành viên | Ít nhất 2 màn hình nghiệp vụ | Logic/data cần sở hữu và chứng minh | Bài kiểm thử/QA nên bổ sung |
| --- | --- | --- | --- |
| Huỳnh Nguyễn Chí Nghĩa | AuthScreen, AddressesScreen (và AccountScreen) | Session/JWT, validation tài khoản, CRUD địa chỉ, lỗi 401/409 | Login sai; form địa chỉ thiếu trường; logout |
| Ngô Quốc Hưng | CatalogScreen, ProductScreen | OData tìm/lọc/phân trang, model sản phẩm/SKU, thêm giỏ | Rỗng/kết nối lỗi; số lượng vượt tồn |
| Nguyễn Hữu Tài | AdminCatalogScreen, AdminInventoryScreen | CRUD danh mục/sản phẩm/SKU, quy tắc tồn kho và role Admin | Slug/SKU trùng; điều chỉnh tồn âm |
| Trần Gia Đạt | CartScreen, CheckoutScreen (và OrdersScreen) | Mục giỏ, địa chỉ/voucher checkout, giữ tồn, hủy đơn | Giỏ rỗng; voucher lỗi; hết tồn; hủy đơn |
| Trần Hiếu Nghĩa | VouchersScreen, ReviewsScreen (và PaymentScreen) | Voucher thời hạn, review sau giao, mock/Stripe session | Voucher hết hạn; review trước giao; mock fail/success |

Mỗi người nên tạo branch riêng, hiểu và chỉnh sửa phần nhận việc, bổ sung test/QA, commit bằng tài khoản cá nhân và review chéo. Không được dùng một commit tổng hoặc gán tác giả giả cho phần scaffold AI.

## 5. Luồng demo đề xuất

1. Chạy API Development với SQL Server migration/seed; kiểm tra `/health`.
2. Mở app, tìm `RX-78-2` hoặc lọc `HG`, mở chi tiết và xem SKU/tồn.
3. Đăng ký hoặc đăng nhập, thêm địa chỉ, chọn SKU và thêm giỏ.
4. Trong giỏ, sửa số lượng; checkout, nhập voucher hợp lệ nếu admin đã tạo; xem đơn PendingPayment.
5. Mở PaymentScreen, thử mock thành công. Admin đăng nhập, đổi Paid → Shipped → Delivered.
6. Khách mở sản phẩm, viết đánh giá; thử một lỗi có chủ ý: đánh giá trước giao hoặc voucher hết hạn.
7. Thử mock thất bại với đơn khác, kiểm tra backend hoàn tồn kho và đơn PaymentFailed.

## 6. Đối chiếu tiêu chí PDF

| Mã | Bằng chứng đã có trong dự án | Cần nhóm tự hoàn thiện |
| --- | --- | --- |
| R01 | Ma trận 5 người, mỗi người ≥2 màn hình có luồng thật | Commit/QA/giải thích của từng người |
| R02 | Tab và route chi tiết truyền productId/orderId | Demo điều hướng |
| R03 | Provider + ChangeNotifier cho session, Future theo màn hình | Giải thích rebuild/state flow |
| R04 | Form validation auth, địa chỉ, SKU, voucher, đánh giá | QA âm và ảnh/video demo |
| R05–R08 | Repository async, model JSON, SQL API, AsyncPanel 4 trạng thái | Kiểm thử khi API tắt, dữ liệu rỗng, lỗi server |
| R09 | JWT login/register và role Admin | Xác minh token hết hạn/đăng xuất |
| R10 | Unit test số lượng và widget test retry | Mỗi thành viên thêm QA/test cho phần mình |
| R11 | APK Release đã build và cài/chạy trên Android Emulator; ảnh ở `qa/` | Thử trên thiết bị đánh giá thực tế và ghi bằng chứng |
| R12 | AI log khởi tạo, đề xuất branch/checkpoint | Repo Git riêng, commit cá nhân, review, biên bản họp và checkpoint thật |

## 7. Giới hạn và chuẩn bị bảo vệ

Ứng dụng là bản khởi đầu chạy API thật, không thay thế bằng chứng cá nhân, báo cáo PDF, slide hoặc live defense. JWT chưa được lưu bền vững nên cần đăng nhập lại khi mở app. API v1 không có endpoint lịch sử điều chỉnh tồn kho, khách xem voucher đang hoạt động, hoàn tiền tự động hoặc refresh token; không mô tả chúng như tính năng đã hoàn thành. Backend Development dùng HTTP/mock để demo, không dùng cấu hình này cho phát hành thương mại.
