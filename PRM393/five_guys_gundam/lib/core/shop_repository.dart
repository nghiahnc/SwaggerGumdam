import 'api_client.dart';
import 'models.dart';

/// UC10: sort orders of the catalog. Each ends on unique keys (Name, Id) so
/// that $skip paging over equal prices or names is stable.
///
/// Products without an active SKU have no price (null). SQL Server puts null
/// first when ascending, so "cheapest first" sorts on `FromPriceVnd eq null`
/// first to keep them at the end; descending already puts them last.
enum CatalogSort {
  nameAsc('Tên A → Z', 'Name,Id'),
  nameDesc('Tên Z → A', 'Name desc,Id'),
  priceAsc('Giá thấp → cao', 'FromPriceVnd eq null,FromPriceVnd,Name,Id'),
  priceDesc('Giá cao → thấp', 'FromPriceVnd desc,Name,Id');

  const CatalogSort(this.label, this.orderBy);
  final String label;
  final String orderBy;
}

class ShopRepository {
  ShopRepository(this.api);
  final ApiClient api;

  // Đọc đủ mọi trang: API trả tối đa 100 dòng một trang, lấy một trang thì
  // danh mục, sản phẩm hay SKU thứ 101 trở đi sẽ mất mà không báo gì.
  Future<List<Category>> categories() async =>
      (await _allPages('/api/v1/categories')).map(Category.fromJson).toList();
  Future<Category> category(String id) async => Category.fromJson(
    asJson(await api.request('GET', '/api/v1/categories/$id')),
  );

  Future<List<Product>> adminProducts() async =>
      (await _allPages('/api/v1/products')).map(Product.fromJson).toList();

  static const catalogPageSize = 20;

  Future<ProductSearchPage> searchProducts({
    String query = '',
    String? grade,
    int skip = 0,
    CatalogSort sort = CatalogSort.nameAsc,
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
      r'$orderby': sort.orderBy,
      r'$top': '$catalogPageSize',
      r'$skip': '$skip',
      r'$count': 'true',
      if (filters.isNotEmpty) r'$filter': filters.join(' and '),
    };
    final path = '/odata/Products?${Uri(queryParameters: parameters).query}';
    return ProductSearchPage.fromJson(
      asJson(await api.request('GET', path)),
      skip: skip,
      pageSize: catalogPageSize,
    );
  }

  Future<Product> product(String id) async => Product.fromJson(
    asJson(await api.request('GET', '/api/v1/products/$id')),
  );
  Future<List<Variant>> variants(String id) async =>
      (await _allPages('/api/v1/products/$id/variants'))
          .map(Variant.fromJson)
          .toList();

  /// UC14: reads one SKU again, so its price and stock are current.
  Future<Variant> variant(String id) async => Variant.fromJson(
    asJson(await api.request('GET', '/api/v1/variants/$id')),
  );

  /// Every review of the product: the own review and the average must not
  /// depend on whether it is among the newest 100.
  Future<List<Review>> reviews(String id) async =>
      (await _allPages('/api/v1/products/$id/reviews'))
          .map(Review.fromJson)
          .toList();

  /// Reads the latest review for its detail screen, including changes made
  /// after the product's review list was loaded.
  Future<Review> review(String id) async =>
      Review.fromJson(asJson(await api.request('GET', '/api/v1/reviews/$id')));

  Future<List<Address>> addresses() async =>
      asJsonList(await api.request('GET', '/api/v1/addresses'))
          .map(Address.fromJson)
          .toList();

  /// UC05: the API only finds addresses of the signed-in account (404 otherwise).
  Future<Address> address(String id) async => Address.fromJson(
    asJson(await api.request('GET', '/api/v1/addresses/$id')),
  );
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

  /// The API resolves this ID within the current account's cart.
  Future<CartLine> cartItem(String id) async => CartLine.fromJson(
    asJson(await api.request('GET', '/api/v1/cart/items/$id')),
  );
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

  /// Số đơn mỗi trang; màn Đơn dùng cùng số này để biết còn trang sau không.
  static const ordersPageSize = 20;

  Future<List<ShopOrder>> orders({int page = 1}) async => pageItems(
    await api.request(
      'GET',
      '/api/v1/orders?page=$page&pageSize=$ordersPageSize',
    ),
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

  /// Tải ảnh sản phẩm lên API, trả về URL đầy đủ để lưu vào `imageUrl`.
  Future<String> uploadProductImage(String filename, List<int> bytes) async {
    final path =
        asJson(
              await api.upload(
                '/api/v1/products/images',
                field: 'file',
                filename: filename,
                bytes: bytes,
              ),
            )['url']
            as String;
    // API trả đường dẫn tương đối. Ghép với địa chỉ API mà app đang dùng.
    return '${api.baseUrl}$path';
  }

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

  /// Every voucher, stopped ones included (they stay in the API's list), so
  /// a new code that sorts late still appears.
  Future<List<Voucher>> vouchers() async =>
      (await _allPages('/api/v1/vouchers')).map(Voucher.fromJson).toList();
  Future<Voucher> voucher(String id) async => Voucher.fromJson(
    asJson(await api.request('GET', '/api/v1/vouchers/$id')),
  );
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

  /// Reads a paged list to the end. The API serves at most 100 items a page
  /// and reports the total in `totalCount`; the page cap stops a loop if the
  /// total and the pages ever disagree.
  ///
  /// Pages are offsets, so a row added or removed between two requests
  /// shifts the later pages: items are kept by id (no row twice), and when
  /// the total changed during the read it starts over once.
  Future<List<Json>> _allPages(String path) async {
    const pageSize = 100, maxPages = 100;
    for (var attempt = 1; ; attempt++) {
      final byId = <Object?, Json>{};
      Object? firstTotal;
      var changed = false;
      for (var page = 1; page <= maxPages; page++) {
        final data = asJson(
          await api.request('GET', '$path?page=$page&pageSize=$pageSize'),
        );
        final batch = asJsonList(data['items']);
        final total = data['totalCount'];
        if (page == 1) {
          firstTotal = total;
        } else if (total != firstTotal) {
          changed = true;
        }
        for (final item in batch) {
          byId[item['id']] = item;
        }
        if (batch.length < pageSize || (total is num && byId.length >= total)) {
          break;
        }
      }
      if (!changed || attempt == 2) return byId.values.toList();
    }
  }
}
