import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('attaches JWT and exposes backend Problem Details', () async {
    final api = ApiClient(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer demo-token');
        expect(request.url.path, '/api/v1/orders');
        return http.Response.bytes(
          utf8.encode('{"title":"Voucher không còn hợp lệ.","status":409}'),
          409,
          headers: {'content-type': 'application/problem+json; charset=utf-8'},
        );
      }),
    )..token = 'demo-token';

    await expectLater(
      api.request(
        'POST',
        '/api/v1/orders',
        body: {'addressId': 'example', 'voucherCode': 'EXPIRED'},
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', contains('Voucher')),
      ),
    );
    api.close();
  });
}
