# AI Assistance Log · PRM393

Đây là log khởi tạo trung thực. Các thành viên thêm dòng riêng khi **thực sự** kiểm tra, chỉnh sửa, viết test hoặc từ chối gợi ý AI. Không ký nhận thay người khác.

| Ngày | Tác vụ | Công cụ | AI hỗ trợ | Người học đã kiểm tra/thay đổi | Màn hình/commit |
| --- | --- | --- | --- | --- | --- |
| 2026-10-05 | Tạo scaffold Flutter dựa trên API PRN232 và đề PRM393 | Codex | Gợi ý kiến trúc, viết mã màn hình/repository và tài liệu ban đầu | AI đã chạy analyze/test, build APK và thử luồng catalog → giỏ → đơn → mock Paid → Delivered trên Android Emulator; **chưa có xác nhận cá nhân**. Từng thành viên cần review, chạy thử, sửa, bổ sung test và commit thật. | Scaffold ban đầu, commit AI `12649a9`; commit cá nhân chưa có |
| 2026-10-05 | Bổ sung demo Edge | Codex | Thêm nền tảng web, chọn URL API theo nền tảng, sửa lỗi mạng đa nền tảng và tài liệu chạy | AI đã chạy analyze/test, build Web và kiểm tra CORS/API bằng HTTP. Chưa có xác nhận cá nhân. | `web/`, `lib/main.dart`, `lib/core/api_client.dart`, `README.md` |
| 2026-10-10 | FL-04 CatalogScreen, FL-05 ProductScreen (Ngô Quốc Hưng) | Claude Code | Đọc tài liệu/backend, sửa phân trang dùng `@odata.count` (hết lỗi trang rỗng khi đúng 20 kết quả), phân trang giữ từ khóa đã tìm, trạng thái rỗng có “Xóa bộ lọc”/“Về trang đầu”, kéo làm mới chờ dữ liệu; ProductScreen giới hạn số lượng theo tồn, khóa SKU hết hàng, hộp thoại yêu cầu đăng nhập trước khi thêm giỏ, hiện tạm tính; thêm 9 test | AI đã chạy `flutter analyze` (0 issue), `flutter test` (12 pass), build Web và gọi API thật (OData có `@odata.count`, product/variants đúng contract, thêm giỏ khi chưa đăng nhập trả 401). **Chưa có xác nhận cá nhân**: Hưng cần tự đọc diff, chạy thử trên Android Emulator theo kiểm thử tối thiểu FL-04/FL-05 và commit bằng tài khoản của mình. | Branch `feature/hung-fl04-fl05-catalog-product`; `catalog.dart`, `product.dart`, `cart_policy.dart`, `models.dart`, `shop_repository.dart`, test mới |

## Mẫu cho các lần tiếp theo

| Ngày | Tác vụ | Công cụ | AI hỗ trợ | Người học đã kiểm tra/thay đổi | Màn hình/commit |
| --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | Tên lỗi/feature | Tên công cụ | Gợi ý cụ thể | Kết quả test, sửa gì, từ chối gì và lý do | File/commit/PR thật |

Không tạo lại lịch sử quá trình đã không diễn ra. Bài nộp cuối cần repo PRM393 riêng, tác giả/commit đúng người, biên bản họp và checkpoint thực tế.
