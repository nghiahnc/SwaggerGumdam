import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/orders.dart';

import 'test_helpers.dart';

// Đơn giả theo đúng OrderDTO của backend.
Map<String, Object> order(String id, String status, String paymentStatus) => {
  'id': id,
  'status': status,
  'paymentStatus': paymentStatus,
  'subtotalVnd': 700000,
  'discountVnd': 0,
  'totalVnd': 700000,
  'createdAtUtc': '2026-10-10T02:46:00Z',
  'expiresAtUtc': '2026-10-11T02:46:00Z',
  'items': [
    {
      'variantId': 'v1',
      'productName': 'RX-78-2 Gundam',
      'sku': 'HG-RX78-001',
      'unitPriceVnd': 350000,
      'quantity': 2,
    },
  ],
};

void main() {
  testWidgets('customer sees pay and cancel for a pending order', (
    tester,
  ) async {
    await pumpScreen(tester, const OrderDetailScreen(orderId: 'pending-1'), {
      'GET /api/v1/orders/pending-1': order(
        'pending-1',
        'PendingPayment',
        'Pending',
      ),
    });

    expect(find.text('Chờ thanh toán'), findsOneWidget);
    expect(find.text('Thanh toán'), findsWidgets);
    expect(find.text('Hủy đơn'), findsOneWidget);
    expect(find.text('Xác nhận đã gửi hàng'), findsNothing);
  });

  final paid = {'GET /api/v1/orders/paid-1': order('paid-1', 'Paid', 'Paid')};

  testWidgets('customer cannot cancel or ship a paid order', (tester) async {
    await pumpScreen(tester, const OrderDetailScreen(orderId: 'paid-1'), paid);

    expect(find.text('Đã thanh toán'), findsWidgets);
    expect(find.text('Hủy đơn'), findsNothing);
    expect(find.text('Xác nhận đã gửi hàng'), findsNothing);
  });

  testWidgets('admin can mark a paid order as shipped', (tester) async {
    await pumpScreen(
      tester,
      const OrderDetailScreen(orderId: 'paid-1'),
      paid,
      role: 'Admin',
    );

    expect(find.text('Hủy đơn'), findsNothing);
    expect(find.text('Xác nhận đã gửi hàng'), findsOneWidget);
  });

  testWidgets('admin filter shows only orders that need action', (
    tester,
  ) async {
    await pumpScreen(tester, const OrdersScreen(), {
      'GET /api/v1/orders': {
        'items': [
          order('aaaaaaaa-1', 'Paid', 'Paid'),
          order('bbbbbbbb-2', 'Delivered', 'Paid'),
        ],
      },
    }, role: 'Admin');

    expect(find.text('Đơn #AAAAAAAA'), findsOneWidget);
    expect(find.text('Đơn #BBBBBBBB'), findsOneWidget);
    expect(find.textContaining('2 sản phẩm'), findsNWidgets(2));

    await tester.tap(find.text('Cần xử lý'));
    await tester.pumpAndSettle();

    expect(find.text('Đơn #AAAAAAAA'), findsOneWidget);
    expect(find.text('Đơn #BBBBBBBB'), findsNothing);
  });
}
