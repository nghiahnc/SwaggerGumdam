import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:five_guys_gundam/screens/admin_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/admin_fake_shop_api.dart';

Future<FakeShopApi> pumpCatalog(WidgetTester tester, [FakeShopApi? api]) async {
  api ??= FakeShopApi().seed();
  await tester.pumpWidget(
    Provider<ShopRepository>.value(
      value: api.repository(),
      child: const MaterialApp(home: AdminCatalogScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Finder field(String label) => find.widgetWithText(TextFormField, label);
Finder addButton(int index) =>
    find.widgetWithText(FilledButton, 'Thêm').at(index);

Future<void> openMenu(
  WidgetTester tester,
  String rowText,
  String action,
) async {
  await tester.tap(
    find.descendant(
      of: find.widgetWithText(Card, rowText),
      matching: find.byType(PopupMenuButton<String>),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('C1 hiển thị danh mục, sản phẩm và trạng thái', (tester) async {
    await pumpCatalog(tester);
    expect(find.text('High Grade'), findsOneWidget);
    expect(find.text('Freedom Gundam'), findsOneWidget);
    expect(find.text('high-grade · Đang bán'), findsOneWidget);
  });

  testWidgets('C2 thêm danh mục gửi POST và tải lại danh sách', (tester) async {
    final api = await pumpCatalog(tester);
    await tester.tap(addButton(0));
    await tester.pumpAndSettle();
    await tester.enterText(field('Tên'), '  Master Grade ');
    await tester.enterText(field('Slug'), 'master-grade');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(api.lastBody('POST', '/api/v1/categories')['name'], 'Master Grade');
    expect(find.text('Master Grade'), findsOneWidget);
  });

  testWidgets('C3 form danh mục rỗng bị chặn, không gọi API', (tester) async {
    final api = await pumpCatalog(tester);
    await tester.tap(addButton(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pump();

    expect(find.text('Không được để trống'), findsNWidgets(2));
    expect(api.called('POST', '/api/v1/categories'), isFalse);
  });

  testWidgets('C4 slug trùng hiện lỗi 409 từ API', (tester) async {
    await pumpCatalog(tester);
    await tester.tap(addButton(0));
    await tester.pumpAndSettle();
    await tester.enterText(field('Tên'), 'Trùng');
    await tester.enterText(field('Slug'), 'HIGH-GRADE');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Slug danh mục đã tồn tại.'), findsOneWidget);
  });

  testWidgets('C5 sửa danh mục điền sẵn dữ liệu cũ và gửi PUT', (tester) async {
    final api = await pumpCatalog(tester);
    await openMenu(tester, 'High Grade', 'Sửa');
    expect(find.text('Sửa danh mục'), findsOneWidget);
    expect(find.text('high-grade'), findsWidgets);

    await tester.enterText(field('Tên'), 'HG Universal');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(api.called('PUT', '/api/v1/categories/cat-hg'), isTrue);
    expect(find.text('HG Universal'), findsOneWidget);
  });

  testWidgets('C6 không ngừng được danh mục còn sản phẩm đang bán', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await openMenu(tester, 'High Grade', 'Ngừng bán');
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();

    expect(find.text('Còn sản phẩm đang bán trong danh mục.'), findsOneWidget);
  });

  testWidgets('C7 bấm "Không" ở hộp xác nhận thì không xóa', (tester) async {
    final api = await pumpCatalog(tester);
    await openMenu(tester, 'Freedom Gundam', 'Ngừng bán');
    await tester.tap(find.text('Không'));
    await tester.pumpAndSettle();

    expect(api.called('DELETE', '/api/v1/products/p-freedom'), isFalse);
  });

  testWidgets('C8 thêm sản phẩm gửi kèm categoryId mặc định', (tester) async {
    final api = await pumpCatalog(tester);
    await tester.tap(addButton(1));
    await tester.pumpAndSettle();
    await tester.enterText(field('Tên'), 'Strike Gundam');
    await tester.enterText(field('Slug'), 'strike');
    await tester.enterText(field('Grade (HG/MG/...)'), 'HG');
    await tester.enterText(field('Tỉ lệ (1/144/...)'), '1/144');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final body = api.lastBody('POST', '/api/v1/products');
    expect(body['categoryId'], 'cat-hg');
    expect(body['grade'], 'HG');
    expect(find.text('Strike Gundam'), findsOneWidget);
  });

  testWidgets('C9 ngừng bán sản phẩm gửi DELETE và đổi nhãn', (tester) async {
    final api = await pumpCatalog(tester);
    await openMenu(tester, 'Freedom Gundam', 'Ngừng bán');
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();

    expect(api.called('DELETE', '/api/v1/products/p-freedom'), isTrue);
    expect(find.text('HG · 1/144 · Ngừng bán'), findsOneWidget);
  });

  testWidgets('C10 nút thêm sản phẩm bị khóa khi không có danh mục đang bán', (
    tester,
  ) async {
    final api = FakeShopApi()
      ..categories.add({
        'id': 'cat-off',
        'name': 'Cũ',
        'slug': 'cu',
        'description': null,
        'isActive': false,
      });
    await pumpCatalog(tester, api);

    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Thêm').at(1),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
