// Giá trị status/paymentStatus lấy từ backend ShoppingService và PaymentService.
// Mọi màn dùng các hằng dưới đây thay vì gõ lại chuỗi, để API đổi tên trạng
// thái thì chỉ sửa một chỗ.

/// `ShopOrder.Status` của API.
abstract final class OrderStatus {
  static const pendingPayment = 'PendingPayment';
  static const paid = 'Paid';
  static const paymentFailed = 'PaymentFailed';
  static const shipped = 'Shipped';
  static const delivered = 'Delivered';
  static const cancelled = 'Cancelled';
  static const expired = 'Expired';

  /// Đã nhận tiền: từ Paid trở đi.
  static bool isPaid(String status) =>
      status == paid || status == shipped || status == delivered;
}

/// `Payment.Status` / `ShopOrder.PaymentStatus` của API.
abstract final class PaymentStatus {
  static const pending = 'Pending';
  static const paid = 'Paid';
  static const failed = 'Failed';
  static const cancelled = 'Cancelled';
  static const expired = 'Expired';
  static const refundRequired = 'RefundRequired';
}

String orderStatusLabel(String status) => switch (status) {
  OrderStatus.pendingPayment => 'Chờ thanh toán',
  OrderStatus.paid => 'Đã thanh toán',
  OrderStatus.paymentFailed => 'Thanh toán thất bại',
  OrderStatus.shipped => 'Đang giao',
  OrderStatus.delivered => 'Đã giao',
  OrderStatus.cancelled => 'Đã hủy',
  OrderStatus.expired => 'Đã hết hạn',
  _ => status,
};

String paymentStatusLabel(String status) => switch (status) {
  PaymentStatus.pending => 'Chưa thanh toán',
  PaymentStatus.paid => 'Đã thanh toán',
  PaymentStatus.failed => 'Thất bại',
  PaymentStatus.cancelled => 'Đã hủy',
  PaymentStatus.expired => 'Hết hạn',
  PaymentStatus.refundRequired => 'Cần hoàn tiền',
  _ => status,
};

// Câu giải thích ngắn cho khách ở màn chi tiết đơn; giá trị lạ không có gợi ý.
String? orderStatusHint(String status) => switch (status) {
  OrderStatus.pendingPayment =>
    'Hãy thanh toán trước hạn. Quá hạn, đơn sẽ tự hủy và hoàn tồn kho.',
  OrderStatus.paid => 'Đơn đã thanh toán, đang chờ cửa hàng gửi hàng.',
  OrderStatus.shipped => 'Đơn đang được giao đến bạn.',
  OrderStatus.delivered =>
    'Đơn đã giao thành công. Bạn có thể đánh giá sản phẩm.',
  OrderStatus.cancelled => 'Đơn đã hủy, tồn kho đã được hoàn lại.',
  OrderStatus.expired => 'Đơn quá hạn thanh toán nên đã tự hủy.',
  OrderStatus.paymentFailed => 'Thanh toán thất bại, tồn kho đã được hoàn lại.',
  _ => null,
};

// Backend chỉ cho hủy đơn chưa thanh toán (ShoppingService.Cancel).
bool canCancelOrder(String status) => status == OrderStatus.pendingPayment;

// Trùng với switch trong ShoppingService.SetStatus: Paid → Shipped → Delivered.
String? nextAdminStatus(String status) => switch (status) {
  OrderStatus.paid => OrderStatus.shipped,
  OrderStatus.shipped => OrderStatus.delivered,
  _ => null,
};
