/// Labels for order and payment states shown on the payment screen (FL-15).
///
/// The values are the API's (GundamShop.Bll/ShoppingService.cs,
/// PaymentService.cs, GundamShop.Api/PendingOrderExpiryService.cs).
abstract final class PaymentPolicy {
  static const pending = 'PendingPayment';

  static String orderStatus(String status) => switch (status) {
    'PendingPayment' => 'Chờ thanh toán',
    'Paid' => 'Đã thanh toán',
    'PaymentFailed' => 'Thanh toán thất bại',
    'Cancelled' => 'Đã hủy',
    'Expired' => 'Hết hạn thanh toán',
    'Shipped' => 'Đang giao',
    'Delivered' => 'Đã giao',
    _ => status,
  };

  /// What a finished payment attempt means for the customer, read from the
  /// order as the API reports it after the attempt.
  static String outcome(String status) => switch (status) {
    'Paid' || 'Shipped' || 'Delivered' =>
      'Thanh toán thành công. Đơn đã được ghi nhận là đã thanh toán.',
    'PaymentFailed' =>
      'Thanh toán thất bại. Đơn đã đóng; tồn kho và lượt voucher (nếu có) '
          'đã được hoàn lại.',
    'Cancelled' => 'Đơn đã bị hủy nên không thể thanh toán.',
    'Expired' => 'Đơn đã quá hạn thanh toán. Hãy tạo đơn mới.',
    _ => 'Đơn không còn chờ thanh toán (${orderStatus(status)}).',
  };

  static bool succeeded(String status) =>
      status == 'Paid' || status == 'Shipped' || status == 'Delivered';
}
