import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/cart.dart';
import 'package:five_guys_gundam/screens/cart_item_detail.dart';

import 'support/fake_shop_api.dart';

Map<String, Object> cartItemJson({
  String productName = 'RX-78-2 Gundam',
  String sku = 'HG-RX78-001',
  int unitPriceVnd = 350000,
  int quantity = 2,
}) => {
  'id': 'cart-1',
  'variantId': 'variant-1',
  'productName': productName,
  'sku': sku,
  'unitPriceVnd': unitPriceVnd,
  'quantity': quantity,
};

/// The repository and client stay real: only the server responses are faked.
/// Detail reads must use the cart-item id and never write to the cart.
void main() {
  const itemPath = '/api/v1/cart/items/cart-1';
  const listPath = '/api/v1/cart/items';
  late FakeShopApi fake;

  setUp(() {
    fake = FakeShopApi()..signIn(id: 'customer-1', role: 'Customer');
  });

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(800, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(fake.wrap(screen));
    await tester.pumpAndSettle();
  }

  void expectField(String key, String text) => expect(
    find.descendant(
      of: find.byKey(Key(key)),
      matching: find.textContaining(text),
      matchRoot: true,
    ),
    findsOneWidget,
  );

  testWidgets(
    'tapping a cart item fetches current details with authentication',
    (tester) async {
      fake.on('GET', listPath, [cartItemJson(productName: 'Tên sản phẩm cũ')]);
      fake.on(
        'GET',
        itemPath,
        cartItemJson(
          productName: 'MG Freedom Gundam Ver.2.0',
          sku: 'MG-FREEDOM-002',
          unitPriceVnd: 475000,
          quantity: 3,
        ),
      );
      await open(tester, const CartScreen());
      await tester.tap(find.byKey(const ValueKey('cart-item-cart-1')));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết món trong giỏ'), findsOneWidget);
      expect(find.byKey(const Key('cart-item-detail')), findsOneWidget);
      expectField('cart-item-name', 'MG Freedom Gundam Ver.2.0');
      expectField('cart-item-sku', 'MG-FREEDOM-002');
      expectField('cart-item-quantity', '3');
      expectField('cart-item-unit-price', '475.000 ₫');
      expectField('cart-item-total', '1.425.000 ₫');
      expect(find.text('Tên sản phẩm cũ'), findsNothing);
      expect(fake.count('GET $itemPath'), 1);
      expect(fake.requests.last.headers['Authorization'], 'Bearer test-token');
      expect(fake.calls.every((call) => call.startsWith('GET ')), isTrue);
      expect(find.byTooltip('Tăng'), findsNothing);
      expect(find.byTooltip('Xóa khỏi giỏ'), findsNothing);
    },
  );

  testWidgets('refresh fetches changed quantity and recalculates the total', (
    tester,
  ) async {
    fake.on('GET', itemPath, cartItemJson());
    await open(tester, const CartItemDetailScreen(cartItemId: 'cart-1'));
    expectField('cart-item-quantity', '2');
    expectField('cart-item-total', '700.000 ₫');

    fake.on('GET', itemPath, cartItemJson(quantity: 4, unitPriceVnd: 400000));
    await tester.tap(find.byTooltip('Tải lại'));
    await tester.pumpAndSettle();

    expectField('cart-item-quantity', '4');
    expectField('cart-item-unit-price', '400.000 ₫');
    expectField('cart-item-total', '1.600.000 ₫');
    expect(fake.count('GET $itemPath'), 2);
    expect(fake.calls.every((call) => call.startsWith('GET ')), isTrue);
  });

  testWidgets(
    'a missing or non-owned item shows the error and supports retry',
    (tester) async {
      fake.refuse('GET', itemPath, 404, 'Không tìm thấy mục giỏ hàng.');
      await open(tester, const CartItemDetailScreen(cartItemId: 'cart-1'));
      expect(find.text('Không tìm thấy mục giỏ hàng.'), findsOneWidget);
      expect(find.byKey(const Key('cart-item-detail')), findsNothing);

      fake.on('GET', itemPath, cartItemJson());
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expectField('cart-item-name', 'RX-78-2 Gundam');
      expect(find.text('Không tìm thấy mục giỏ hàng.'), findsNothing);
      expect(fake.count('GET $itemPath'), 2);
    },
  );

  testWidgets('a guest cannot read a cart item or send its request', (
    tester,
  ) async {
    fake = FakeShopApi();
    await open(tester, const CartItemDetailScreen(cartItemId: 'cart-1'));

    expect(find.text('Đăng nhập để xem món trong giỏ hàng.'), findsOneWidget);
    expect(find.byKey(const Key('cart-item-detail')), findsNothing);
    expect(find.byTooltip('Tải lại'), findsNothing);
    expect(fake.calls, isEmpty);
  });

  testWidgets('an expired session explains how to sign in again', (
    tester,
  ) async {
    fake.on('GET', itemPath, null, status: 401);
    await open(tester, const CartItemDetailScreen(cartItemId: 'cart-1'));

    expect(
      find.text('Phiên đăng nhập đã hết hạn. Hãy đăng xuất rồi đăng nhập lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byKey(const Key('cart-item-detail')), findsNothing);
    expect(fake.count('GET $itemPath'), 1);
  });

  testWidgets('returning from detail reloads an item removed elsewhere', (
    tester,
  ) async {
    fake.on('GET', listPath, [cartItemJson()]);
    fake.on('GET', itemPath, cartItemJson());
    await open(tester, const CartScreen());
    await tester.tap(find.byKey(const ValueKey('cart-item-cart-1')));
    await tester.pumpAndSettle();

    fake.on('GET', listPath, []);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(fake.count('GET $listPath'), 2);
    expect(find.text('Giỏ hàng đang trống.'), findsOneWidget);
    expect(find.byKey(const ValueKey('cart-item-cart-1')), findsNothing);
    expect(find.text('Đặt hàng'), findsNothing);
    expect(fake.calls.every((call) => call.startsWith('GET ')), isTrue);
  });

  testWidgets('nested quantity and delete controls do not open item details', (
    tester,
  ) async {
    var stored = [cartItemJson()];
    fake.onRequest('GET', listPath, (_) => FakeShopApi.json(stored));
    fake.onRequest('PUT', itemPath, (_) {
      stored = [cartItemJson(quantity: 3)];
      return FakeShopApi.json(stored.single);
    });
    fake.onRequest('DELETE', itemPath, (_) {
      stored = [];
      return FakeShopApi.json(null, status: 204);
    });
    await open(tester, const CartScreen());

    await tester.tap(find.byTooltip('Tăng'));
    await tester.pumpAndSettle();
    expect(fake.lastBody('PUT', itemPath), {'quantity': 3});
    expect(find.text('Tạm tính (3 sản phẩm)'), findsOneWidget);
    expect(find.byType(CartItemDetailScreen), findsNothing);
    expect(fake.count('GET $itemPath'), 0);

    await tester.tap(find.byTooltip('Xóa khỏi giỏ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();
    expect(fake.count('DELETE $itemPath'), 1);
    expect(find.text('Giỏ hàng đang trống.'), findsOneWidget);
    expect(find.byType(CartItemDetailScreen), findsNothing);
    expect(fake.count('GET $itemPath'), 0);
  });

  testWidgets('long names and large totals fit a narrow detail screen', (
    tester,
  ) async {
    const longName =
        'MG 1/100 Unicorn Gundam Ver.Ka Full Psycho-Frame Prototype Mobile Suit';
    const longSku = 'MG-UNICORN-VERKA-LIMITED-EDITION-001';
    fake.on(
      'GET',
      itemPath,
      cartItemJson(
        productName: longName,
        sku: longSku,
        unitPriceVnd: 99999999,
        quantity: 99,
      ),
    );
    await open(
      tester,
      const CartItemDetailScreen(cartItemId: 'cart-1'),
      size: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);
    expectField('cart-item-name', longName);
    await tester.scrollUntilVisible(
      find.byKey(const Key('cart-item-total')),
      200,
    );
    expectField('cart-item-total', '9.899.999.901 ₫');
    expect(tester.takeException(), isNull);
  });
}
