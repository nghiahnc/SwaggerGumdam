# Hướng dẫn dev · Gundam Shop API

## 1. Dự án này hoạt động thế nào?

Một ứng dụng Flutter sau này gửi HTTP/JSON tới API. API xác thực người dùng, gọi nghiệp vụ ở BLL, rồi DAL đọc/ghi SQL Server bằng EF Core. Không cần Flutter để thử backend: Swagger hoặc PowerShell đều gọi cùng endpoint.

```text
Flutter (sau này) / Swagger
           │ HTTP + JSON + Bearer JWT
           ▼
GundamShop.Api ── route, quyền, validation, mã lỗi, OData
           ▼
GundamShop.Bll ── quy tắc catalog, giỏ, đơn, voucher, thanh toán
           ▼
GundamShop.Dal ── entity, DbContext, migration EF Core
           ▼
SQL Server / LocalDB
```

- **REST**: endpoint `/api/v1/...` dùng GET/POST/PUT/DELETE. Các danh sách trả `{ items, pageNumber, pageSize, totalCount }`. `pageSize` tối đa 100.
- **EF Core**: ánh xạ C# entity sang bảng SQL Server. Migration trong `GundamShop.Dal/Migrations` tạo và cập nhật cấu trúc database.
- **JWT**: `POST /api/v1/auth/login` trả `accessToken`. Đặt header `Authorization: Bearer <token>` cho các API cần đăng nhập. `Admin` được sửa catalog, tồn kho, voucher và cập nhật giao hàng.
- **OData**: `GET /odata/Products` là bản đọc sản phẩm. Cho phép `$filter`, `$orderby`, `$skip`, `$top`, `$count`; tối đa 50 mục/lần. Ví dụ `?$filter=Grade eq 'HG'&$orderby=Name&$top=10`. Thuộc tính trong OData dùng PascalCase; `FromPriceVnd` là `null` nếu chưa có SKU đang bán. Không có OData ghi dữ liệu hay mở rộng tùy ý.
- **Problem Details**: lỗi nghiệp vụ trả HTTP 400/401/403/404/409 kèm JSON `title`, `status`; lỗi bất ngờ trả 500 và được ghi log.

## 2. Chạy SQL Server

Mặc định `appsettings.json` dùng `(localdb)\MSSQLLocalDB`, database `GundamShopDb`. Để dùng SQL Server chung của nhóm, đổi `ConnectionStrings:Shop` bằng environment variable, ví dụ:

```powershell
$env:ConnectionStrings__Shop = 'Server=localhost;Database=GundamShopDb;User Id=sa;Password=<mật-khẩu>;Encrypt=True;TrustServerCertificate=True'
```

Không commit mật khẩu vào `appsettings.json`. Chạy migration:

```powershell
dotnet restore GundamShop.slnx --configfile NuGet.Config
dotnet ef database update --project GundamShop.Dal --startup-project GundamShop.Api
```

Nếu chưa có `dotnet ef`, cài công cụ EF Core 8 (`dotnet tool install --global dotnet-ef --version 8.0.30`). Trong Development, đặt `Database__AutoMigrate=true` và chạy API một lần để cập nhật database, đồng thời tạo dữ liệu mẫu. Seed không chạy ở Production, không xóa dữ liệu sẵn có; dữ liệu gồm admin, danh mục HG/MG, hai sản phẩm và hai SKU.

```powershell
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$env:Database__AutoMigrate = 'true'
dotnet run --project GundamShop.Api --urls http://127.0.0.1:5288
```

Mở `http://127.0.0.1:5288/swagger`. Dùng `admin@gundam.local` / `Admin123!` để demo, và đổi mật khẩu/khóa JWT trước khi chia sẻ môi trường. JWT key demo chỉ có trong `appsettings.Development.json`. Ở môi trường khác, cung cấp `Jwt__Key` dài ít nhất 32 byte.

## 3. Chức năng và ai phụ trách

| Người | Phân hệ | Bộ CRUD hoàn chỉnh |
| --- | --- | --- |
| Thành viên 1 | Đăng ký, đăng nhập, hồ sơ, địa chỉ | Địa chỉ (`/addresses`) |
| Thành viên 2 | Danh mục, sản phẩm, OData | Danh mục và sản phẩm |
| Thành viên 3 | SKU, giá, tồn kho | SKU (`/variants`) |
| Thành viên 4 | Giỏ, đặt hàng, trạng thái đơn | Mục giỏ (`/cart/items`) |
| Thành viên 5 | Voucher, đánh giá, thanh toán | Voucher và đánh giá |

File Excel `GundamShop_PhanCong.xlsx` liệt kê 48 chức năng/endpoint, phương thức HTTP, quyền và bộ CRUD. Trong `ShopRoutes.cs`, các nhóm endpoint khớp số thành viên. Trong BLL, tìm `AuthService`, `CatalogService`, `ShoppingService`, `PromotionService`, `PaymentService`. Các lớp tương ứng trong DAL nằm ở `Entities.cs` và `ShopDbContext.cs`.

## 4. Thử một đơn hàng từ đầu đến cuối

1. `POST /api/v1/auth/register` với `email`, `password`, `fullName`; lưu `accessToken`.
2. `POST /api/v1/addresses` với `recipient`, `phone`, `line1`, `ward`, `district`, `province`, `isDefault`; lưu `id` địa chỉ.
3. `GET /api/v1/products`, rồi `GET /api/v1/products/{id}/variants`; lưu `id` SKU.
4. `POST /api/v1/cart/items` với `variantId`, `quantity`.
5. `POST /api/v1/orders` với `addressId`, `voucherCode` (có thể `null`). API chốt giá tại thời điểm mua, trừ và giữ tồn kho trong transaction, tạo đơn `PendingPayment`.
6. `POST /api/v1/payments/orders/{orderId}/session`. Với provider mặc định `Mock`, response không có checkout URL.
7. Chỉ trong Development, `POST /api/v1/payments/mock/orders/{orderId}/complete` với `{ "succeeded": true }` hoặc `false`. Thành công đưa đơn sang `Paid`; thất bại hoàn tồn kho và lượt voucher. Admin chuyển `Paid → Shipped → Delivered` bằng `PUT /api/v1/orders/{id}/status`.
8. Chỉ người đã nhận hàng mới được `POST /api/v1/reviews` cho sản phẩm đã mua.

Ví dụ PowerShell đăng nhập admin và thử API:

```powershell
$base = 'http://127.0.0.1:5288'
$login = Invoke-RestMethod -Method Post -Uri "$base/api/v1/auth/login" -ContentType 'application/json' -Body '{"email":"admin@gundam.local","password":"Admin123!"}'
$headers = @{ Authorization = "Bearer $($login.accessToken)" }
Invoke-RestMethod -Uri "$base/api/v1/vouchers" -Headers $headers
Invoke-RestMethod -Uri "$base/odata/Products?`$filter=Grade eq 'HG'&`$top=10"
```

`DELETE` của danh mục/sản phẩm/SKU/voucher là **ngừng sử dụng** (`IsActive=false`) để giữ lịch sử đơn. Giỏ, địa chỉ và đánh giá được xóa thật. Đơn chưa trả có thể hủy; đơn đã trả không có thao tác hoàn tiền tự động. Mọi đơn chờ quá 24 giờ được tác vụ nền đóng lại và hoàn tồn kho. Nếu Stripe thông báo thanh toán thành công sau khi đơn đã đóng, đơn nhận trạng thái `RefundRequired` để admin xử lý thủ công.

## 5. Thanh toán Mock và Stripe

Trong Development, `Payments:Provider` mặc định là `Mock`. Endpoint mock chỉ được đăng ký trong Development và không gọi mạng ngoài.

### Chạy Stripe ở chế độ thử

Chế độ thử (test mode) dùng trang Stripe Checkout thật và webhook thật, nhưng trả bằng thẻ thử nên không mất tiền. Cần ba thứ:

1. Tài khoản Stripe. Chế độ thử dùng được ngay, không cần kích hoạt; lấy secret key `sk_test_...` ở Dashboard → Developers → API keys.
2. [Stripe CLI](https://docs.stripe.com/stripe-cli) để chuyển webhook về máy: chạy `stripe login`, rồi lệnh dưới. Lệnh này in ra webhook secret `whsec_...` và phải chạy suốt lúc thử. `--events` giới hạn ở bốn sự kiện API dùng; API trả 200 và bỏ qua các sự kiện khác (`payment_intent.*`, `charge.*`).

```powershell
stripe listen --events checkout.session.completed,checkout.session.async_payment_succeeded,checkout.session.async_payment_failed,checkout.session.expired --forward-to http://127.0.0.1:5288/api/v1/payments/stripe/webhook
```

3. Chạy API với khóa thử:

```powershell
$env:Payments__Provider = 'Stripe'
$env:Payments__Stripe__SecretKey = 'sk_test_...'
$env:Payments__Stripe__WebhookSecret = 'whsec_...'
dotnet run --project GundamShop.Api --urls http://127.0.0.1:5288
```

Android Emulator (`10.0.2.2`) và Edge đều tới được `127.0.0.1` của máy. Chỉ dùng `--urls http://0.0.0.0:5288` khi thử bằng điện thoại thật, và đổi mật khẩu admin mẫu trước: địa chỉ này mở Swagger và tài khoản admin mẫu cho mọi máy trong mạng LAN.

Trong Development không cần đặt `SuccessUrl`/`CancelUrl`: khi để trống, API đưa khách về trang `/payment/success` và `/payment/cancel` của chính nó, theo địa chỉ app đã gọi (Android Emulator: `http://10.0.2.2:5288`, Edge: `http://127.0.0.1:5288`). Ngoài Development, API không tin địa chỉ do request gửi lên, nên phải đặt `Payments__Stripe__SuccessUrl` và `Payments__Stripe__CancelUrl`, nếu không sẽ trả 503 "Cần cấu hình Stripe SuccessUrl và CancelUrl.".

Trong app: đặt hàng → **Thanh toán** → **Mở Stripe Checkout** → trả bằng thẻ `4242 4242 4242 4242`, ngày hết hạn bất kỳ trong tương lai, CVC bất kỳ → quay lại app. Khi quay lại, màn thanh toán đọc lại đơn một lần; nếu webhook chưa tới thì bấm **Tôi đã thanh toán, tải lại trạng thái**. Thẻ `4000 0000 0000 0002` bị Stripe từ chối ngay trên trang Stripe: đơn vẫn **Chờ thanh toán**, khách thử thẻ khác hoặc hủy đơn. [Thẻ thử của Stripe](https://docs.stripe.com/testing).

Cách API xử lý phiên Stripe:

- `expires_at` của phiên là 24 giờ sau lúc đặt đơn trừ 5 phút (giờ UTC), tức trang Stripe hết hạn trước hạn đơn 5 phút. Stripe chỉ nhận tối đa 24 giờ kể từ lúc tạo phiên; 5 phút này phòng giờ máy chạy API lệch với Stripe. Giá trị chỉ tính từ đơn, không theo giờ gọi, nên gọi lại gửi đúng yêu cầu cũ (cùng `Idempotency-Key`) và nhận lại cùng một trang. Trang còn dưới 35 phút (đơn còn dưới 40 phút) thì không mở phiên mới (409 "Đơn sắp hết hạn, hãy tạo đơn mới.").
- Hai yêu cầu mở phiên cho cùng một đơn chạy cùng lúc (bấm hai lần): Stripe từ chối khóa đang được dùng (`idempotency_key_in_use`), API đợi rồi gửi lại (tối đa 3 lần, 0,5 → 1 → 2 giây) và nhận cùng trang đó; hết lượt thì trả 409 "Trang thanh toán của đơn đang được tạo, hãy thử lại sau vài giây.". Nếu hai yêu cầu khác địa chỉ nên tạo ra hai trang, chỉ trang được lưu trước được trả cho khách, trang còn lại bị đóng ngay.
- Stripe trả lại lỗi 5xx đã lưu cho mọi lần gọi lại cùng khóa, nên sau một lỗi 5xx API thử ngay một lần với khóa mới để đơn vẫn thanh toán được.
- Webhook `checkout.session.expired` của phiên đã tới `expires_at` (trước hạn đơn 5 phút) đưa đơn sang `Expired`; `checkout.session.async_payment_failed` đưa sang `PaymentFailed`. Cả hai đều hoàn tồn kho và lượt voucher. Phiên bị đóng sớm hơn `expires_at` là do chính API đóng (hủy đơn, tác vụ nền), nên webhook hết hạn của nó không đổi đơn; việc đóng đơn do thao tác hủy/tác vụ nền làm.
- Khi khách/Admin hủy đơn, hoặc tác vụ nền đóng đơn quá hạn, API đóng phiên Stripe trước (`POST /v1/checkout/sessions/{id}/expire`) để trang Stripe không thu tiền cho đơn đã đóng. Nếu Stripe báo phiên đã được trả, đơn chuyển `Paid`; khách hủy lúc đó nhận 409 "Đơn vừa được thanh toán qua Stripe nên không hủy được.". Nếu Stripe không còn phiên đó (đã đổi tài khoản/khóa), việc hủy vẫn tiếp tục. Nếu không gọi được Stripe, tác vụ nền thử lại mỗi phút; quá hạn 30 phút thì vẫn đóng đơn (Stripe đã tự hết hạn phiên trước hạn đơn 5 phút).
- Hủy đơn đúng lúc API đang tạo phiên: API kiểm tra lại đơn sau khi Stripe trả phiên; đơn đã hủy thì đóng phiên đó và trả 409 "Đơn không chờ thanh toán.", nên khách không nhận được trang thanh toán cho đơn đã hủy.
- Đơn có tổng tiền dưới mức tối thiểu hoặc trên mức tối đa Stripe thu được trả 409 ("Số tiền đơn quá nhỏ…" / "Số tiền đơn vượt mức Stripe cho phép…") thay cho 502. Các lỗi khác từ Stripe được ghi log (mã lỗi và thông báo của Stripe) để tra cứu.
- Đơn tạo lúc provider còn là `Mock` vẫn thanh toán được sau khi chuyển sang `Stripe`.

`POST /api/v1/payments/orders/{id}/session` tạo Stripe-hosted Checkout Session và trả `checkoutUrl`. VND là tiền không có phần thập phân, nên `120000` được gửi lên Stripe là **120.000 VND**, không nhân 100. [Tài liệu tiền tệ Stripe](https://docs.stripe.com/currencies).

Đăng ký webhook Stripe tới `POST /api/v1/payments/stripe/webhook`. API kiểm tra `Stripe-Signature` (HMAC SHA-256 và thời gian 5 phút), chỉ cập nhật đơn sau sự kiện server từ Stripe, ghi `eventId` để tránh xử lý lặp. Redirect về trang thành công **không** tự đánh dấu đơn đã trả. Stripe khuyên hoàn tất đơn từ webhook. [Stripe Checkout và webhook](https://docs.stripe.com/payments/existing-customers?platform=web&ui=stripe-hosted).

Khi triển khai thật sau này, dùng HTTPS, đặt `Payments__Provider=Stripe`, khóa/secret qua biến môi trường hoặc secret manager, và chỉ bật `Payments__Stripe__AllowLive=true` trong Production nếu đã có `sk_live_...` cùng webhook live. Giá, tồn kho, voucher và đối soát cần được kiểm thử lại với tài khoản Stripe đủ điều kiện trước khi mở cho khách.

Stripe hiện chưa liệt kê Việt Nam trong danh sách nơi mở tài khoản Stripe trực tiếp, dù VND là đồng tiền có thể hiển thị/thu. Vì vậy bản demo dùng Mock hoặc Stripe chế độ thử, và không cam kết thu tiền thật bằng tài khoản doanh nghiệp Việt Nam. [Stripe global availability](https://stripe.com/global).

## 6. Kết nối Flutter

Flutter chỉ cần gửi request HTTPS và đọc JSON. Đặt base URL theo máy chạy API; nếu dùng Android emulator với server trên cùng máy, thường dùng địa chỉ mạng của host thay vì `localhost` của emulator. Lưu JWT an toàn trong ứng dụng; gửi `Authorization: Bearer <token>` cho request cần quyền. Với danh sách sản phẩm, có thể dùng REST `GET /api/v1/products?page=1&pageSize=20` hoặc OData. Giá là số nguyên VND, thời gian UTC dạng ISO 8601, ID là GUID dạng chuỗi. Dùng `status` HTTP và `title` của Problem Details để hiển thị lỗi cho người dùng.

Để demo Flutter trong Edge trên cùng máy, chạy API ở `http://127.0.0.1:5288` và truyền `--dart-define=API_BASE_URL=http://127.0.0.1:5288` cho Flutter. Android Emulator dùng `http://10.0.2.2:5288`. API chỉ cho phép CORS từ origin `localhost` hoặc `127.0.0.1` (cổng bất kỳ) trong môi trường Development. Sau khi cập nhật API, phải khởi động lại tiến trình backend để nhận cấu hình CORS mới.

## 7. Kiểm thử và giới hạn hiện tại

Khi API chạy ở `http://127.0.0.1:5288`, gọi:

```powershell
./tests/smoke.ps1
```

Script tạo dữ liệu test có hậu tố ngẫu nhiên và thử 5 bộ CRUD, đơn có voucher, thanh toán mock thành công/thất bại, hoàn tồn kho, đánh giá sau giao hàng và OData. Stripe thật cần test key, webhook secret và tài khoản hợp lệ; bản demo không gọi Stripe mặc định. Các mục chưa có trong v1: giao diện React/Flutter, hoàn tiền tự động, phí vận chuyển, thuế, cổng vận chuyển.

Để thử webhook Stripe **mà không gọi mạng Stripe**, chạy API ở Development với `Payments__Provider=Stripe`, `Payments__Stripe__SecretKey=sk_test_unused`, `Payments__Stripe__WebhookSecret=whsec_local_test` trên cổng `5289`, rồi chạy `./tests/stripe-webhook.ps1`. Script dùng `sqlcmd` để gắn session ID giả vào đơn thử trong LocalDB, gửi webhook có chữ ký HMAC, gửi lại cùng event để kiểm tra xử lý một lần, và thử chữ ký sai. Đây là kiểm thử logic webhook; không xác nhận API Checkout Session thật của Stripe.

Để thử **cả luồng Stripe mà không cần tài khoản Stripe** (mở phiên, bấm hai lần, Stripe lỗi 500, hủy đơn khi trang Stripe đang mở hoặc đang được tạo, trả tiền sát hạn, đơn quá hạn hoặc sắp hết hạn, đơn quá nhỏ/quá lớn, webhook), dùng máy chủ đóng vai Stripe. Script **ghi dữ liệu thật vào database của API** (một danh mục, sản phẩm/SKU, một khách, voucher và khoảng 20 đơn) và không xóa đi, nên chạy với database riêng:

```powershell
python tests/stripe_stub.py
# cửa sổ khác:
$env:ConnectionStrings__Shop = 'Server=(localdb)\MSSQLLocalDB;Database=GundamShopE2E;Trusted_Connection=True;TrustServerCertificate=True'
$env:Database__AutoMigrate = 'true'
dotnet run --project GundamShop.Api --urls http://127.0.0.1:5288 --Payments:Provider=Stripe --Payments:Stripe:SecretKey=sk_test_local_stub --Payments:Stripe:WebhookSecret=whsec_local_test --Payments:Stripe:ApiBase=http://127.0.0.1:12111
# cửa sổ thứ ba:
python tests/stripe_e2e.py http://127.0.0.1:5288 http://127.0.0.1:12111 GundamShopE2E
```

Cần Python 3, `sqlcmd` tới LocalDB `MSSQLLocalDB`, và tài khoản admin mẫu `admin@gundam.local` (có sau khi seed ở mục 2, chưa đổi mật khẩu). Tham số thứ ba là tên database mà API đang dùng; script dừng với lỗi nếu lệnh `sqlcmd` không sửa được dòng nào. `Payments:Stripe:ApiBase` chỉ dùng cho kiểm thử này; mặc định API gọi `https://api.stripe.com`. Script mất vài phút vì chờ tác vụ nền đóng đơn quá hạn.
