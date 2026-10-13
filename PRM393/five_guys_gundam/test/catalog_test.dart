import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/api_client.dart';
import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:five_guys_gundam/screens/catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Map<String, Object?> hit(int i) => {
  'Id': 'p$i',
  'Name': 'Gundam $i',
  'Grade': 'HG',
  'Scale': '1/144',
  'Category': 'High Grade',
  'FromPriceVnd': 350000,
};

http.Response odata(List<Map<String, Object?>> items, int count) =>
    http.Response.bytes(
      utf8.encode(jsonEncode({'@odata.count': count, 'value': items})),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Widget catalogApp(MockClient client) => Provider<ShopRepository>.value(
  value: ShopRepository(
    ApiClient(baseUrl: 'http://example.test', client: client),
  ),
  child: const MaterialApp(home: CatalogScreen()),
);

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(800, 3000);
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
  });

  test('search builds OData filter, paging and reads total count', () async {
    late Uri url;
    final repo = ShopRepository(
      ApiClient(
        baseUrl: 'http://example.test',
        client: MockClient((request) async {
          url = request.url;
          return odata([for (var i = 0; i < 20; i++) hit(i)], 45);
        }),
      ),
    );

    final page = await repo.searchProducts(
      query: " Char's Zaku ",
      grade: 'MG',
      skip: 20,
    );

    expect(url.path, '/odata/Products');
    expect(
      url.queryParameters[r'$filter'],
      "contains(tolower(Name),'char''s zaku') and Grade eq 'MG'",
    );
    expect(url.queryParameters[r'$skip'], '20');
    expect(url.queryParameters[r'$top'], '20');
    expect(url.queryParameters[r'$count'], 'true');
    expect(page.pageNumber, 2);
    expect(page.pageCount, 3);
    expect(page.hasPrevious, isTrue);
    expect(page.hasNext, isTrue);
  });

  testWidgets('exactly one full page does not offer an empty next page', (
    tester,
  ) async {
    await tester.pumpWidget(
      catalogApp(
        MockClient(
          (_) async => odata([for (var i = 0; i < 20; i++) hit(i)], 20),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tìm thấy 20 sản phẩm'), findsOneWidget);
    final next = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Trang sau'),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('next page sends skip and keeps the submitted query', (
    tester,
  ) async {
    final requests = <Uri>[];
    await tester.pumpWidget(
      catalogApp(
        MockClient((request) async {
          requests.add(request.url);
          final skip = int.parse(request.url.queryParameters[r'$skip']!);
          return odata([
            for (var i = skip; i < skip + 20 && i < 25; i++) hit(i),
          ], 25);
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'gundam');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    // Gõ thêm nhưng chưa tìm: phân trang vẫn dùng từ khóa đã gửi.
    await tester.enterText(find.byType(TextField), 'chưa gửi');
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();

    expect(requests.last.queryParameters[r'$skip'], '20');
    expect(requests.last.queryParameters[r'$filter'], contains("'gundam'"));
    expect(find.text('Gundam 24'), findsOneWidget);
  });

  testWidgets('no result offers to clear filters', (tester) async {
    final requests = <Uri>[];
    await tester.pumpWidget(
      catalogApp(
        MockClient((request) async {
          requests.add(request.url);
          final filtered = request.url.queryParameters.containsKey(r'$filter');
          return filtered ? odata([], 0) : odata([hit(1)], 1);
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'không có');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(
      find.text('Không tìm thấy sản phẩm cho “không có”.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Xóa bộ lọc'));
    await tester.pumpAndSettle();

    expect(requests.last.queryParameters.containsKey(r'$filter'), isFalse);
    expect(find.text('Gundam 1'), findsOneWidget);
  });

  testWidgets('network failure shows retry and recovers', (tester) async {
    var online = false;
    await tester.pumpWidget(
      catalogApp(
        MockClient((_) async {
          if (!online) throw http.ClientException('offline');
          return odata([hit(1)], 1);
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu mạng thất bại. Hãy thử lại.'), findsOneWidget);

    online = true;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Gundam 1'), findsOneWidget);
  });
}
