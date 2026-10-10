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

// Câu giải thích ngắn cho khách ở màn chi tiết đơn; giá trị lạ không có gợi ý.
String? orderStatusHint(String status) => switch (status) {
  'PendingPayment' =>
    'Hãy thanh toán trước hạn. Quá hạn, đơn sẽ tự hủy và hoàn tồn kho.',
  'Paid' => 'Đơn đã thanh toán, đang chờ cửa hàng gửi hàng.',
  'Shipped' => 'Đơn đang được giao đến bạn.',
  'Delivered' => 'Đơn đã giao thành công. Bạn có thể đánh giá sản phẩm.',
  'Cancelled' => 'Đơn đã hủy, tồn kho đã được hoàn lại.',
  'Expired' => 'Đơn quá hạn thanh toán nên đã tự hủy.',
  'PaymentFailed' => 'Thanh toán thất bại, tồn kho đã được hoàn lại.',
  _ => null,
};

// Backend chỉ cho hủy đơn chưa thanh toán (ShoppingService.Cancel).
bool canCancelOrder(String status) => status == 'PendingPayment';

// Trùng với switch trong ShoppingService.SetStatus: Paid → Shipped → Delivered.
String? nextAdminStatus(String status) => switch (status) {
  'Paid' => 'Shipped',
  'Shipped' => 'Delivered',
  _ => null,
};
