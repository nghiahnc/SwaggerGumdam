import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/cart.dart';

import 'test_helpers.dart';

// UC30: chi tiết một mục giỏ đọc lại từ GET /cart/items/{id}.
Map<String, Object?> line({int quantity = 2, int price = 350000}) => {
  'id': 'c1',
  'variantId': 'v1',
  'productName': 'RX-78-2 Gundam',
  'sku': 'HG-RX78-001',
  'unitPriceVnd': price,
  'quantity': quantity,
};

void main() {
  late List<String> requests;
  late Map<String, Object> responses;

  Future<void> pumpCart(WidgetTester tester) =>
      pumpScreen(tester, const CartScreen(), responses, requests: requests);

  setUp(() {
    requests = [];
    responses = {
      'GET /api/v1/cart/items': [line()],
      // Giá vừa đổi và số lượng đã sửa ở máy khác.
      'GET /api/v1/cart/items/c1': line(quantity: 3, price: 400000),
    };
  });

  testWidgets('G1 nút chi tiết gọi GET theo id và hiện giá hiện tại', (
    tester,
  ) async {
    await pumpCart(tester);
    await tester.tap(find.byTooltip('Chi tiết mục giỏ'));
    await tester.pumpAndSettle();

    expect(requests.last, 'GET /api/v1/cart/items/c1');
    expect(find.text('Chi tiết mục giỏ'), findsOneWidget);
    expect(find.text('RX-78-2 Gundam'), findsOneWidget);
    expect(find.text('HG-RX78-001'), findsOneWidget);
    expect(find.text('400.000 ₫'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1.200.000 ₫'), findsOneWidget);
  });

  testWidgets('G2 mục không còn hoặc của người khác: 404 và thử lại', (
    tester,
  ) async {
    responses['GET /api/v1/cart/items/c1'] = problem(
      404,
      'Không tìm thấy mục giỏ hàng.',
    );
    await pumpCart(tester);
    await tester.tap(find.byTooltip('Chi tiết mục giỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy mục giỏ hàng.'), findsOneWidget);

    responses['GET /api/v1/cart/items/c1'] = line();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('700.000 ₫'), findsOneWidget);
  });

  testWidgets('G3 xem chi tiết không sửa giỏ; quay về thì tải lại giỏ', (
    tester,
  ) async {
    await pumpCart(tester);
    await tester.tap(find.byTooltip('Chi tiết mục giỏ'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(requests, [
      'GET /api/v1/cart/items',
      'GET /api/v1/cart/items/c1',
      'GET /api/v1/cart/items',
    ]);
  });

  testWidgets('G4 tên dài trên màn 320 px: thẻ giỏ không tràn với nút mới', (
    tester,
  ) async {
    responses['GET /api/v1/cart/items'] = [
      {...line(), 'productName': 'MG 1/100 ' * 12},
    ];
    await pumpScreen(
      tester,
      const CartScreen(),
      responses,
      size: const Size(320, 900),
    );
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Chi tiết mục giỏ'), findsOneWidget);
    expect(find.byTooltip('Xóa khỏi giỏ'), findsOneWidget);
  });
}
