import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/cart.dart';
import 'package:five_guys_gundam/screens/checkout.dart';

import 'test_helpers.dart';

const address = {
  'id': 'a1',
  'recipient': 'Trần Gia Đạt',
  'phone': '0900000000',
  'line1': '1 Lê Lợi',
  'ward': 'Bến Nghé',
  'district': 'Quận 1',
  'province': 'TP.HCM',
  'isDefault': true,
};

void main() {
  testWidgets('checkout without address disables order button', (tester) async {
    await pumpScreen(tester, const CheckoutScreen(subtotalVnd: 500000), {
      'GET /api/v1/addresses': [],
    });

    expect(
      find.text('Bạn cần thêm địa chỉ trước khi đặt hàng.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tạo đơn hàng'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('invalid voucher code blocks checkout before calling API', (
    tester,
  ) async {
    final requests = <String>[];
    await pumpScreen(tester, const CheckoutScreen(subtotalVnd: 500000), {
      'GET /api/v1/addresses': [address],
    }, requests: requests);

    await tester.enterText(find.byType(TextFormField), 'A' * 65);
    final button = find.widgetWithText(FilledButton, 'Tạo đơn hàng');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Mã voucher tối đa 64 ký tự.'), findsOneWidget);
    expect(find.text('Xác nhận'), findsNothing);
    expect(requests, isNot(contains('POST /api/v1/orders')));
  });

  testWidgets('out-of-stock 409 stays visible above the order button', (
    tester,
  ) async {
    await pumpScreen(tester, const CheckoutScreen(subtotalVnd: 2500000), {
      'GET /api/v1/addresses': [address],
      'POST /api/v1/orders': problem(
        409,
        'SKU MG-UNICORN-001 không đủ tồn kho.',
      ),
    });

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo đơn hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();

    // Hiện ở SnackBar và ở hộp lỗi cố định; vẫn ở màn đặt hàng.
    expect(find.text('SKU MG-UNICORN-001 không đủ tồn kho.'), findsNWidgets(2));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Xác nhận đặt hàng'), findsOneWidget);
  });

  testWidgets('empty cart shows message and hides order button', (
    tester,
  ) async {
    await pumpScreen(tester, const CartScreen(), {
      'GET /api/v1/cart/items': [],
    });

    expect(find.text('Giỏ hàng đang trống.'), findsOneWidget);
    expect(find.text('Đặt hàng'), findsNothing);
  });
}
