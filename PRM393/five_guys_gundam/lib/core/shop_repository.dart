import 'api_client.dart';
import 'models.dart';

class ShopRepository {
  ShopRepository(this.api);
  final ApiClient api;

  Future<List<Category>> categories() async =>
      pageItems(await api.request('GET', '/api/v1/categories?pageSize=100'))
          .map(Category.fromJson)
          .toList();

  Future<List<Product>> products({int page = 1}) async => pageItems(
    await api.request('GET', '/api/v1/products?page=$page&pageSize=20'),
  ).map(Product.fromJson).toList();
  Future<List<Product>> adminProducts() async =>
      pageItems(await api.request('GET', '/api/v1/products?pageSize=100'))
          .map(Product.fromJson)
          .toList();

  Future<List<ProductSearchHit>> searchProducts({
    String query = '',
    String? grade,
    int skip = 0,
  }) async {
    final filters = <String>[];
    if (query.trim().isNotEmpty) {
      final safe = query.trim().toLowerCase().replaceAll("'", "''");
      filters.add("contains(tolower(Name),'$safe')");
    }
    if (grade != null && grade.isNotEmpty) {
      filters.add("Grade eq '${grade.replaceAll("'", "''")}'");
    }
    final parameters = <String, String>{
      r'$orderby': 'Name',
      r'$top': '20',
      r'$skip': '$skip',
      r'$count': 'true',
      if (filters.isNotEmpty) r'$filter': filters.join(' and '),
    };
    final path = '/odata/Products?${Uri(queryParameters: parameters).query}';
    final data = asJson(await api.request('GET', path));
    return asJsonList(data['value']).map(ProductSearchHit.fromJson).toList();
  }

  Future<Product> product(String id) async => Product.fromJson(
    asJson(await api.request('GET', '/api/v1/products/$id')),
  );
  Future<List<Variant>> variants(String id) async => pageItems(
    await api.request('GET', '/api/v1/products/$id/variants?pageSize=100'),
  ).map(Variant.fromJson).toList();
  Future<List<Review>> reviews(String id) async => pageItems(
    await api.request('GET', '/api/v1/products/$id/reviews?pageSize=100'),
  ).map(Review.fromJson).toList();

  Future<List<Address>> addresses() async =>
      asJsonList(await api.request('GET', '/api/v1/addresses'))
          .map(Address.fromJson)
          .toList();
  Future<Address> saveAddress(Json body, {String? id}) async =>
      Address.fromJson(
        asJson(
          await api.request(
            id == null ? 'POST' : 'PUT',
            id == null ? '/api/v1/addresses' : '/api/v1/addresses/$id',
            body: body,
          ),
        ),
      );
  Future<void> deleteAddress(String id) async =>
      api.request('DELETE', '/api/v1/addresses/$id');

  Future<List<CartLine>> cart() async =>
      asJsonList(await api.request('GET', '/api/v1/cart/items'))
          .map(CartLine.fromJson)
          .toList();
  Future<void> addToCart(String variantId, int quantity) async => api.request(
    'POST',
    '/api/v1/cart/items',
    body: {'variantId': variantId, 'quantity': quantity},
  );
  Future<void> updateCart(String id, int quantity) async => api.request(
    'PUT',
    '/api/v1/cart/items/$id',
    body: {'quantity': quantity},
  );
  Future<void> deleteCart(String id) async =>
      api.request('DELETE', '/api/v1/cart/items/$id');

  Future<ShopOrder> checkout(String addressId, String? voucherCode) async =>
      ShopOrder.fromJson(
        asJson(
          await api.request(
            'POST',
            '/api/v1/orders',
            body: {'addressId': addressId, 'voucherCode': voucherCode},
          ),
        ),
      );
  Future<List<ShopOrder>> orders({int page = 1}) async => pageItems(
    await api.request('GET', '/api/v1/orders?page=$page&pageSize=20'),
  ).map(ShopOrder.fromJson).toList();
  Future<ShopOrder> order(String id) async => ShopOrder.fromJson(
    asJson(await api.request('GET', '/api/v1/orders/$id')),
  );
  Future<ShopOrder> cancelOrder(String id) async => ShopOrder.fromJson(
    asJson(await api.request('POST', '/api/v1/orders/$id/cancel')),
  );
  Future<ShopOrder> setOrderStatus(String id, String status) async =>
      ShopOrder.fromJson(
        asJson(
          await api.request(
            'PUT',
            '/api/v1/orders/$id/status',
            body: {'status': status},
          ),
        ),
      );
  Future<Json> paymentSession(String id) async =>
      asJson(await api.request('POST', '/api/v1/payments/orders/$id/session'));
  Future<void> completeMock(String id, bool succeeded) async => api.request(
    'POST',
    '/api/v1/payments/mock/orders/$id/complete',
    body: {'succeeded': succeeded},
  );

  Future<Category> saveCategory(Json body, {String? id}) async =>
      Category.fromJson(
        asJson(
          await api.request(
            id == null ? 'POST' : 'PUT',
            id == null ? '/api/v1/categories' : '/api/v1/categories/$id',
            body: body,
          ),
        ),
      );
  Future<void> deleteCategory(String id) async =>
      api.request('DELETE', '/api/v1/categories/$id');
  Future<Product> saveProduct(Json body, {String? id}) async =>
      Product.fromJson(
        asJson(
          await api.request(
            id == null ? 'POST' : 'PUT',
            id == null ? '/api/v1/products' : '/api/v1/products/$id',
            body: body,
          ),
        ),
      );
  Future<void> deleteProduct(String id) async =>
      api.request('DELETE', '/api/v1/products/$id');
  Future<Variant> saveVariant(Json body, {String? id}) async =>
      Variant.fromJson(
        asJson(
          await api.request(
            id == null ? 'POST' : 'PUT',
            id == null ? '/api/v1/variants' : '/api/v1/variants/$id',
            body: body,
          ),
        ),
      );
  Future<void> deleteVariant(String id) async =>
      api.request('DELETE', '/api/v1/variants/$id');
  Future<Variant> adjustStock(String id, int delta, String reason) async =>
      Variant.fromJson(
        asJson(
          await api.request(
            'POST',
            '/api/v1/variants/$id/stock-adjustments',
            body: {'delta': delta, 'reason': reason},
          ),
        ),
      );

  Future<List<Voucher>> vouchers() async =>
      pageItems(await api.request('GET', '/api/v1/vouchers?pageSize=100'))
          .map(Voucher.fromJson)
          .toList();
  Future<Voucher> saveVoucher(Json body, {String? id}) async =>
      Voucher.fromJson(
        asJson(
          await api.request(
            id == null ? 'POST' : 'PUT',
            id == null ? '/api/v1/vouchers' : '/api/v1/vouchers/$id',
            body: body,
          ),
        ),
      );
  Future<void> deleteVoucher(String id) async =>
      api.request('DELETE', '/api/v1/vouchers/$id');
  Future<Review> saveReview(Json body, {String? id}) async => Review.fromJson(
    asJson(
      await api.request(
        id == null ? 'POST' : 'PUT',
        id == null ? '/api/v1/reviews' : '/api/v1/reviews/$id',
        body: body,
      ),
    ),
  );
  Future<void> deleteReview(String id) async =>
      api.request('DELETE', '/api/v1/reviews/$id');
}
