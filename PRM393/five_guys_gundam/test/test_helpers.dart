import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/api_client.dart';
import 'package:five_guys_gundam/core/models.dart';
import 'package:five_guys_gundam/core/session.dart';
import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

// Repository và ApiClient thật, chỉ thay mạng bằng MockClient: không gọi API thật.
// Khóa của [responses] là "METHOD /path" (không gồm query string).
// Mỗi request được ghi lại vào [requests] để kiểm tra app có gửi đi hay không.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen,
  Map<String, Object> responses, {
  List<String>? requests,
  String role = 'Customer',
}) async {
  // Màn hình test cao để ListView dựng đủ mọi phần tử, kể cả nút ở cuối.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = ApiClient(
    baseUrl: 'http://example.test',
    client: MockClient((request) async {
      requests?.add('${request.method} ${request.url.path}');
      final body = responses['${request.method} ${request.url.path}'];
      if (body == null) return http.Response('', 404);
      if (body is http.Response) return body; // Lỗi dựng sẵn, ví dụ 409.
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
      'email': 'test@gundam.local',
      'fullName': 'Người dùng Test',
      'role': role,
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

// Response lỗi dạng Problem Details giống backend (ví dụ 409 hết tồn kho).
http.Response problem(int status, String title) => http.Response.bytes(
  utf8.encode(jsonEncode({'title': title, 'status': status})),
  status,
  headers: {'content-type': 'application/problem+json; charset=utf-8'},
);
