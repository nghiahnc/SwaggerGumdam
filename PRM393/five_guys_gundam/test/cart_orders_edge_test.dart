import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/models.dart';
import 'package:five_guys_gundam/screens/cart.dart';
import 'package:five_guys_gundam/screens/checkout.dart';
import 'package:five_guys_gundam/screens/orders.dart';

import 'cart_checkout_widget_test.dart' show address;
import 'orders_widget_test.dart' show order;
import 'test_helpers.dart';

// Font của flutter_test vẽ mỗi ký tự rộng bằng cỡ chữ (~1,8 lần Roboto), nên
// 360px ở đây ≈ điện thoại 320px thật với chữ phóng to ~1,6 lần.
const phone = Size(360, 1800);
const longName =
    'MG 1/100 Unicorn Gundam Ver.Ka Full Psycho-Frame Prototype Mobile Suit';

Map<String, Object> cartLine(String id, int quantity, {int price = 350000}) => {
  'id': id,
  'variantId': 'v-$id',
  'productName': longName,
  'sku': 'MG-UNICORN-VERKA-LIMITED-EDITION-001',
  'unitPriceVnd': price,
  'quantity': quantity,
};

void main() {
  group('Ngày giờ đơn hàng', () {
    // API thật trả "2026-10-10T10:24:18.9179242" (không có Z) dù là giờ UTC.
    test('chuỗi không có múi giờ được hiểu là UTC', () {
      final o = ShopOrder.fromJson({
        ...order('o1', 'Paid', 'Paid'),
        'createdAtUtc': '2026-10-10T10:24:18.9179242',
        'expiresAtUtc': '2026-10-11T10:24:18.9179426',
      });
      expect(o.createdAtUtc.isUtc, isTrue);
      expect(
        o.createdAtUtc.difference(DateTime.utc(2026, 10, 10, 10, 24, 18)),
        lessThan(const Duration(seconds: 1)),
      );
      expect(o.expiresAtUtc.isUtc, isTrue);
    });

    test('chuỗi có Z hoặc offset vẫn đúng', () {
      final z = ShopOrder.fromJson(order('o1', 'Paid', 'Paid'));
      expect(z.createdAtUtc, DateTime.utc(2026, 10, 10, 2, 46));
      final offset = ShopOrder.fromJson({
        ...order('o1', 'Paid', 'Paid'),
        'createdAtUtc': '2026-10-10T09:46:00+07:00',
      });
      expect(offset.createdAtUtc.toUtc(), DateTime.utc(2026, 10, 10, 2, 46));
    });

    test('formatDateTime hiển thị đúng giờ địa phương', () {
      final utc = DateTime.utc(2026, 10, 10, 10, 24);
      final local = utc.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(
        formatDateTime(utc),
        '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}',
      );
    });
  });

  group('Giao diện màn hẹp, tên dài, tiền lớn', () {
    testWidgets('giỏ hàng tên dài, tiền lớn không tràn', (tester) async {
      await pumpScreen(tester, const CartScreen(), {
        'GET /api/v1/cart/items': [
          cartLine('c1', 99, price: 99999999),
          cartLine('c2', 1),
        ],
      }, size: phone);
      expect(tester.takeException(), isNull);
      expect(find.text('Tạm tính (100 sản phẩm)'), findsOneWidget);
      expect(find.text('9.900.349.901 ₫'), findsOneWidget);
    });

    testWidgets('xác nhận đặt hàng địa chỉ dài không tràn', (tester) async {
      await pumpScreen(tester, const CheckoutScreen(subtotalVnd: 9900349901), {
        'GET /api/v1/addresses': [
          {
            ...address,
            'recipient': 'Nguyễn Trần Gia Đạt Phương Nam Bắc Trung',
            'line1': 'Số 123/45/67 Đường Nguyễn Văn Linh nối dài, Khu phố 8',
          },
        ],
        'POST /api/v1/orders': problem(
          409,
          'SKU MG-UNICORN-VERKA-LIMITED-EDITION-001 không đủ tồn kho.',
        ),
      }, size: phone);
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo đơn hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('danh sách và chi tiết đơn không tràn', (tester) async {
      final big = {
        ...order('aaaaaaaa-1', 'PaymentFailed', 'RefundRequired'),
        'subtotalVnd': 9900349901,
        'discountVnd': 50000,
        'totalVnd': 9900299901,
        'items': [
          for (var i = 0; i < 3; i++)
            {
              'variantId': 'v$i',
              'productName': longName,
              'sku': 'MG-UNICORN-VERKA-LIMITED-EDITION-00$i',
              'unitPriceVnd': 99999999,
              'quantity': 99,
            },
        ],
      };
      await pumpScreen(tester, const OrdersScreen(), {
        'GET /api/v1/orders': {
          'items': [big],
        },
        'GET /api/v1/orders/aaaaaaaa-1': big,
      }, size: phone);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Đơn #AAAAAAAA'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Cần hoàn tiền'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('-50.000 ₫'), 300);
      expect(tester.takeException(), isNull);
      expect(find.text('9.900.299.901 ₫'), findsWidgets);
    });
  });

  group('Giỏ hàng', () {
    testWidgets('chưa đăng nhập: không gọi API, hiện nút đăng nhập', (
      tester,
    ) async {
      final requests = <String>[];
      await pumpScreen(
        tester,
        const CartScreen(),
        {},
        requests: requests,
        signedIn: false,
      );
      expect(find.text('Đăng nhập để xem giỏ'), findsOneWidget);
      expect(requests, isEmpty);
    });

    testWidgets('tăng số lượng gửi PUT quantity + 1', (tester) async {
      final bodies = <String, Object?>{};
      await pumpScreen(tester, const CartScreen(), {
        'GET /api/v1/cart/items': [cartLine('c1', 2)],
        'PUT /api/v1/cart/items/c1': cartLine('c1', 3),
      }, bodies: bodies);
      await tester.tap(find.byTooltip('Tăng'));
      await tester.pumpAndSettle();
      expect(bodies['PUT /api/v1/cart/items/c1'], {'quantity': 3});
    });

    testWidgets('nút giảm khóa ở 1, nút tăng khóa ở 99', (tester) async {
      await pumpScreen(tester, const CartScreen(), {
        'GET /api/v1/cart/items': [cartLine('c1', 1), cartLine('c2', 99)],
      });
      final minus = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove),
      );
      final plus = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(minus.first.onPressed, isNull);
      expect(minus.last.onPressed, isNotNull);
      expect(plus.first.onPressed, isNotNull);
      expect(plus.last.onPressed, isNull);
    });

    testWidgets('xóa: bấm Không thì không gọi API, Đồng ý thì gọi DELETE', (
      tester,
    ) async {
      final requests = <String>[];
      await pumpScreen(tester, const CartScreen(), {
        'GET /api/v1/cart/items': [cartLine('c1', 1)],
        'DELETE /api/v1/cart/items/c1': <String, Object>{},
      }, requests: requests);

      await tester.tap(find.byTooltip('Xóa khỏi giỏ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không'));
      await tester.pumpAndSettle();
      expect(requests, isNot(contains('DELETE /api/v1/cart/items/c1')));

      await tester.tap(find.byTooltip('Xóa khỏi giỏ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(requests, contains('DELETE /api/v1/cart/items/c1'));
    });

    testWidgets('401 khi sửa giỏ báo phiên hết hạn', (tester) async {
      await pumpScreen(tester, const CartScreen(), {
        'GET /api/v1/cart/items': [cartLine('c1', 2)],
        'PUT /api/v1/cart/items/c1': problem(401, 'Unauthorized'),
      });
      await tester.tap(find.byTooltip('Tăng'));
      await tester.pumpAndSettle();
      expect(
        find.text('Phiên đăng nhập đã hết hạn. Hãy đăng xuất và đăng nhập lại.'),
        findsOneWidget,
      );
    });
  });

  group('Đặt hàng', () {
    testWidgets('chọn sẵn địa chỉ mặc định, gửi voucher đã chuẩn hóa', (
      tester,
    ) async {
      final bodies = <String, Object?>{};
      await pumpScreen(tester, const CheckoutScreen(subtotalVnd: 700000), {
        'GET /api/v1/addresses': [
          {...address, 'id': 'a0', 'isDefault': false},
          address,
        ],
        'POST /api/v1/orders': order('o-new', 'PendingPayment', 'Pending'),
        'GET /api/v1/orders/o-new': order('o-new', 'PendingPayment', 'Pending'),
      }, bodies: bodies);

      await tester.enterText(find.byType(TextFormField), '  giam50k ');
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo đơn hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();

      expect(bodies['POST /api/v1/orders'], {
        'addressId': 'a1',
        'voucherCode': 'GIAM50K',
      });
      expect(find.text('Chi tiết đơn hàng'), findsOneWidget);
    });

    testWidgets('không nhập voucher thì gửi null', (tester) async {
      final bodies = <String, Object?>{};
      await pumpScreen(tester, const CheckoutScreen(subtotalVnd: 700000), {
        'GET /api/v1/addresses': [address],
        'POST /api/v1/orders': order('o-new', 'PendingPayment', 'Pending'),
        'GET /api/v1/orders/o-new': order('o-new', 'PendingPayment', 'Pending'),
      }, bodies: bodies);
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo đơn hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(bodies['POST /api/v1/orders'], {
        'addressId': 'a1',
        'voucherCode': null,
      });
    });

    testWidgets('nhiều địa chỉ (ô voucher chưa được dựng) vẫn đặt hàng được', (
      tester,
    ) async {
      final requests = <String>[];
      await pumpScreen(
        tester,
        const CheckoutScreen(subtotalVnd: 700000),
        {
          'GET /api/v1/addresses': [
            for (var i = 0; i < 12; i++)
              {...address, 'id': 'a$i', 'isDefault': i == 0},
          ],
          'POST /api/v1/orders': order('o-new', 'PendingPayment', 'Pending'),
          'GET /api/v1/orders/o-new': order(
            'o-new',
            'PendingPayment',
            'Pending',
          ),
        },
        requests: requests,
        size: const Size(360, 640),
      );
      expect(find.byType(TextFormField), findsNothing); // Nằm ngoài màn hình.
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo đơn hàng'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(requests, contains('POST /api/v1/orders'));
    });

    testWidgets('bấm Không ở hộp xác nhận thì không tạo đơn', (tester) async {
      final requests = <String>[];
      await pumpScreen(tester, const CheckoutScreen(subtotalVnd: 700000), {
        'GET /api/v1/addresses': [address],
      }, requests: requests);
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo đơn hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không'));
      await tester.pumpAndSettle();
      expect(requests, isNot(contains('POST /api/v1/orders')));
    });
  });

  group('Đơn hàng', () {
    testWidgets('hủy đơn gọi API rồi tải lại', (tester) async {
      final requests = <String>[];
      await pumpScreen(tester, const OrderDetailScreen(orderId: 'p1'), {
        'GET /api/v1/orders/p1': order('p1', 'PendingPayment', 'Pending'),
        'POST /api/v1/orders/p1/cancel': order('p1', 'Cancelled', 'Cancelled'),
      }, requests: requests);
      await tester.tap(find.text('Hủy đơn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(requests, contains('POST /api/v1/orders/p1/cancel'));
      expect(
        requests.where((r) => r == 'GET /api/v1/orders/p1').length,
        2,
      );
    });

    testWidgets('admin xem đơn chờ thanh toán của khách: không có nút Thanh toán', (
      tester,
    ) async {
      await pumpScreen(tester, const OrderDetailScreen(orderId: 'p1'), {
        'GET /api/v1/orders/p1': order(
          'p1',
          'PendingPayment',
          'Pending',
          userId: 'khach-khac',
        ),
      }, role: 'Admin');
      expect(find.widgetWithText(FilledButton, 'Thanh toán'), findsNothing);
      expect(find.text('Hủy đơn'), findsOneWidget);
    });

    testWidgets('admin chuyển Shipped -> Delivered gửi đúng trạng thái', (
      tester,
    ) async {
      final bodies = <String, Object?>{};
      await pumpScreen(tester, const OrderDetailScreen(orderId: 's1'), {
        'GET /api/v1/orders/s1': order('s1', 'Shipped', 'Paid'),
        'PUT /api/v1/orders/s1/status': order('s1', 'Delivered', 'Paid'),
      }, bodies: bodies, role: 'Admin');
      await tester.tap(find.text('Xác nhận đã giao hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(bodies['PUT /api/v1/orders/s1/status'], {'status': 'Delivered'});
    });

    testWidgets('đơn của người khác (404) hiện lỗi và nút Thử lại', (
      tester,
    ) async {
      await pumpScreen(tester, const OrderDetailScreen(orderId: 'x1'), {
        'GET /api/v1/orders/x1': problem(404, 'Không tìm thấy đơn hàng.'),
      });
      expect(find.text('Không tìm thấy đơn hàng.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('đủ 20 đơn thì bật Trang sau và chuyển được trang', (
      tester,
    ) async {
      await pumpScreen(tester, const OrdersScreen(), {
        'GET /api/v1/orders': {
          'items': [
            for (var i = 0; i < 20; i++)
              order('${i}0000000-x', 'Cancelled', 'Cancelled'),
          ],
        },
      });
      final next = find.widgetWithText(TextButton, 'Trang sau');
      await tester.scrollUntilVisible(next, 300);
      expect(tester.widget<TextButton>(next).onPressed, isNotNull);
      await tester.tap(next);
      await tester.pumpAndSettle();
      // Trang mới dựng lại danh sách từ đầu; cuộn xuống thanh phân trang.
      await tester.scrollUntilVisible(find.text('Trang 2'), 300);
      expect(find.text('Trang 2'), findsOneWidget);
      final prev = find.widgetWithText(TextButton, 'Trang trước');
      expect(tester.widget<TextButton>(prev).onPressed, isNotNull);
    });
  });
}
