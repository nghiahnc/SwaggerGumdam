import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/api_client.dart';
import 'package:five_guys_gundam/core/models.dart';
import 'package:five_guys_gundam/core/session.dart';
import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:five_guys_gundam/screens/cart.dart';
import 'package:five_guys_gundam/screens/checkout.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

// Repository và ApiClient thật, chỉ thay mạng bằng MockClient: không gọi API thật.
// Mỗi request được ghi lại vào [requests] để kiểm tra app có gửi đi hay không.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen,
  Map<String, Object> responses, {
  List<String>? requests,
}) async {
  final api = ApiClient(
    baseUrl: 'http://example.test',
    client: MockClient((request) async {
      requests?.add('${request.method} ${request.url.path}');
      final body = responses['${request.method} ${request.url.path}'];
      if (body == null) return http.Response('', 404);
      return http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  final session = SessionController(api)
    ..user = ShopUser.fromJson({
      'id': 'u1',
      'email': 'khach@gundam.local',
      'fullName': 'Khách Test',
      'role': 'Customer',
    });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ShopRepository>.value(value: ShopRepository(api)),
        ChangeNotifierProvider<SessionController>.value(value: session),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

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
