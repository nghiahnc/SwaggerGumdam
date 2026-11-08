import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/api_client.dart';
import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Danh sách admin đọc đủ mọi trang: API trả tối đa 100 dòng một trang.
Map<String, Object?> category(int i) => {
  'id': 'c$i',
  'name': 'Danh mục $i',
  'slug': 'dm-$i',
  'description': null,
  'isActive': true,
};

Map<String, Object?> product(int i) => {
  'id': 'p$i',
  'categoryId': 'c1',
  'name': 'Sản phẩm $i',
  'slug': 'sp-$i',
  'grade': 'HG',
  'scale': '1/144',
  'description': null,
  'imageUrl': null,
  'isActive': true,
};

Map<String, Object?> variant(int i) => {
  'id': 'v$i',
  'productId': 'p1',
  'sku': 'SKU$i',
  'label': 'Bản $i',
  'priceVnd': 1000,
  'stock': 1,
  'isActive': true,
};

/// Serves [total] rows built by [row], 100 a page, like PageHelper in the API.
(ShopRepository, List<Uri>) repoWith(
  int total,
  Map<String, Object?> Function(int) row,
) {
  final urls = <Uri>[];
  final repo = ShopRepository(
    ApiClient(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        urls.add(request.url);
        final page = int.parse(request.url.queryParameters['page'] ?? '1');
        final size = int.parse(request.url.queryParameters['pageSize'] ?? '20');
        final items = [
          for (var i = (page - 1) * size; i < total && i < page * size; i++)
            row(i),
        ];
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'items': items,
              'pageNumber': page,
              'pageSize': size,
              'totalCount': total,
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    ),
  );
  return (repo, urls);
}

void main() {
  test('P1 danh mục thứ 101 trở đi không bị mất', () async {
    final (repo, urls) = repoWith(250, category);
    final items = await repo.categories();
    expect(items, hasLength(250));
    expect(items.last.id, 'c249');
    expect(urls.map((u) => u.queryParameters['page']), ['1', '2', '3']);
    expect(urls.every((u) => u.path == '/api/v1/categories'), isTrue);
  });

  test('P2 sản phẩm của admin đọc đủ mọi trang', () async {
    final (repo, _) = repoWith(101, product);
    expect(await repo.adminProducts(), hasLength(101));
  });

  test('P3 SKU của một sản phẩm đọc đủ mọi trang', () async {
    final (repo, urls) = repoWith(130, variant);
    expect(await repo.variants('p1'), hasLength(130));
    expect(urls.first.path, '/api/v1/products/p1/variants');
  });

  test('P4 dưới 100 dòng thì chỉ gọi một lần', () async {
    final (repo, urls) = repoWith(3, category);
    expect(await repo.categories(), hasLength(3));
    expect(urls, hasLength(1));
  });

  test('P5 đơn hàng xin đúng số dòng màn Đơn dùng để phân trang', () async {
    final (repo, urls) = repoWith(0, category);
    await repo.orders(page: 2);
    expect(urls.single.queryParameters['page'], '2');
    expect(
      urls.single.queryParameters['pageSize'],
      '${ShopRepository.ordersPageSize}',
    );
  });
}
