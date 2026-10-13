import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:five_guys_gundam/core/api_client.dart';
import 'package:five_guys_gundam/core/models.dart';
import 'package:five_guys_gundam/core/session.dart';
import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

/// May answer later (return a Future) to test what the screen does while a
/// request is still running.
typedef Handler = FutureOr<http.Response> Function(http.Request request);

/// A scripted Gundam Shop API for widget tests. Each test registers the
/// answers it needs; every request is recorded so a test can also prove that
/// nothing was sent. Routes match `METHOD /path`, ignoring the query string.
class FakeShopApi {
  FakeShopApi() {
    api = ApiClient(baseUrl: 'http://api.test', client: MockClient(_handle));
  }

  late final ApiClient api;
  late final ShopRepository repository = ShopRepository(api);
  late final SessionController session = SessionController(api);
  final requests = <http.Request>[];
  final _routes = <String, Handler>{};

  /// Answers with [body] encoded as JSON.
  void on(String method, String path, Object? body, {int status = 200}) =>
      onRequest(method, path, (_) => json(body, status: status));

  /// Answers with Problem Details carrying [title], like the real API.
  void refuse(String method, String path, int status, String title) =>
      on(method, path, {'title': title, 'status': status}, status: status);

  void onRequest(String method, String path, Handler handler) =>
      _routes['$method $path'] = handler;

  /// `METHOD /path` of every request, in order.
  List<String> get calls => [
    for (final r in requests) '${r.method} ${r.url.path}',
  ];

  int count(String call) => calls.where((c) => c == call).length;

  Json lastBody(String method, String path) => jsonDecode(
    requests.lastWhere((r) => r.method == method && r.url.path == path).body,
  ) as Json;

  void signIn({String id = 'admin-1', String role = 'Admin'}) {
    api.token = 'test-token';
    session.user = ShopUser.fromJson({
      'id': id,
      'email': '$id@test.local',
      'fullName': 'User $id',
      'role': role,
    });
  }

  Widget wrap(Widget home) => MultiProvider(
    providers: [
      Provider<ShopRepository>.value(value: repository),
      ChangeNotifierProvider<SessionController>.value(value: session),
    ],
    child: MaterialApp(home: home),
  );

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final handler = _routes['${request.method} ${request.url.path}'];
    if (handler == null) {
      return json({
        'title': 'No fake route for ${request.method} ${request.url.path}',
        'status': 404,
      }, status: 404);
    }
    return await handler(request);
  }

  static http.Response json(Object? body, {int status = 200}) =>
      http.Response.bytes(
        body == null ? const <int>[] : utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

Json page(List<Json> items) => {
  'items': items,
  'pageNumber': 1,
  'pageSize': 100,
  'totalCount': items.length,
};

/// Dates in the shape the API returns them when read from SQL Server:
/// UTC, without a zone suffix.
String apiDate(DateTime utc) =>
    utc.toUtc().toIso8601String().replaceAll('Z', '');

Json voucherJson({
  String id = 'v-1',
  String code = 'SALE10',
  int discountVnd = 50000,
  int minSubtotalVnd = 0,
  int maxUses = 10,
  int usedCount = 0,
  DateTime? startsAtUtc,
  DateTime? endsAtUtc,
  bool isActive = true,
}) => {
  'id': id,
  'code': code,
  'discountVnd': discountVnd,
  'minSubtotalVnd': minSubtotalVnd,
  'maxUses': maxUses,
  'usedCount': usedCount,
  'startsAtUtc': apiDate(
    startsAtUtc ?? DateTime.now().toUtc().subtract(const Duration(days: 1)),
  ),
  'endsAtUtc': apiDate(
    endsAtUtc ?? DateTime.now().toUtc().add(const Duration(days: 30)),
  ),
  'isActive': isActive,
};

Json reviewJson({
  String id = 'r-1',
  String productId = 'p-1',
  String userId = 'customer-2',
  int rating = 5,
  String comment = 'Nhựa đẹp, khớp chắc.',
  DateTime? createdAtUtc,
}) => {
  'id': id,
  'productId': productId,
  'userId': userId,
  'rating': rating,
  'comment': comment,
  'createdAtUtc': apiDate(createdAtUtc ?? DateTime.utc(2026, 10, 1, 3)),
};

Json orderJson({
  String id = 'order-0001-aaaa',
  String status = 'PendingPayment',
  int subtotalVnd = 350000,
  int discountVnd = 0,
}) => {
  'id': id,
  'status': status,
  'paymentStatus': status == 'Paid' ? 'Paid' : 'Pending',
  'subtotalVnd': subtotalVnd,
  'discountVnd': discountVnd,
  'totalVnd': subtotalVnd - discountVnd,
  'createdAtUtc': apiDate(DateTime.utc(2026, 10, 10, 3)),
  'expiresAtUtc': apiDate(DateTime.utc(2026, 10, 11, 3)),
  'items': [
    {
      'variantId': 'var-1',
      'productName': 'RX-78-2 Gundam',
      'sku': 'HG-RX78-001',
      'unitPriceVnd': subtotalVnd,
      'quantity': 1,
    },
  ],
};
