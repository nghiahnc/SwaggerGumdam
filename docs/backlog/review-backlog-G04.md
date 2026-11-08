# Review backlog G04 – PRM393 (đối chiếu `G04_PRM393_Backlog.xlsx`)

## Review lại toàn bộ 08/11/2026: hard code, màn hình UI, chạy test (chưa commit)

### Kết quả chạy
| Kiểm tra | Kết quả |
|---|---|
| `flutter analyze` | Không có lỗi |
| `flutter test` | **228/228 pass** (223 của lần sửa trước + 5 test phân trang mới) |
| `dotnet build GundamShop.slnx` | 0 cảnh báo, 0 lỗi |
| API thật (LocalDB, Development, `verify_api.py`) | **18/18 pass** (UC03, 05, 10, 14, 30) |
| `tests/stripe_e2e.py` | Không chạy lại vì lần này không sửa code API. Script này cũng tự thêm dữ liệu vào DB |
| `tests/smoke.ps1` | Chưa chạy, vì máy không có PowerShell 7 |

### UC nào chưa có màn hình
Mình đối chiếu mọi route trong `ShopRoutes.cs` với lời gọi từ Flutter, và mọi hàm trong `ShopRepository`/`SessionController` với màn hình gọi đến nó.
- **50/50 UC đều có màn hình**, trừ **UC50** (`POST /payments/stripe/webhook`). Webhook do Stripe gọi vào server, nên app không có màn hình là đúng thiết kế. Phía app, màn thanh toán chỉ đọc lại trạng thái đơn mà webhook đã cập nhật.
- Có một hàm repository mà không màn hình nào gọi: `products({page})` (gọi `/api/v1/products?pageSize=20`). Màn admin dùng `adminProducts()`, catalog thì dùng OData. **Đã xóa** hàm này.

### Hard code đã sửa
| Chỗ | Vấn đề | Sửa | File (chủ UC) |
|---|---|---|---|
| Danh sách admin: danh mục, sản phẩm, SKU | Gọi `pageSize=100` đúng một lần, nên từ dòng thứ 101 trở đi bị mất mà không báo gì | Dùng `_allPages(...)` để đọc đến hết | `shop_repository.dart`: `categories()`/`adminProducts()` (Tài UC16, UC21), `variants()` (Hưng UC13) |
| Số đơn mỗi trang | Số `20` viết ở hai nơi (repository và màn Đơn). Lệch nhau thì nút "Trang sau" sai | `ShopRepository.ordersPageSize` | `shop_repository.dart`, `screens/orders.dart` (Đạt UC34) |
| Giới hạn số lượng trong giỏ | `1`/`99` viết ở hai nơi | `minCartQuantity`/`maxCartQuantity` | `core/cart_policy.dart`, `screens/cart.dart` (Đạt UC29–31) |
| Chuỗi trạng thái đơn và thanh toán | `'Paid'`, `'PendingPayment'`, `'Shipped'`… gõ lại ở 5 file | `OrderStatus.*`, `PaymentStatus.*`, `OrderStatus.isPaid()` | `core/order_status.dart`, `screens/orders.dart` (Đạt UC34–37), `core/payment_policy.dart`, `screens/payment.dart` (Hiếu Nghĩa UC48–49) |
| Vai trò `'Admin'` và provider `'Mock'` | Chuỗi rời | `SessionController.adminRole`, `PaymentPolicy.mockProvider` | `core/session.dart` (Nghĩa), `core/payment_policy.dart` (Hiếu Nghĩa) |

Test mới: `test/repository_paging_test.dart`, gồm P1–P5:
- 250 danh mục được đọc đủ qua 3 trang.
- 101 sản phẩm và 130 SKU được đọc đủ.
- Dưới 100 dòng thì chỉ gọi API một lần.
- Màn Đơn gửi đúng `pageSize` mà nó dùng để phân trang.

### Hard code cố ý giữ lại
- `main.dart`: địa chỉ API mặc định `127.0.0.1:5288` (Android emulator dùng `10.0.2.2:5288`). Đây là cổng ghi trong README, và có thể đổi bằng `--dart-define=API_BASE_URL=...`.
- `catalogGrades` (HG/RG/MG/PG…): đúng danh sách trong spec.
- Gợi ý thẻ test Stripe `4242…`: chỉ là chữ hướng dẫn.
- Giá trị mặc định `maxUses = 100` trong form voucher: người dùng sửa được.
- Phía API (dùng chung với PRN232, không sửa ở đây):
  - Tài khoản seed `admin@gundam.local` chỉ tạo khi chạy Development + AutoMigrate.
  - JWT hết hạn sau 8 giờ.
  - Hạn thanh toán 24 giờ đang lặp ở cả `ShoppingService` và `PaymentService`. **Nên gom về cấu hình** nếu PRN232 còn sửa.

### Người phụ trách cần commit thêm
Lần review này sửa thêm file của Hưng, Tài, Đạt và Hiếu Nghĩa, nên bảng chia file bên dưới cần cộng thêm:
- **Tài**: `categories()` và `adminProducts()` trong `shop_repository.dart`, cùng `test/repository_paging_test.dart`.
- **Hưng**: `variants()` trong `shop_repository.dart`.
- **Đạt**:
  - `core/cart_policy.dart` và `screens/orders.dart`
  - `core/order_status.dart` (`OrderStatus`, nhãn và gợi ý trạng thái)
  - `ordersPageSize` trong `shop_repository.dart`
- **Hiếu Nghĩa**:
  - `core/payment_policy.dart` và `screens/payment.dart`
  - phần `PaymentStatus` trong `order_status.dart`
- **Nghĩa**: `adminRole` trong `session.dart`. Hàm `products()` vừa bị xóa cũng do Nghĩa viết (`60b4e16`).

`order_status.dart` và `shop_repository.dart` chứa phần của nhiều người. Như đã ghi ở mục dưới, hãy commit file dùng chung trước, hoặc dùng `git add -p`.

## Sửa ngày 08/11/2026 (chưa commit, trên `ef75a0d`)

### Code Flutter đã sửa

| UC | Lỗi | Cách sửa | Test mới |
|---|---|---|---|
| UC03 | Flutter không gọi `/auth/me` | `SessionController.loadProfile()`. `AccountScreen` đọc hồ sơ từ API mỗi khi có người đăng nhập (kể cả đăng nhập ngay trên tab). Lỗi 401 báo hết phiên và giữ thông tin cũ, có nút tải lại | `account_screen_test.dart` A1–A4 |
| UC01, UC02 | Không có widget test cho `AuthScreen` | Không sửa code | `account_screen_test.dart` L1–L3, R1–R2 |
| UC05 | Không gọi `GET /addresses/{id}` | Bấm vào địa chỉ mở `AddressDetailScreen`, sửa/xóa được từ đó, quay về thì tải lại danh sách | `addresses_screen_test.dart` D3–D6 |
| UC04, 06–08 | Không có widget test cho `AddressesScreen` | Không sửa code | `addresses_screen_test.dart` D1–D2, D7–D10 |
| UC10 | Không đổi được thứ tự sắp xếp | `CatalogSort` gồm 4 thứ tự (tên A→Z, Z→A, giá thấp→cao, cao→thấp). Mỗi thứ tự kết thúc bằng `Name,Id` để phân trang ổn định. Đổi thứ tự thì về trang 1 | `catalog_sort_test.dart` S1–S6 |
| UC10 | (Phát hiện khi chạy API thật) "Giá thấp → cao" đưa sản phẩm **chưa có giá** lên đầu, vì SQL Server xếp NULL trước | Dùng `$orderby=FromPriceVnd eq null,FromPriceVnd,Name,Id` | S1 |
| UC14 | Không gọi `GET /variants/{id}` | Mỗi SKU có nút ⓘ riêng mở `VariantDetailScreen`. Nút này không đổi SKU đang chọn, và SKU hết hàng vẫn xem được | `variant_detail_test.dart` V1–V5 |
| UC30 | Không gọi `GET /cart/items/{id}` | Nút ⓘ trên thẻ giỏ mở `CartItemDetailScreen`, quay về thì tải lại giỏ | `cart_item_detail_test.dart` G1–G4 |

File đã sửa, chia theo người phụ trách. Không sửa API.

| Người | UC | File |
|---|---|---|
| Huỳnh Nguyễn Chí Nghĩa | UC01–08 | `core/session.dart`, `screens/account.dart`, `screens/addresses.dart`, `test/account_screen_test.dart`, `test/addresses_screen_test.dart`, hàm `address()` trong `shop_repository.dart` |
| Ngô Quốc Hưng | UC10, UC14 | `screens/catalog.dart`, `screens/product.dart`, `test/catalog_sort_test.dart`, `test/variant_detail_test.dart`, `enum CatalogSort` + tham số `sort` + hàm `variant()` trong `shop_repository.dart` |
| Trần Gia Đạt | UC30 | `screens/cart.dart`, `test/cart_item_detail_test.dart`, hàm `cartItem()` trong `shop_repository.dart` |

`shop_repository.dart` chứa phần sửa của cả ba người. Nếu ai commit màn hình mà thiếu hàm tương ứng thì build sẽ lỗi. Có hai cách:
- Mỗi người chọn đúng phần của mình bằng `git add -p`.
- Commit `shop_repository.dart` chung một lần trước, rồi mới commit các file màn hình.

### Đã kiểm tra
- `dart format`: sạch. `flutter analyze`: không có lỗi. `flutter test`: **223/223 pass** (189 cũ + 34 mới). `dotnet build`: 0 lỗi.
- **Chạy API thật** (LocalDB, Development) bằng script tạo dữ liệu biên: sản phẩm chưa có giá, hai sản phẩm trùng giá, hai tài khoản. **18/18 pass**:
  - `/auth/me` đúng tài khoản. Không có token thì 401.
  - `GET /addresses/{id}` và `GET /cart/items/{id}` của người khác đều 404.
  - `GET /variants/{id}`: khách nhận 404 với SKU đã ngừng bán, admin vẫn đọc được.
  - Cả 4 `$orderby` đều trả 200 và đúng thứ tự. Sản phẩm không giá nằm cuối. Trùng giá thì xếp theo tên. Phân trang `$skip` cho ra cùng thứ tự với khi lấy một trang.
  - Gộp bộ lọc tên, grade và sắp xếp trong một request vẫn trả 200 (không vượt `MaxNodeCount`).
- Script kiểm tra để lại dữ liệu trong LocalDB của máy này: 2 danh mục "Verify …" đã ngừng bán (mỗi danh mục có 3 sản phẩm ngừng bán và 1 SKU ngừng bán), cùng 4 tài khoản `c1-…`/`c2-…@t.local`. Admin vẫn thấy chúng trên màn quản trị. Mình chưa xóa.
- **Chưa chạy**: `tests/smoke.ps1`, vì cần PowerShell 7 mà máy không có. Chưa xem giao diện trên emulator hay web, chỉ có widget test (bao gồm màn 320 px).

### Excel đã sửa (`Downloads/G04_PRM393_Backlog.xlsx`)
- Có 44 ô thay đổi, chỉ ở các cột Status, Flutter Code, Member Commit và ô ghi chú B22 của Summary. Công thức, validation, comment và style giữ nguyên.
- Đã bật tính lại công thức khi mở file (máy không có LibreOffice để tính sẵn).
- Bản gốc được lưu tại `C:\Users\lorem\AppData\Local\Temp\claude\d255568488dc7d7d\78e1df80-c2ae-4ebf-bc40-b925a1f73bb9\scratchpad\xlsx\G04_PRM393_Backlog.orig.xlsx`.
- Tham chiếu dòng được tính tự động theo hàm tại `ef75a0d`. Member Commit là commit của **đúng người phụ trách** có nhiều dòng nhất trong đoạn đó (`git blame`).
- **Status**: UC17, UC23, UC44, UC49 chuyển sang Completed. Tổng: 44 Completed / 6 In Progress.
  - In Progress còn lại: UC03, 05, 10, 14, 30 (đã sửa nhưng chưa commit) và UC50 (webhook do Stripe gọi, Flutter không gọi).
- **Tham chiếu dòng**: cập nhật UC16–28, UC33, UC39–47, UC49–50.
- **Commit**: cập nhật UC16–20 → `fc49da4`, UC22–23 → `78a9ccd`, UC25/26/28 → `05aa0c4`, UC33 → `5afc369`, UC39 → `bfecf85`, UC41 → `fb0c1e6`, UC44 → `f45f7bb`, UC49 → `e6b9a7e`, UC50 → `e78f6bc`.
- **Chưa sửa, cần người phụ trách quyết định.** Theo `git blame` tại `ef75a0d`, người phụ trách viết **dưới một nửa** số dòng trong đoạn được trích dẫn. Phần còn lại là `60b4e16` của nghiahnc. Mình giữ nguyên giá trị ô:

  | UC | Đoạn code | Dòng của người phụ trách | Commit đang ghi |
  |---|---|---|---|
  | UC21 | admin_catalog.dart L29-33 | Tài 0/5 | dfbe403 |
  | UC24 | admin_catalog.dart L51-59 | Tài 3/9 | fc49da4 (commit này gắn tag UC16-20) |
  | UC27 | admin_inventory.dart L78-88 | Tài 0/11 | dfbe403 |
  | UC29 | cart.dart L27-31 | Đạt 0/5 | 9cdf3c2 |
  | UC31 | cart.dart L45-56 | Đạt 5/12 | bd2b3bc |
  | UC32 | cart.dart L58-72 | Đạt 4/15 | bd2b3bc |
  | UC33 | checkout.dart L53-99 | Đạt 21/47 | 5afc369 |
  | UC34 | orders.dart L111-115 | Đạt 0/5 | 9cdf3c2 |
  | UC35 | orders.dart L319-321 | Đạt 0/3 | 9cdf3c2 |
  | UC36 | orders.dart L323-337 | Đạt 3/15 | e4e7022 |
  | UC37 | orders.dart L339-359 | Đạt 10/21 | e4e7022 |
- **Phải mở file bằng Excel desktop rồi Save một lần trước khi nộp hoặc chia sẻ.** openpyxl không lưu sẵn kết quả công thức. Nếu xem trên web, LMS hoặc bằng pandas, sheet Summary sẽ trống cho đến khi Excel lưu lại.
  - UC01–15 và UC29–32: các file này vừa được mình sửa, nên số dòng sẽ đổi. **Cần đánh số lại sau khi commit.**
- Sau khi các bạn commit phần sửa: chuyển UC03/05/10/14/30 sang Completed và điền commit mới.

### Còn để lại (thuộc API dùng chung với repo PRN232, không sửa ở đây)
- UC13: API sắp theo `Sku`, trong khi mô tả ghi "ordered by ID".
- UC43: review chỉ trả `UserId`, không có tên người viết.

---

## Cập nhật 08/11/2026: bản gộp mới `ef75a0d`

Nghĩa đã gộp thêm 13 commit (`dbfa118..ef75a0d`): 7 commit UC16–28 của Tài và 5 commit FL-13..15 của Hiếu Nghĩa. Đã pull fast-forward. Kết quả kiểm tra:
- `flutter test` → **189/189 pass** (trước đó 162).
- `dotnet build` → 0 lỗi.
- Nhóm có lưu kết quả Stripe e2e trong `qa/stripe-e2e-2026-11-08.txt`: 57/57 pass. Mình không tự chạy lại.

Thay đổi so với review bên dưới (bản `dbfa118`):

| UC | Trước | Bây giờ | Đề xuất status |
|---|---|---|---|
| UC16–20 | Code nằm trong `admin_catalog.dart`, blame cho `60b4e16` (nghiahnc) | Màn mới `admin_categories.dart`, 262/262 dòng do NguyenHuuTai viết (`fc49da4`), cùng `admin_form_dialog.dart` và `admin_categories_test.dart` (C1–C21) | Giữ Completed. **Sửa cột Flutter Code sang `admin_categories.dart` và Member Commit sang `fc49da4`** |
| UC17 | Flutter không gọi `GET /categories/{id}` | `CategoryDetailScreen` gọi `repo.category(id)` (admin_categories.dart:117), có test C11, C12 | **In Progress → Completed** |
| UC21–24 | Code của nghiahnc | `admin_catalog.dart`: editProduct L36-50 phần lớn do `78a9ccd` (Tài). reload L29-35 và remove L51-64 vẫn chủ yếu là `60b4e16` | Sửa tham chiếu dòng. Member Commit UC22/23 → `78a9ccd` |
| UC23 | Chưa có test sửa sản phẩm | Có C13 (PUT), C14 (409 trùng slug), C16 | **In Progress → Completed** |
| UC25–28 | Code của nghiahnc | `admin_inventory.dart`: edit L46-61 và adjust L62-77 phần lớn do `05aa0c4` (Tài). remove L78-92 (UC27) vẫn 100% `60b4e16` | Sửa tham chiếu dòng. Member Commit UC25/26/28 → `05aa0c4`. UC27 vẫn chưa có dòng nào của Tài |
| UC26 | Bật lại được SKU của sản phẩm đã ngừng bán | BLL chặn việc này (`CatalogService.UpdateVariant`), có test I15 | Đã xử lý |
| UC39 | Chỉ đọc voucher trước khi sửa | Có màn chi tiết riêng (vouchers.dart:317, `bfecf85`), có `voucher_detail_screen_test.dart` | Giữ Completed, cập nhật dòng và commit |
| UC44 | Flutter không gọi `GET /reviews/{id}` | Màn chi tiết gọi `repo.review(id)` (reviews.dart:250, `f45f7bb`), có 3 test mới | **In Progress → Completed** |
| UC50 | Webhook đã đủ luật | Thêm chặn payload hỏng hoặc thiếu id phiên (trả 400 thay vì 500), `4d02a4b` | Có thể Completed (e2e 57/57) |
| UC49 | — | Không đổi | Có thể Completed (e2e 57/57) |

Vẫn còn tồn tại:
- UC03, 05, 14, 30: Flutter vẫn chưa gọi `/auth/me`, `GET /addresses/{id}`, `GET /variants/{id}`, `GET /cart/items/{id}`.
- UC10: chưa có UI đổi thứ tự sắp xếp.
- UC27: đoạn code ngừng bán SKU chưa có dòng nào của Tài.
- Tiêu chí "có test" của UC01/06/07/08 vẫn chưa thống nhất.
- Cột commit của UC29/34/35 và UC49/50 vẫn sai như mục bên dưới.
- Mọi tham chiếu dòng Flutter của UC16–28 trong Excel giờ đều lệch, vì các file đã được viết lại.

---

*Phần dưới là review bản `dbfa118`.*

- Nhánh: `nghiahnc/merge-prm393-features`, commit `dbfa118` (đã pull, fast-forward 9 commit).
- Ngày review: 08/11/2026.
- Đã chạy: `flutter test` → **162/162 pass**; `dotnet build GundamShop.slnx` → **0 lỗi**.
- **Chưa chạy** API thật: `tests/smoke.ps1` và `tests/stripe_e2e.py` cần SQL Server và stub Stripe. Hành vi API dưới đây được review bằng cách đọc code BLL.
- Test Flutter chạy trên API giả (`test/support/*fake*`), nên chỉ chứng minh màn hình gọi đúng route. Luật nghiệp vụ phía server được kiểm bằng cách đọc `GundamShop.Bll/*.cs`.

Chú thích các cột:
- **Route**: tham chiếu `e7eb6c1 · Lxx` trỏ đúng route trong `ShopRoutes.cs` hay không.
- **Gọi**: Flutter (`shop_repository.dart`) có gọi route đó không.
- **Test**: F = widget/unit test Flutter, S = `smoke.ps1`, E = `stripe_e2e.py`.
- **BLL**: code BLL có đáp ứng các luật trong cột Details không.
- **Status**: trạng thái ghi trong Excel có khớp tiêu chí của sheet Summary (*có route + Flutter gọi + có test*) không.

## Kết luận nhanh

- Cả 50 tham chiếu API đều đúng dòng. Các đoạn code Flutter đều tồn tại và đúng chức năng, trừ những chỗ ghi chú bên dưới.
- 10 UC "In Progress" đều có lý do cụ thể, xem từng dòng.
- Có 3 vấn đề cần sửa trong Excel:
  1. **Cột Member Commit của UC16–28 (Tài)**: `dfbe403` chỉ thêm 4 file test. `git blame` cho thấy toàn bộ code `admin_catalog.dart` và `admin_inventory.dart` trong các đoạn được trích dẫn đến từ `60b4e16` (nghiahnc, khung app ban đầu).
     - Bản viết lại của Tài nằm ở nhánh `feature/tai-uc16-20-categories`. Nhánh này có 7 commit **chưa có trong `dbfa118`**: `8e53712`, `a7674d4`, `9ddbfbd`, `7412770`, `fc49da4`, `78a9ccd`, `05aa0c4`.
     - Các file mới trong nhánh đó: `admin_categories.dart`, `widgets/admin_form_dialog.dart`, `test/admin_categories_test.dart`. Nhánh còn viết lại `admin_catalog.dart` và `admin_inventory.dart`.
     - Sau khi merge nhánh này, cột Flutter Code và Member Commit của UC16–28 phải trỏ sang file và commit mới.
     - Ngoài ra, `feature/tai-fl06-fl08-admin` ở máy local còn commit `653d7ff` chưa push.
  2. **UC29, UC34, UC35 (Đạt)**: đoạn code được trích dẫn có blame 100% là `60b4e16` (nghiahnc), không phải `9cdf3c2`. Commit `9cdf3c2` có sửa các file đó, nhưng ở những dòng khác.
  3. **UC49, UC50**: `c311dae` chỉ sửa API (4 file `.cs`). Code trong `payment.dart` ở các dòng được trích dẫn đến từ `e6b9a7e` và `e78f6bc`.
- **UC01, 06, 07, 08** ghi Completed nhưng không có test Flutter nào, chỉ có `smoke.ps1`. UC02 và UC04 có test Flutter gián tiếp: `admin_home_test` gọi `session.login`, còn test checkout có tải `GET /addresses`. Không có widget test riêng cho `AuthScreen` và `AddressesScreen`.
- **Sheet áp dụng tiêu chí "có test" không đồng nhất.** UC23 bị ghi In Progress, dù `smoke.ps1:28` có gọi `PUT /products`. Nhóm cần chọn một trong hai cách:
  - Tính smoke là test: chuyển UC23 sang Completed.
  - Không tính smoke: chuyển UC01, 06, 07, 08 sang In Progress.
- **UC49, UC50** ghi In Progress, nhưng code BLL đã đủ luật và `stripe_e2e.py` (S1–S8) đã có kịch bản kiểm. Nếu chạy e2e pass thì có thể chuyển sang Completed.

## Chi tiết từng UC

| UC | Chức năng | Route | Gọi | Test | BLL | Status (Excel → nhận xét) | Ghi chú |
|---|---|---|---|---|---|---|---|
| UC01 | Signup | ✓ L11 | ✓ | S | ✓ | Completed → **thiếu test F** | Email trim+lowercase, `MinLength(8)`, PBKDF2 120k, 409 khi trùng email. |
| UC02 | Login | ✓ L12 | ✓ | F (gián tiếp), S | ✓ | Completed ✓ (không có test cho AuthScreen) | Kiểm `IsActive`, so sánh hash bằng FixedTimeEquals, 401 dùng chung một thông báo. |
| UC03 | View Profile | ✓ L13 | ✗ | – | ✓ | In Progress ✓ | Flutter không gọi `/auth/me`, chỉ đọc user lưu trong session (account.dart L34-42). |
| UC04 | Address List | ✓ L16 | ✓ | F (gián tiếp qua checkout) | ✓ | Completed ✓ (không có test cho AddressesScreen) | Default đứng đầu ✓. Smoke không gọi GET list. |
| UC05 | Address Details | ✓ L17 | ✗ | S | ✓ | In Progress ✓ | Không có hàm GET theo id trong repository. Đoạn trích L74-92 là danh sách. |
| UC06 | Add Address | ✓ L18 | ✓ | S | ✓ | Completed → **thiếu test F** | Địa chỉ đầu tiên tự thành default ✓, bỏ default cũ ✓. |
| UC07 | Edit Address | ✓ L19 | ✓ | S | ✓ | Completed → **thiếu test F** | Lưu ý: sửa default thành `false` thì user không còn địa chỉ default (spec không cấm). |
| UC08 | Delete Address | ✓ L20 | ✓ | S | ✓ | Completed → **thiếu test F** | Lưu ý: xóa địa chỉ default thì không tự gán default mới. |
| UC09 | Product Catalog | ✓ OData | ✓ | F | ✓ | Completed ✓ | Giá "từ" = min giá SKU active ✓. |
| UC10 | Search/Filter/Sort | ✓ OData | ✓ một phần | F | ✓ | In Progress ✓ | Có tìm theo tên và lọc grade. **Không có UI đổi thứ tự** (`$orderby=Name` cố định). |
| UC11 | Paginate | ✓ OData | ✓ | F | ✓ | Completed ✓ | Client dùng 20/trang, API giới hạn 50. Mô tả "limits each page to 50" là giới hạn của API. |
| UC12 | Product Details | ✓ L31 | ✓ | F | ✓ | Completed ✓ | |
| UC13 | SKU List | ✓ L35 | ✓ | F | ⚠ | Completed ✓ | Spec ghi "ordered by ID" nhưng BLL sắp theo `Sku`. Nên sửa mô tả hoặc code. |
| UC14 | SKU Details | ✓ L39 | ✗ | S | ✓ | In Progress ✓ | Flutter không gọi `GET /variants/{id}`. Đoạn L147-162 trùng với UC13. |
| UC15 | Add Cart Item | ✓ L48 | ✓ | F, S | ✓ | Completed ✓ | 1–99 ✓, SKU/product/category active ✓, 409 khi SKU đã có trong giỏ ✓. |
| UC16 | Category List | ✓ L23 | ✓ | F (C1) | ✓ | Completed ✓ | **Commit: code từ `60b4e16`**, `dfbe403` chỉ có test. |
| UC17 | Category Details | ✓ L24 | ✗ | – | ✓ | In Progress ✓ | Flutter không gọi `GET /categories/{id}`. Đoạn L97-114 là danh sách. |
| UC18 | Add Category | ✓ L25 | ✓ | F (C2-C4), S | ✓ | Completed ✓ | Slug chỉ trim+lowercase, vẫn nhận khoảng trắng bên trong. **Commit như UC16.** |
| UC19 | Edit Category | ✓ L26 | ✓ | F (C5), S | ✓ | Completed ✓ | **Commit như UC16.** |
| UC20 | Deactivate Category | ✓ L27 | ✓ | F (C6-C7), S | ✓ | Completed ✓ | Chặn khi còn sản phẩm active ✓, xóa mềm ✓. **Commit như UC16.** |
| UC21 | Product List | ✓ L30 | ✓ | F (C1) | ✓ | Completed ✓ | **Commit như UC16.** |
| UC22 | Add Product | ✓ L32 | ✓ | F (C8), S | ✓ | Completed ✓ | Spec không giới hạn grade. Lưu ý: grade nhận chữ tùy ý, nên bộ lọc HG/MG/RG/PG có thể bỏ sót. **Commit như UC16.** |
| UC23 | Edit Product | ✓ L33 | ✓ | S | ✓ | In Progress → tùy cách tính smoke | Code đã gọi PUT. **Chưa có widget test sửa sản phẩm** (C1–C10 không có), nhưng smoke có gọi PUT. |
| UC24 | Deactivate Product | ✓ L34 | ✓ | F (C9), S | ✓ | Completed ✓ | Tắt cả product và mọi SKU ✓. **Commit như UC16.** |
| UC25 | Add SKU | ✓ L40 | ✓ | F (I3-I5), S | ✓ | Completed ✓ | SKU upper ✓, giá ≥1 ✓, tồn ≥0 ✓. **Commit như UC16.** |
| UC26 | Edit SKU | ✓ L41 | ✓ | F (I6), S | ✓ | Completed ✓ | Không sửa mã, product hay tồn ✓. Lưu ý: có thể bật lại SKU của product đã ngừng bán. |
| UC27 | Deactivate SKU | ✓ L42 | ✓ | F (I10), S | ✓ | Completed ✓ | **Commit như UC16.** |
| UC28 | Adjust Stock | ✓ L43 | ✓ | F (I7-I9), S | ✓ | Completed ✓ | Delta ≠ 0, kết quả nằm trong 0..int.Max ✓. RowVersion chống ghi đè, xung đột trả 409. **Commit như UC16.** |
| UC29 | View Cart | ✓ L46 | ✓ | F | ✓ | Completed ✓ | **Commit: L27-31 blame `60b4e16`**, không phải `9cdf3c2`. |
| UC30 | Cart Item Details | ✓ L47 | ✗ | – | ✓ | In Progress ✓ | Flutter không gọi `GET /cart/items/{id}`. Đoạn L152-247 là widget thẻ dòng giỏ. |
| UC31 | Update Quantity | ✓ L49 | ✓ | F, S | ✓ | Completed ✓ | |
| UC32 | Remove Cart Item | ✓ L50 | ✓ | F | ✓ | Completed ✓ | |
| UC33 | Place Order | ✓ L55 | ✓ | F, S | ✓ | Completed ✓ | Transaction Serializable, trừ tồn, voucher, tạo Payment, xóa giỏ ✓. Code trích dẫn blame chủ yếu `60b4e16`, `5afc369`, `0dc03ee` chứ không phải `b3319c2`. |
| UC34 | Order List | ✓ L53 | ✓ | F | ✓ | Completed ✓ | Mới nhất trước ✓, admin xem tất cả ✓. **Commit: blame `60b4e16`.** |
| UC35 | Order Details | ✓ L54 | ✓ | F, S | ✓ | Completed ✓ | **Commit: blame `60b4e16`.** |
| UC36 | Cancel Unpaid | ✓ L56 | ✓ | F | ✓ | Completed ✓ | Hoàn tồn và voucher trong transaction ✓. Route hiện tại còn đóng phiên Stripe trước khi hủy. |
| UC37 | Shipping Status | ✓ L57 | ✓ | F, S | ✓ | Completed ✓ | Chỉ cho Paid→Shipped và Shipped→Delivered ✓. |
| UC38 | Voucher List | ✓ L60 | ✓ | F | ✓ | Completed ✓ | |
| UC39 | Voucher Details | ✓ L61 | ✓ | F | ✓ | Completed ✓ | Chỉ gọi trước khi mở form sửa, không có màn chi tiết riêng (vẫn đạt tiêu chí). |
| UC40 | Add Voucher | ✓ L62 | ✓ | F, S | ✓ | Completed ✓ | |
| UC41 | Edit Voucher | ✓ L63 | ✓ | F, S | ✓ | Completed ✓ | MaxUses ≥ UsedCount ✓. Phần lớn đoạn code đến từ `fb0c1e6` chứ không phải `5ffb31b`. |
| UC42 | Deactivate Voucher | ✓ L64 | ✓ | F, S | ✓ | Completed ✓ | |
| UC43 | Product Reviews | ✓ L36 | ✓ | F | ⚠ | Completed ✓ | Spec ghi "reviewer" nhưng DTO chỉ trả `UserId`, không có tên. |
| UC44 | Review Details | ✓ L67 | ✗ | – | ✓ | In Progress ✓ | Flutter không gọi `GET /reviews/{id}`. Đoạn L303-366 là `_ReviewCard`. |
| UC45 | Add Review | ✓ L68 | ✓ | F, S | ✓ | Completed ✓ | Mỗi user 1 review ✓, phải có đơn Delivered ✓ (trả 403). |
| UC46 | Edit Review | ✓ L69 | ✓ | F, S | ✓ | Completed ✓ | |
| UC47 | Delete Review | ✓ L70 | ✓ | F, S | ✓ | Completed ✓ | Chủ review hoặc admin ✓. |
| UC48 | Mock Payment | ✓ L75 | ✓ | F, S | ✓ | Completed ✓ | Thất bại thì hoàn tồn và voucher ✓. Kết quả lặp lại xử lý theo trạng thái đơn ✓. |
| UC49 | Stripe Session | ✓ L73 | ✓ | F, E | ✓ | In Progress → **có thể Completed** | Kiểm cấu hình, hạn đơn, dùng lại session, đơn 0đ thành Paid ✓. **Commit `c311dae` chỉ có API**, code Flutter từ `e6b9a7e`/`e78f6bc`. |
| UC50 | Stripe Webhook | ✓ L76 | n/a | E (S3, S6) | ✓ | In Progress → **có thể Completed** | Webhook do Stripe gọi nên Flutter không gọi. Kiểm chữ ký + timestamp 300s ✓, chống xử lý trùng event ✓, RefundRequired ✓. Đoạn `payment.dart` L164-188 là nút "kiểm tra lại", không phải webhook. **Commit như UC49.** |

## Ghi chú khác

- Ngày của Member Commit lệch so với iteration. Nếu giảng viên đối chiếu ngày thì sẽ thấy:
  - **Ite 1–2**: commit có ngày *sau* deadline. Ví dụ `60b4e16` ngày 05/10 cho UC01 (hạn 26/09), `5ffb31b` ngày 10/10 cho UC38–42 (hạn 26/09).
  - **Ite 3**: commit nằm trong khoảng 05/10–17/10, khớp.
  - **Ite 4** (19/10–30/10): đa số commit có ngày *trước* ngày bắt đầu. Đó là `60b4e16`, `f4a6e8b`, `dfbe403`, `9cdf3c2`, `e4e7022` và `e6b9a7e`. Chỉ `c311dae` (27/10) nằm trong khoảng.
- Sheet Summary khớp với sheet Backlog: 40/50 Completed, tổng trọng số 90.
- File Excel chưa bị sửa, chưa commit gì.
