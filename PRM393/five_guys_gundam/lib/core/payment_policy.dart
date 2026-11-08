import 'order_status.dart';

/// Labels for order and payment states shown on the payment screen.
///
/// The values are the API's (GundamShop.Bll/ShoppingService.cs,
/// PaymentService.cs, GundamShop.Api/PendingOrderExpiryService.cs).
abstract final class PaymentPolicy {
  static const pending = 'PendingPayment';

  /// The order screens' labels, so an order reads the same on both.
  static String orderStatus(String status) => orderStatusLabel(status);

  /// Money that reached an order after it closed (cancelled, expired or
  /// failed). The API keeps the closed status and only marks the payment;
  /// the refund is done by hand.
  static const refundRequired = 'RefundRequired';

  static bool needsRefund(String? paymentStatus) =>
      paymentStatus == refundRequired;

  /// The chip on the payment screen. A refund case reads "Cần hoàn tiền"
  /// rather than "Đã hủy" or "Thanh toán thất bại" next to a sentence that
  /// says the money was received.
  static String statusLabel(String status, {String? paymentStatus}) =>
      needsRefund(paymentStatus)
      ? paymentStatusLabel(paymentStatus!)
      : orderStatus(status);

  /// What a finished payment attempt means for the customer, read from the
  /// order as the API reports it after the attempt.
  static String outcome(String status, {String? paymentStatus}) {
    if (needsRefund(paymentStatus)) {
      return 'Cửa hàng đã nhận tiền nhưng đơn đã đóng trước khi tiền về, '
          'nên tiền sẽ được hoàn lại thủ công. Hãy liên hệ cửa hàng; không '
          'thanh toán lại đơn này.';
    }
    return switch (status) {
      'Paid' || 'Shipped' || 'Delivered' =>
        'Thanh toán thành công. Đơn đã được ghi nhận là đã thanh toán.',
      'PaymentFailed' =>
        'Thanh toán thất bại. Đơn đã đóng; tồn kho và lượt voucher (nếu có) '
            'đã được hoàn lại.',
      'Cancelled' => 'Đơn đã bị hủy nên không thể thanh toán.',
      'Expired' => 'Đơn đã quá hạn thanh toán. Hãy tạo đơn mới.',
      _ => 'Đơn không còn chờ thanh toán (${orderStatus(status)}).',
    };
  }

  static bool succeeded(String status, {String? paymentStatus}) =>
      !needsRefund(paymentStatus) &&
      (status == 'Paid' || status == 'Shipped' || status == 'Delivered');
}
