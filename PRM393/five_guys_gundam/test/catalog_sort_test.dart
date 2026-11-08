import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/api_client.dart';
import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:five_guys_gundam/screens/catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

// UC10: sắp xếp danh mục sản phẩm qua OData $orderby.
Map<String, Object?> hit(int i) => {
  'Id': 'p$i',
  'Name': 'Gundam $i',
  'Grade': 'HG',
  'Scale': '1/144',
  'Category': 'High Grade',
  'FromPriceVnd': 350000,
};

http.Response odata(int count) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      '@odata.count': count,
      'value': [for (var i = 0; i < (count < 20 ? count : 20); i++) hit(i)],
    }),
  ),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late List<Uri> urls;

  Widget catalogApp() => Provider<ShopRepository>.value(
    value: ShopRepository(
      ApiClient(
        baseUrl: 'http://example.test',
        client: MockClient((request) async {
          urls.add(request.url);
          return odata(45);
        }),
      ),
    ),
    child: const MaterialApp(home: CatalogScreen()),
  );

  setUp(() {
    urls = [];
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(800, 3000);
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
  });

  test(
    'S1 mỗi thứ tự gửi đúng \$orderby, kết thúc bằng khóa duy nhất',
    () async {
      for (final (sort, expected) in [
        (CatalogSort.nameAsc, 'Name,Id'),
        (CatalogSort.nameDesc, 'Name desc,Id'),
        (CatalogSort.priceAsc, 'FromPriceVnd eq null,FromPriceVnd,Name,Id'),
        (CatalogSort.priceDesc, 'FromPriceVnd desc,Name,Id'),
      ]) {
        urls = [];
        await ShopRepository(
          ApiClient(
            baseUrl: 'http://example.test',
            client: MockClient((request) async {
              urls.add(request.url);
              return odata(0);
            }),
          ),
        ).searchProducts(sort: sort);
        expect(
          urls.single.queryParameters[r'$orderby'],
          expected,
          reason: '$sort',
        );
      }
    },
  );

  testWidgets('S2 mặc định sắp theo tên A → Z', (tester) async {
    await tester.pumpWidget(catalogApp());
    await tester.pumpAndSettle();
    expect(urls.single.queryParameters[r'$orderby'], 'Name,Id');
    expect(find.text('Tên A → Z'), findsOneWidget);
  });

  testWidgets('S3 đổi thứ tự thì về trang đầu và giữ từ khóa đã tìm', (
    tester,
  ) async {
    await tester.pumpWidget(catalogApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zaku');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(urls.last.queryParameters[r'$skip'], '20');

    await tester.tap(find.byKey(const Key('catalog-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giá cao → thấp').last);
    await tester.pumpAndSettle();

    final q = urls.last.queryParameters;
    expect(q[r'$orderby'], 'FromPriceVnd desc,Name,Id');
    expect(q[r'$skip'], '0');
    expect(q[r'$filter'], "contains(tolower(Name),'zaku')");
  });

  testWidgets('S4 sang trang sau giữ thứ tự đã chọn', (tester) async {
    await tester.pumpWidget(catalogApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giá thấp → cao').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();

    expect(
      urls.last.queryParameters[r'$orderby'],
      'FromPriceVnd eq null,FromPriceVnd,Name,Id',
    );
    expect(urls.last.queryParameters[r'$skip'], '20');
  });

  testWidgets('S5 chọn lại đúng thứ tự đang dùng thì không gửi lại', (
    tester,
  ) async {
    await tester.pumpWidget(catalogApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tên A → Z').last);
    await tester.pumpAndSettle();
    expect(urls, hasLength(1));
  });

  testWidgets('S6 màn 320 px: hàng tìm kiếm và ô sắp xếp không tràn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    await tester.pumpWidget(catalogApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
