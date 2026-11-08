// Tác giả: Nguyễn Hữu Tài (AgnesLorem) — CE190387, có AI hỗ trợ
// UC: UC21–UC24 (FL-06)
// Mục đích: widget test cho AdminCatalogScreen: sản phẩm

import 'dart:async';

import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:five_guys_gundam/screens/admin_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/admin_fake_shop_api.dart';

Future<FakeShopApi> pumpCatalog(
  WidgetTester tester, [
  FakeShopApi? api,
  Future<PickedImage?> Function()? pickImage,
]) async {
  api ??= FakeShopApi().seed();
  await tester.pumpWidget(
    Provider<ShopRepository>.value(
      value: api.repository(),
      child: MaterialApp(
        home: AdminCatalogScreen(pickImage: pickImage ?? () async => null),
      ),
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

/// Nút nằm cuối form, màn test thấp nên phải cuộn tới trước khi bấm.
Future<void> tapChooseImage(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Chọn ảnh từ máy'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chọn ảnh từ máy'));
}

void main() {
  testWidgets('C22 hiển thị sản phẩm và trạng thái', (tester) async {
    await pumpCatalog(tester);
    expect(find.text('Freedom Gundam'), findsOneWidget);
    expect(find.textContaining('Đang bán'), findsOneWidget);
  });

  testWidgets('C23 hộp xác nhận ngừng bán ghi tên sản phẩm', (tester) async {
    await pumpCatalog(tester);
    await openMenu(tester, 'Freedom Gundam', 'Ngừng bán');
    expect(find.text('Ngừng bán sản phẩm Freedom Gundam?'), findsOneWidget);
  });

  testWidgets('C24 sửa sản phẩm cuối danh sách xong vẫn ở đúng chỗ cuộn', (
    tester,
  ) async {
    final api = FakeShopApi().seed();
    for (var i = 1; i <= 30; i++) {
      api.products.add({
        ...api.products.first,
        'id': 'p-$i',
        'name': 'Mẫu $i',
        'slug': 'mau-$i',
      });
    }
    await pumpCatalog(tester, api);
    await tester.scrollUntilVisible(
      find.text('Mẫu 30'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await openMenu(tester, 'Mẫu 30', 'Sửa');
    await tester.enterText(field('Tên'), 'Mẫu 30 sửa');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(api.called('PUT', '/api/v1/products/p-30'), isTrue);
    // Danh sách tải lại nhưng không nhảy về đầu: dòng vừa sửa vẫn trên màn.
    expect(find.text('Mẫu 30 sửa'), findsOneWidget);
    expect(find.text('Freedom Gundam'), findsNothing);
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
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('STRIKE'), findsOneWidget);
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

  testWidgets('C25 chọn ảnh từ máy: tải lên, điền URL, lưu kèm ảnh', (
    tester,
  ) async {
    final api = await pumpCatalog(
      tester,
      null,
      () async => (name: 'freedom.png', bytes: List.filled(64, 7)),
    );
    await openMenu(tester, 'Freedom Gundam', 'Sửa');
    await tapChooseImage(tester);
    await tester.pumpAndSettle();

    expect(api.uploads['freedom.png'], greaterThan(64));
    const url = 'http://fake.test/uploads/products/freedom.png';
    expect(find.widgetWithText(TextFormField, url), findsOneWidget);
    final preview = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('product-image-preview')),
        matching: find.byType(Image),
      ),
    );
    expect((preview.image as NetworkImage).url, url);

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(api.lastBody('PUT', '/api/v1/products/p-freedom')['imageUrl'], url);
  });

  testWidgets('C26 ảnh quá 5 MB bị chặn, không gửi lên API', (tester) async {
    final api = await pumpCatalog(
      tester,
      null,
      () async => (name: 'big.jpg', bytes: List.filled(maxImageBytes + 1, 0)),
    );
    await openMenu(tester, 'Freedom Gundam', 'Sửa');
    await tapChooseImage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ảnh lớn hơn 5 MB.'), findsOneWidget);
    expect(api.called('POST', '/api/v1/products/images'), isFalse);
  });

  testWidgets('C27 API từ chối ảnh thì báo lỗi, giữ URL cũ', (tester) async {
    final api = FakeShopApi().seed();
    api.products.first['imageUrl'] = 'https://example.test/old.jpg';
    await pumpCatalog(
      tester,
      api,
      () async => (name: 'evil.svg', bytes: [1, 2, 3]),
    );
    await openMenu(tester, 'Freedom Gundam', 'Sửa');
    await tapChooseImage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Chỉ nhận ảnh JPG, PNG hoặc WebP.'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'https://example.test/old.jpg'),
      findsOneWidget,
    );
  });

  testWidgets('C28 đang tải ảnh thì khóa nút Lưu', (tester) async {
    final gate = Completer<void>();
    final api = FakeShopApi().seed()..uploadGate = gate.future;
    await pumpCatalog(tester, api, () async => (name: 'a.jpg', bytes: [1]));
    await openMenu(tester, 'Freedom Gundam', 'Sửa');
    await tapChooseImage(tester);
    await tester.pump();

    expect(find.text('Đang tải ảnh...'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lưu'),
    );
    expect(save.onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Chọn ảnh từ máy'), findsOneWidget);
  });
}
