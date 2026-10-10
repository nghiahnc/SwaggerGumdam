# FiveGuysGundam · Map code

Tài liệu này nối **màn hình → state/logic → model → endpoint → kiểm thử**. Dùng cùng `PROJECT_GUIDE.md` để giải thích khi bảo vệ và xác định tác động khi đổi yêu cầu.

## 1. Cấu trúc

| Vị trí | Vai trò |
| --- | --- |
| `lib/main.dart` | Khởi tạo Provider, theme và `ShopShell`; đọc `API_BASE_URL` lúc build |
| `web/` | Điểm vào Flutter Web để demo trên Edge; API dùng `127.0.0.1` khi chạy cùng máy |
| `lib/core/api_client.dart` | HTTP/JSON, Bearer JWT, timeout, Problem Details |
| `lib/core/session.dart` | `ChangeNotifier` cho login/register/logout, user và role |
| `lib/core/models.dart` | Parse DTO JSON thành model Dart có kiểu |
| `lib/core/shop_repository.dart` | Toàn bộ đường gọi API, trả model cho màn hình |
| `lib/core/cart_policy.dart` | Quy tắc số lượng trước khi thêm giỏ |
| `lib/widgets/common.dart` | `AsyncPanel` loading/empty/error/data, tiền VND, validation, dialog xác nhận, snackbar |
| `lib/screens/shell.dart` | NavigationBar; tab quản trị chỉ hiện cho Admin |
| `test/cart_policy_test.dart` | Unit test số lượng hợp lệ, 0, >99, vượt tồn; giới hạn tối đa theo tồn |
| `test/catalog_test.dart` | FL-04: query OData ($filter/$skip/$count), phân trang theo tổng số, rỗng + xóa bộ lọc, mất mạng rồi thử lại |
| `test/product_screen_test.dart` | FL-05: SKU hết hàng bị khóa, số lượng dừng ở tồn, khách chưa đăng nhập bị yêu cầu đăng nhập, thêm giỏ đúng SKU/số lượng |
| `test/async_panel_test.dart` | Widget test lỗi bất đồng bộ và nút Thử lại |

## 2. Map màn hình và API

| Chủ trì dự kiến | Màn hình / file | Action chính | Endpoint backend |
| --- | --- | --- | --- |
| Huỳnh Nguyễn Chí Nghĩa | `AuthScreen`, `screens/account.dart` | Đăng ký/đăng nhập, role, đăng xuất | `POST /api/v1/auth/register`, `POST /api/v1/auth/login` |
| Huỳnh Nguyễn Chí Nghĩa | `AddressesScreen`, `screens/addresses.dart` | Xem/thêm/sửa/xóa địa chỉ | `GET/POST /api/v1/addresses`, `PUT/DELETE /api/v1/addresses/{id}` |
| Ngô Quốc Hưng | `CatalogScreen`, `screens/catalog.dart` | OData tìm/lọc/skip/top | `GET /odata/Products` |
| Ngô Quốc Hưng | `ProductScreen`, `screens/product.dart` | Chi tiết, SKU, chọn số lượng, thêm giỏ | `GET /api/v1/products/{id}`, `GET /api/v1/products/{id}/variants`, `POST /api/v1/cart/items` |
| Nguyễn Hữu Tài | `AdminCatalogScreen`, `screens/admin_catalog.dart` | CRUD danh mục và sản phẩm | `GET/POST/PUT/DELETE /api/v1/categories`, `/api/v1/products` |
| Nguyễn Hữu Tài | `AdminInventoryScreen`, `screens/admin_inventory.dart` | CRUD SKU, đổi giá/trạng thái, điều chỉnh tồn | `GET /api/v1/products/{id}/variants`, `POST/PUT/DELETE /api/v1/variants`, `POST /api/v1/variants/{id}/stock-adjustments` |
| Trần Gia Đạt | `CartScreen`, `screens/cart.dart` | Xem/sửa số lượng/xóa giỏ | `GET/PUT/DELETE /api/v1/cart/items` |
| Trần Gia Đạt | `CheckoutScreen`, `screens/checkout.dart` | Chọn địa chỉ, voucher, tạo đơn | `GET /api/v1/addresses`, `POST /api/v1/orders` |
| Trần Gia Đạt | `OrdersScreen`, `OrderDetailScreen`, `screens/orders.dart` | Theo dõi/hủy đơn, admin giao hàng | `GET /api/v1/orders`, `GET /api/v1/orders/{id}`, `POST /api/v1/orders/{id}/cancel`, `PUT /api/v1/orders/{id}/status` |
| Trần Hiếu Nghĩa | `VouchersScreen`, `screens/vouchers.dart` | CRUD voucher | `GET/POST/PUT/DELETE /api/v1/vouchers` |
| Trần Hiếu Nghĩa | `ReviewsScreen`, `screens/reviews.dart` | Xem/viết/sửa/xóa review | `GET /api/v1/products/{id}/reviews`, `POST/PUT/DELETE /api/v1/reviews` |
| Trần Hiếu Nghĩa | `PaymentScreen`, `screens/payment.dart` | Mock success/fail hoặc mở Stripe | `POST /api/v1/payments/orders/{id}/session`, `POST /api/v1/payments/mock/orders/{id}/complete` |

Backend không nhận yêu cầu trực tiếp từ các widget: mọi request đi qua `ShopRepository` và `ApiClient`. Backend code tham chiếu: [ShopRoutes.cs](../../GundamShop.Api/ShopRoutes.cs) (route/quyền), [GundamShop.Bll](../../GundamShop.Bll) (nghiệp vụ), [GundamShop.Dal](../../GundamShop.Dal) (EF/SQL Server).

## 3. Truy vết một luồng từ nút bấm tới SQL Server

```text
ProductScreen nút “Thêm vào giỏ”
  → validateQuantity(quantity, stock)
  → ShopRepository.addToCart()
  → ApiClient.request(POST, /api/v1/cart/items, JSON + JWT)
  → backend ShopRoutes → ShoppingService.AddCartItem()
  → ShopDbContext.CartItems → SQL Server
  → response CartItemDto → snackbar / trạng thái giỏ tải lại

CartScreen nút “Đặt hàng”
  → CheckoutScreen chọn Address + Voucher
  → ShopRepository.checkout()
  → ShoppingService.Checkout() transaction: kiểm tra tồn/voucher,
    giữ tồn, xóa giỏ, tạo đơn PendingPayment
  → OrderDetailScreen lấy OrderDto mới
  → PaymentScreen tạo session và xử lý mock/Stripe
  → tải lại OrderDetailScreen sau khi thanh toán
```

API quyết định giá cuối cùng, tồn kho, trạng thái và quyền. Kiểm tra ở Flutter giúp phản hồi sớm nhưng không thay thế validation backend.

## 4. Khi đổi yêu cầu thì sửa ở đâu?

| Thay đổi | Các file/kiểm thử cần xem |
| --- | --- |
| Thêm trường địa chỉ | `models.dart` Address, `shop_repository.dart`, `addresses.dart`, backend `AddressRequest/Dto`, test form |
| Thêm bộ lọc catalog | `shop_repository.dart:searchProducts`, `catalog.dart`, OData whitelist/backend, test query |
| Đổi quy tắc số lượng | `cart_policy.dart`, `product.dart`, `cart.dart`, `cart_policy_test.dart`, BLL checkout |
| Thêm trạng thái đơn | `orders.dart`, `models.dart`, backend `ShoppingService.SetStatus`, QA chuyển trạng thái |
| Đổi cổng thanh toán | `payment.dart`, `shop_repository.dart`, backend `PaymentService`, cấu hình webhook/test |
| Thêm refresh token | `session.dart`, `api_client.dart`, backend auth, kiểm thử 401/hết hạn |

## 5. Cách đọc lỗi

- `ApiClient` lấy `title` hoặc lỗi validation từ Problem Details. Lỗi mạng/timeout thành thông báo người dùng.
- `AsyncPanel` hiển thị loading, empty, error + retry, và data. Màn hình ghi dữ liệu bắt lỗi, hiện snackbar, rồi gọi `reload()`.
- JWT chỉ ở RAM. Nếu API trả 401 do token hết hạn, ứng dụng hiện lỗi và người dùng cần đăng xuất/đăng nhập lại; tự làm mới token chưa có trong backend.
