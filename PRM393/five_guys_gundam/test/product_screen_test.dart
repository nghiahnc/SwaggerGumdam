import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/api_client.dart';
import 'package:five_guys_gundam/core/session.dart';
import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:five_guys_gundam/screens/product.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> variant(String id, String label, int stock) => {
  'id': id,
  'productId': 'p1',
  'sku': id.toUpperCase(),
  'label': label,
  'priceVnd': 500000,
  'stock': stock,
  'isActive': true,
};

Finder iconButton(String tooltip) => find.ancestor(
  of: find.byTooltip(tooltip),
  matching: find.byType(IconButton),
);

void main() {
  late List<http.Request> requests;
  late ApiClient api;

  Widget productApp() => MultiProvider(
    providers: [
      Provider<ShopRepository>.value(value: ShopRepository(api)),
      ChangeNotifierProvider(create: (_) => SessionController(api)),
    ],
    child: const MaterialApp(home: ProductScreen(productId: 'p1')),
  );

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(800, 1400);
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
    requests = [];
    api = ApiClient(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        requests.add(request);
        return switch (request.url.path) {
          '/api/v1/products/p1' => json({
            'id': 'p1',
            'categoryId': 'c1',
            'name': 'Freedom Gundam',
            'slug': 'freedom',
            'grade': 'MG',
            'scale': '1/100',
            'description': null,
            'imageUrl': null,
            'isActive': true,
          }),
          '/api/v1/products/p1/variants' => json({
            'items': [
              variant('v1', 'Bản thường', 2),
              variant('v2', 'Bản giới hạn', 0),
            ],
          }),
          '/api/v1/auth/login' => json({
            'accessToken': 'token',
            'user': {
              'id': 'u1',
              'email': 'khach@example.test',
              'fullName': 'Khách',
              'role': 'Customer',
            },
          }),
          '/api/v1/cart/items' => json({}, 201),
          _ => json({'title': 'Not found'}, 404),
        };
      }),
    );
  });

  testWidgets('quantity stops at stock and sold-out SKU is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(productApp());
    await tester.pumpAndSettle();

    expect(find.text('SKU V2 · Hết hàng'), findsOneWidget);
    final soldOut = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Bản giới hạn · 500.000 ₫'),
    );
    expect(soldOut.enabled, isFalse);

    final plus = iconButton('Tăng số lượng');
    final minus = iconButton('Giảm số lượng');
    expect(tester.widget<IconButton>(minus).onPressed, isNull);
    await tester.tap(plus);
    await tester.pump();
    expect(find.byKey(const Key('quantity')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('quantity'))).data, '2');
    expect(tester.widget<IconButton>(plus).onPressed, isNull);
    expect(find.text('Tạm tính 1.000.000 ₫ · tối đa 2'), findsOneWidget);
  });

  testWidgets('guest must sign in before adding to cart', (tester) async {
    await tester.pumpWidget(productApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm vào giỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Cần đăng nhập'), findsOneWidget);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.url.path == '/api/v1/cart/items'), isEmpty);
  });

  testWidgets('signed-in customer adds selected SKU and quantity', (
    tester,
  ) async {
    await tester.pumpWidget(productApp());
    await tester.pumpAndSettle();
    await tester
        .element(find.byType(ProductScreen))
        .read<SessionController>()
        .login('khach@example.test', 'secret');
    await tester.tap(find.byTooltip('Tăng số lượng'));
    await tester.tap(find.text('Thêm vào giỏ'));
    await tester.pumpAndSettle();

    final add = requests.lastWhere((r) => r.url.path == '/api/v1/cart/items');
    expect(add.headers['Authorization'], 'Bearer token');
    expect(jsonDecode(add.body), {'variantId': 'v1', 'quantity': 2});
    expect(find.text('Đã thêm 2 × Bản thường vào giỏ'), findsOneWidget);
  });
}
