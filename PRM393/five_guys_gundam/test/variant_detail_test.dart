import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/product.dart';

import 'test_helpers.dart';

// UC14: chi tiết SKU đọc lại từ GET /variants/{id}.
Map<String, Object?> variant(
  String id,
  String label,
  int stock, {
  int price = 500000,
}) => {
  'id': id,
  'productId': 'p1',
  'sku': id.toUpperCase(),
  'label': label,
  'priceVnd': price,
  'stock': stock,
  'isActive': true,
};

void main() {
  late List<String> requests;
  late Map<String, Object> responses;

  Future<void> pumpProduct(WidgetTester tester) => pumpScreen(
    tester,
    const ProductScreen(productId: 'p1'),
    responses,
    requests: requests,
  );

  setUp(() {
    requests = [];
    responses = {
      'GET /api/v1/products/p1': {
        'id': 'p1',
        'categoryId': 'c1',
        'name': 'Freedom Gundam',
        'slug': 'freedom',
        'grade': 'MG',
        'scale': '1/100',
        'description': null,
        'imageUrl': null,
        'isActive': true,
      },
      'GET /api/v1/products/p1/variants': {
        'items': [
          variant('v1', 'Bản thường', 2),
          variant('v2', 'Bản giới hạn', 0),
        ],
      },
      // Giá và tồn trên server đã đổi so với danh sách.
      'GET /api/v1/variants/v1': variant('v1', 'Bản thường', 7, price: 520000),
      'GET /api/v1/variants/v2': variant('v2', 'Bản giới hạn', 0),
    };
  });

  testWidgets('V1 nút chi tiết gọi GET theo id và hiện giá, tồn mới nhất', (
    tester,
  ) async {
    await pumpProduct(tester);
    await tester.tap(find.byTooltip('Chi tiết SKU V1'));
    await tester.pumpAndSettle();

    expect(requests.last, 'GET /api/v1/variants/v1');
    expect(find.text('Chi tiết SKU'), findsOneWidget);
    expect(find.text('V1'), findsOneWidget);
    expect(find.text('Bản thường'), findsOneWidget);
    expect(find.text('520.000 ₫'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Đang bán'), findsOneWidget);
  });

  testWidgets('V2 SKU hết hàng không chọn được nhưng vẫn xem chi tiết được', (
    tester,
  ) async {
    await pumpProduct(tester);
    await tester.tap(find.byTooltip('Chi tiết SKU V2'));
    await tester.pumpAndSettle();

    expect(requests.last, 'GET /api/v1/variants/v2');
    expect(find.text('Hết hàng'), findsOneWidget);
  });

  testWidgets('V3 bấm nút chi tiết không đổi SKU đang chọn', (tester) async {
    responses['GET /api/v1/products/p1/variants'] = {
      'items': [variant('v1', 'Bản thường', 2), variant('v3', 'Bản màu', 5)],
    };
    responses['GET /api/v1/variants/v3'] = variant('v3', 'Bản màu', 5);
    await pumpProduct(tester);
    Finder radio(String label) => find.descendant(
      of: find.widgetWithText(ListTile, label),
      matching: find.byIcon(Icons.radio_button_checked),
    );
    expect(radio('Bản thường · 500.000 ₫'), findsOneWidget);

    await tester.tap(find.byTooltip('Chi tiết SKU V3'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(radio('Bản thường · 500.000 ₫'), findsOneWidget);
    expect(radio('Bản màu · 500.000 ₫'), findsNothing);
  });

  testWidgets('V4 SKU ngừng bán (404) hiện lỗi và thử lại được', (
    tester,
  ) async {
    responses['GET /api/v1/variants/v1'] = problem(404, 'Không tìm thấy SKU.');
    await pumpProduct(tester);
    await tester.tap(find.byTooltip('Chi tiết SKU V1'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy SKU.'), findsOneWidget);

    responses['GET /api/v1/variants/v1'] = variant('v1', 'Bản thường', 2);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bản thường'), findsOneWidget);
  });

  testWidgets('V5 quay về từ chi tiết thì tải lại sản phẩm và SKU', (
    tester,
  ) async {
    await pumpProduct(tester);
    await tester.tap(find.byTooltip('Chi tiết SKU V1'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      requests.where((r) => r == 'GET /api/v1/products/p1/variants').length,
      2,
    );
  });
}
