// Tác giả: Nguyễn Hữu Tài (AgnesLorem) — CE190387, có AI hỗ trợ
// UC: UC21–UC24 (FL-06)
// Mục đích: widget test cho AdminCatalogScreen: sản phẩm

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
Finder get addButton => find.widgetWithText(FilledButton, 'Thêm');

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
  testWidgets('C22 hiển thị sản phẩm và trạng thái', (tester) async {
    await pumpCatalog(tester);
    expect(find.text('Freedom Gundam'), findsOneWidget);
    expect(find.textContaining('Đang bán'), findsOneWidget);
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
    await tester.tap(addButton);
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
        of: find.text('Thêm'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('C13 sửa sản phẩm gọi PUT, giữ danh mục và tải lại danh sách', (
    tester,
  ) async {
    final api = await pumpCatalog(tester);
    await openMenu(tester, 'Freedom Gundam', 'Sửa');
    expect(find.text('Sửa sản phẩm'), findsOneWidget);

    await tester.enterText(field('Tên'), 'Freedom Gundam Rev2');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final body = api.lastBody('PUT', '/api/v1/products/p-freedom');
    expect(body['name'], 'Freedom Gundam Rev2');
    expect(body['categoryId'], 'cat-hg');
    expect(find.text('Sửa sản phẩm'), findsNothing);
    expect(find.text('Freedom Gundam Rev2'), findsOneWidget);
  });

  testWidgets('C14 sửa sản phẩm trùng slug hiện lỗi 409, dữ liệu không đổi', (
    tester,
  ) async {
    final api = await pumpCatalog(tester);
    api.products.add({
      'id': 'p-strike',
      'name': 'Strike Gundam',
      'slug': 'strike',
      'categoryId': 'cat-hg',
      'isActive': true,
    });
    await openMenu(tester, 'Freedom Gundam', 'Sửa');

    await tester.enterText(field('Slug'), 'STRIKE');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(api.called('PUT', '/api/v1/products/p-freedom'), isTrue);
    expect(find.text('Slug sản phẩm đã tồn tại.'), findsOneWidget);
    expect(api.products.first['slug'], 'freedom');
  });

  testWidgets('C16 sản phẩm thuộc danh mục đã ngừng phải chọn lại danh mục', (
    tester,
  ) async {
    final api = FakeShopApi().seed();
    api.categories.first['isActive'] = false;
    api.categories.add({
      'id': 'cat-mg',
      'name': 'Master Grade',
      'slug': 'master-grade',
      'description': null,
      'isActive': true,
    });
    await pumpCatalog(tester, api);
    await openMenu(tester, 'Freedom Gundam', 'Sửa');

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn danh mục'), findsOneWidget);
    expect(api.called('PUT', '/api/v1/products/p-freedom'), isFalse);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Master Grade').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final body = api.lastBody('PUT', '/api/v1/products/p-freedom');
    expect(body['categoryId'], 'cat-mg');
  });
}
