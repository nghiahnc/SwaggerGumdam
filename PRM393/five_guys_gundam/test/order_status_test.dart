import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/order_status.dart';

void main() {
  test('order status labels cover every backend value', () {
    expect(orderStatusLabel('PendingPayment'), 'Chờ thanh toán');
    expect(orderStatusLabel('Paid'), 'Đã thanh toán');
    expect(orderStatusLabel('PaymentFailed'), 'Thanh toán thất bại');
    expect(orderStatusLabel('Shipped'), 'Đang giao');
    expect(orderStatusLabel('Delivered'), 'Đã giao');
    expect(orderStatusLabel('Cancelled'), 'Đã hủy');
    expect(orderStatusLabel('Expired'), 'Đã hết hạn');
  });

  test('payment status labels cover every backend value', () {
    expect(paymentStatusLabel('Pending'), 'Chưa thanh toán');
    expect(paymentStatusLabel('Paid'), 'Đã thanh toán');
    expect(paymentStatusLabel('Failed'), 'Thất bại');
    expect(paymentStatusLabel('Cancelled'), 'Đã hủy');
    expect(paymentStatusLabel('Expired'), 'Hết hạn');
    expect(paymentStatusLabel('RefundRequired'), 'Cần hoàn tiền');
  });

  test('unknown status values are shown unchanged', () {
    expect(orderStatusLabel('OnHold'), 'OnHold');
    expect(paymentStatusLabel('Partial'), 'Partial');
  });

  test('every known status has a hint, unknown has none', () {
    for (final status in [
      'PendingPayment',
      'Paid',
      'PaymentFailed',
      'Shipped',
      'Delivered',
      'Cancelled',
      'Expired',
    ]) {
      expect(orderStatusHint(status), isNotNull, reason: status);
    }
    expect(orderStatusHint('OnHold'), isNull);
  });

  test('only PendingPayment orders can be cancelled', () {
    expect(canCancelOrder('PendingPayment'), isTrue);
    for (final status in [
      'Paid',
      'PaymentFailed',
      'Shipped',
      'Delivered',
      'Cancelled',
      'Expired',
    ]) {
      expect(canCancelOrder(status), isFalse, reason: status);
    }
  });

  test('admin can only move Paid → Shipped → Delivered', () {
    expect(nextAdminStatus('Paid'), 'Shipped');
    expect(nextAdminStatus('Shipped'), 'Delivered');
    expect(nextAdminStatus('PendingPayment'), isNull);
    expect(nextAdminStatus('Delivered'), isNull);
    expect(nextAdminStatus('Cancelled'), isNull);
  });
}
