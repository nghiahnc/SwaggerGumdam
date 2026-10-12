import 'dart:convert';

import 'package:five_guys_gundam/core/api_client.dart';
import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

typedef Row = Map<String, dynamic>;

/// Backend giả trong bộ nhớ, mô phỏng đúng các luật của CatalogService
/// (slug/SKU trùng → 409, xóa mềm, tồn kho không âm) để test màn hình admin.
class FakeShopApi {
  final categories = <Row>[];
  final products = <Row>[];
  final variants = <Row>[];

  /// Mỗi request đã gọi: method, path và body (để kiểm tra dữ liệu gửi lên).
  final calls = <(String method, String path, Row body)>[];
  int _seq = 0;

  String _id(String prefix) => '$prefix-${++_seq}';

  FakeShopApi seed() {
    categories.add({
      'id': 'cat-hg',
      'name': 'High Grade',
      'slug': 'high-grade',
      'description': null,
      'isActive': true,
    });
    products.add({
      'id': 'p-freedom',
      'categoryId': 'cat-hg',
      'name': 'Freedom Gundam',
      'slug': 'freedom',
      'grade': 'HG',
      'scale': '1/144',
      'description': null,
      'imageUrl': null,
      'isActive': true,
    });
    variants.add({
      'id': 'v-std',
      'productId': 'p-freedom',
      'sku': 'FREEDOM-STD',
      'label': 'Standard',
      'priceVnd': 450000,
      'stock': 5,
      'isActive': true,
    });
    return this;
  }

  ShopRepository repository() => ShopRepository(
    ApiClient(baseUrl: 'http://fake.test', client: MockClient(_handle)),
  );

  bool called(String method, String path) =>
      calls.any((c) => c.$1 == method && c.$2 == path);
  Row lastBody(String method, String path) =>
      calls.lastWhere((c) => c.$1 == method && c.$2 == path).$3;

  http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  http.Response _problem(String title, int status) =>
      _json({'title': title, 'status': status}, status);
  Row _page(List<Row> items) => {
    'items': items,
    'pageNumber': 1,
    'pageSize': 100,
    'totalCount': items.length,
  };
  Row _insert(List<Row> rows, Row row) {
    rows.add(row);
    return row;
  }

  Row? _find(List<Row> rows, String id) =>
      rows.where((r) => r['id'] == id).firstOrNull;

  Future<http.Response> _handle(http.Request r) async {
    final path = r.url.path;
    final body = r.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(r.body) as Row;
    calls.add((r.method, path, body));
    final s = path.split('/').where((x) => x.isNotEmpty).toList();
    final key =
        '${r.method} ${s.length > 2 ? s[2] : s.join('/')}'
        '${s.length > 3 ? '/{id}' : ''}${s.length > 4 ? '/${s[4]}' : ''}';
    final id = s.length > 3 ? s[3] : '';

    switch (key) {
      // ---------- Danh mục ----------
      case 'GET categories':
        return _json(_page(categories));
      case 'POST categories' || 'PUT categories/{id}':
        final slug = (body['slug'] as String).toLowerCase();
        if (categories.any((c) => c['slug'] == slug && c['id'] != id)) {
          return _problem('Slug danh mục đã tồn tại.', 409);
        }
        final row = r.method == 'POST'
            ? _insert(categories, {'id': _id('cat'), 'isActive': true})
            : _find(categories, id);
        if (row == null) return _problem('Không tìm thấy danh mục.', 404);
        row.addAll({...body, 'slug': slug});
        return _json(row, r.method == 'POST' ? 201 : 200);
      case 'DELETE categories/{id}':
        if (products.any(
          (p) => p['categoryId'] == id && p['isActive'] == true,
        )) {
          return _problem('Còn sản phẩm đang bán trong danh mục.', 409);
        }
        _find(categories, id)?['isActive'] = false;
        return http.Response('', 204);

      // ---------- Sản phẩm ----------
      case 'GET products':
        return _json(_page(products));
      case 'POST products' || 'PUT products/{id}':
        final slug = (body['slug'] as String).toLowerCase();
        if (products.any((p) => p['slug'] == slug && p['id'] != id)) {
          return _problem('Slug sản phẩm đã tồn tại.', 409);
        }
        final row = r.method == 'POST'
            ? _insert(products, {'id': _id('p'), 'isActive': true})
            : _find(products, id);
        if (row == null) return _problem('Không tìm thấy sản phẩm.', 404);
        row.addAll({...body, 'slug': slug});
        return _json(row, r.method == 'POST' ? 201 : 200);
      case 'DELETE products/{id}':
        _find(products, id)?['isActive'] = false;
        for (final v in variants.where((v) => v['productId'] == id)) {
          v['isActive'] = false;
        }
        return http.Response('', 204);
      case 'GET products/{id}/variants':
        return _json(
          _page(variants.where((v) => v['productId'] == id).toList()),
        );

      // ---------- SKU và tồn kho ----------
      case 'POST variants':
        final sku = (body['sku'] as String).toUpperCase();
        if (variants.any((v) => v['sku'] == sku)) {
          return _problem('SKU đã tồn tại.', 409);
        }
        final row = <String, dynamic>{
          'id': _id('v'),
          'productId': body['productId'],
          'sku': sku,
          'label': body['label'],
          'priceVnd': body['priceVnd'],
          'stock': body['initialStock'],
          'isActive': true,
        };
        variants.add(row);
        return _json(row, 201);
      case 'PUT variants/{id}':
        final row = _find(variants, id);
        if (row == null) return _problem('Không tìm thấy SKU.', 404);
        row.addAll(body);
        return _json(row);
      case 'DELETE variants/{id}':
        _find(variants, id)?['isActive'] = false;
        return http.Response('', 204);
      case 'POST variants/{id}/stock-adjustments':
        final row = _find(variants, id);
        if (row == null) return _problem('Không tìm thấy SKU.', 404);
        final next = (row['stock'] as int) + (body['delta'] as int);
        if (next < 0) return _problem('Tồn kho không hợp lệ.', 409);
        row['stock'] = next;
        return _json(row);

      // ---------- Đăng nhập và màn hình khác (để render ShopShell) ----------
      case 'POST auth/{id}': // /api/v1/auth/login
        final admin = (body['email'] as String).startsWith('admin');
        return _json({
          'accessToken': 'fake-token',
          'user': {
            'id': 'u-1',
            'email': body['email'],
            'fullName': 'Tester',
            'role': admin ? 'Admin' : 'Customer',
          },
        });
      case 'GET odata/Products':
        return _json({'value': <Row>[]});
      default:
        return r.method == 'GET'
            ? _json(_page([]))
            : _problem('Fake API chưa hỗ trợ $key', 501);
    }
  }
}
