// Giá trị status/paymentStatus lấy từ backend ShoppingService và PaymentService.
String orderStatusLabel(String status) => switch (status) {
  'PendingPayment' => 'Chờ thanh toán',
  'Paid' => 'Đã thanh toán',
  'PaymentFailed' => 'Thanh toán thất bại',
  'Shipped' => 'Đang giao',
  'Delivered' => 'Đã giao',
  'Cancelled' => 'Đã hủy',
  'Expired' => 'Đã hết hạn',
  _ => status,
};

String paymentStatusLabel(String status) => switch (status) {
  'Pending' => 'Chưa thanh toán',
  'Paid' => 'Đã thanh toán',
  'Failed' => 'Thất bại',
  'Cancelled' => 'Đã hủy',
  'Expired' => 'Hết hạn',
  'RefundRequired' => 'Cần hoàn tiền',
  _ => status,
};

// Backend chỉ cho hủy đơn chưa thanh toán (ShoppingService.Cancel).
bool canCancelOrder(String status) => status == 'PendingPayment';

// Trùng với switch trong ShoppingService.SetStatus: Paid → Shipped → Delivered.
String? nextAdminStatus(String status) => switch (status) {
  'Paid' => 'Shipped',
  'Shipped' => 'Delivered',
  _ => null,
};
