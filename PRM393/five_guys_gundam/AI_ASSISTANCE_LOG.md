# AI Assistance Log · PRM393

Đây là log khởi tạo trung thực. Các thành viên thêm dòng riêng khi **thực sự** kiểm tra, chỉnh sửa, viết test hoặc từ chối gợi ý AI. Không ký nhận thay người khác.

| Ngày | Tác vụ | Công cụ | AI hỗ trợ | Người học đã kiểm tra/thay đổi | Màn hình/commit |
| --- | --- | --- | --- | --- | --- |
| 2026-10-05 | Tạo scaffold Flutter dựa trên API PRN232 và đề PRM393 | Codex | Gợi ý kiến trúc, viết mã màn hình/repository và tài liệu ban đầu | AI đã chạy analyze/test, build APK và thử luồng catalog → giỏ → đơn → mock Paid → Delivered trên Android Emulator; **chưa có xác nhận cá nhân**. Từng thành viên cần review, chạy thử, sửa, bổ sung test và commit thật. | Scaffold ban đầu, commit AI `12649a9`; commit cá nhân chưa có |
| 2026-10-05 | Bổ sung demo Edge | Codex | Thêm nền tảng web, chọn URL API theo nền tảng, sửa lỗi mạng đa nền tảng và tài liệu chạy | AI đã chạy analyze/test, build Web và kiểm tra CORS/API bằng HTTP. Chưa có xác nhận cá nhân. | `web/`, `lib/main.dart`, `lib/core/api_client.dart`, `README.md` |
| 2026-10-10 | FL-13..15: VouchersScreen, ReviewsScreen, PaymentScreen | Claude Code | Viết lại 3 màn hình theo bảng phân công, tách quy tắc ra `voucher_policy.dart`/`review_policy.dart`/`payment_policy.dart`, sửa lỗi đọc ngày UTC thiếu `Z` (`dates.dart`), viết 52 test (unit + widget với API giả); rà soát bằng 2 agent và sửa các lỗi tìm được | AI đã chạy `flutter analyze` (0 lỗi), `flutter test` (55/55), phép thử ngược 12/12 và đối chiếu câu báo lỗi với API thật. **Chưa có xác nhận cá nhân.** Sinh viên cần tự đọc, chạy lại, thử trên máy thật và ghi lại phần đã kiểm tra/sửa. | `lib/screens/vouchers.dart`, `reviews.dart`, `payment.dart`; `lib/core/voucher_policy.dart`, `review_policy.dart`, `payment_policy.dart`, `dates.dart`, `error_text.dart`; file dùng chung `lib/core/models.dart` (Voucher/Review dùng `parseUtc`); `test/*` gồm `test/support/fake_shop_api.dart`; `CODE_MAP.md`, `README.md`, `VOUCHER_REVIEW_PAYMENT.md`; nhánh `feature/hieu-nghia-vouchers-reviews-payment` |

## Mẫu cho các lần tiếp theo

| Ngày | Tác vụ | Công cụ | AI hỗ trợ | Người học đã kiểm tra/thay đổi | Màn hình/commit |
| --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | Tên lỗi/feature | Tên công cụ | Gợi ý cụ thể | Kết quả test, sửa gì, từ chối gì và lý do | File/commit/PR thật |

Không tạo lại lịch sử quá trình đã không diễn ra. Bài nộp cuối cần repo PRM393 riêng, tác giả/commit đúng người, biên bản họp và checkpoint thực tế.
