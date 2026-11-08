// Tác giả: Nguyễn Hữu Tài (AgnesLorem) — CE190387, có AI hỗ trợ
// UC: UC25–UC28 (FL-07)
// Mục đích: widget test cho AdminInventoryScreen: SKU và tồn kho

import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:five_guys_gundam/screens/admin_inventory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/admin_fake_shop_api.dart';

Future<FakeShopApi> pumpInventory(
  WidgetTester tester, [
  FakeShopApi? api,
]) async {
  api ??= FakeShopApi().seed();
  await tester.pumpWidget(
    Provider<ShopRepository>.value(
      value: api.repository(),
      child: const MaterialApp(home: AdminInventoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> openMenu(WidgetTester tester, String action) async {
  await tester.tap(find.byType(PopupMenuButton<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

Future<void> submitStock(
  WidgetTester tester,
  String delta,
  String reason,
) async {
  await openMenu(tester, 'Điều chỉnh tồn');
  await tester.enterText(field('Chênh lệch (+ nhập / - xuất)'), delta);
  await tester.enterText(field('Lý do'), reason);
  await tester.tap(find.text('Cập nhật'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('I1 chưa có sản phẩm thì nhắc tạo sản phẩm trước', (
    tester,
  ) async {
    await pumpInventory(tester, FakeShopApi());
    expect(find.text('Thêm sản phẩm trước khi tạo SKU.'), findsOneWidget);
  });

  testWidgets('I2 liệt kê SKU với giá, tồn và trạng thái', (tester) async {
    await pumpInventory(tester);
    expect(find.text('FREEDOM-STD · Standard'), findsOneWidget);
    expect(find.text('450.000 ₫ · Tồn 5 · Đang bán'), findsOneWidget);
  });

  testWidgets('I3 thêm SKU gửi số nguyên và productId', (tester) async {
    final api = await pumpInventory(tester);
    await tester.tap(find.text('Thêm SKU'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Mã SKU'), 'freedom-ltd');
    await tester.enterText(field('Tên phiên bản'), 'Limited');
    await tester.enterText(field('Giá VND'), '520000');
    await tester.enterText(field('Tồn ban đầu'), '3');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final body = api.lastBody('POST', '/api/v1/variants');
    expect(body['productId'], 'p-freedom');
    expect(body['priceVnd'], 520000);
    expect(body['initialStock'], 3);
    expect(find.text('FREEDOM-LTD · Limited'), findsOneWidget);
  });

  testWidgets('I4 chặn giá 0 và tồn ban đầu âm', (tester) async {
    final api = await pumpInventory(tester);
    await tester.tap(find.text('Thêm SKU'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Mã SKU'), 'X');
    await tester.enterText(field('Tên phiên bản'), 'X');
    await tester.enterText(field('Giá VND'), '0');
    await tester.enterText(field('Tồn ban đầu'), '-1');
    await tester.tap(find.text('Lưu'));
    await tester.pump();

    expect(find.text('Nhập số nguyên lớn hơn 0'), findsOneWidget);
    expect(find.text('Nhập số nguyên không âm'), findsOneWidget);
    expect(api.called('POST', '/api/v1/variants'), isFalse);
  });

  testWidgets('I5 SKU trùng hiện lỗi 409', (tester) async {
    await pumpInventory(tester);
    await tester.tap(find.text('Thêm SKU'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Mã SKU'), 'freedom-std');
    await tester.enterText(field('Tên phiên bản'), 'Dup');
    await tester.enterText(field('Giá VND'), '1000');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('SKU đã tồn tại.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
    'I6 sửa SKU: không cho sửa mã, tắt "Đang bán" gửi isActive=false',
    (tester) async {
      final api = await pumpInventory(tester);
      await openMenu(tester, 'Sửa giá / tên');
      expect(field('Mã SKU'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(
        api.lastBody('PUT', '/api/v1/variants/v-std')['isActive'],
        isFalse,
      );
      expect(find.text('450.000 ₫ · Tồn 5 · Ngừng bán'), findsOneWidget);
    },
  );

  testWidgets('I7 nhập kho +3 kèm lý do', (tester) async {
    final api = await pumpInventory(tester);
    await submitStock(tester, '3', 'Nhập hàng đợt 2');

    final body = api.lastBody(
      'POST',
      '/api/v1/variants/v-std/stock-adjustments',
    );
    expect(body, {'delta': 3, 'reason': 'Nhập hàng đợt 2'});
    expect(find.text('Đã cập nhật tồn kho'), findsOneWidget);
    expect(find.text('450.000 ₫ · Tồn 8 · Đang bán'), findsOneWidget);
  });

  testWidgets('I8 chặn chênh lệch 0 và lý do rỗng', (tester) async {
    final api = await pumpInventory(tester);
    await submitStock(tester, '0', '   ');

    expect(find.text('Nhập số nguyên khác 0'), findsOneWidget);
    expect(find.text('Không được để trống'), findsOneWidget);
    expect(
      api.called('POST', '/api/v1/variants/v-std/stock-adjustments'),
      isFalse,
    );
  });

  testWidgets('I9 xuất quá tồn bị API từ chối, tồn giữ nguyên', (tester) async {
    await pumpInventory(tester);
    await submitStock(tester, '-100', 'Kiểm kê');

    expect(find.text('Tồn kho không hợp lệ.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('450.000 ₫ · Tồn 5 · Đang bán'), findsOneWidget);
  });

  testWidgets('I10 ngừng bán SKU gửi DELETE', (tester) async {
    final api = await pumpInventory(tester);
    await openMenu(tester, 'Ngừng bán');
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();

    expect(api.called('DELETE', '/api/v1/variants/v-std'), isTrue);
  });

  testWidgets('I11 sản phẩm đã ngừng bán thì khóa nút Thêm SKU', (
    tester,
  ) async {
    final api = FakeShopApi().seed();
    api.products.first['isActive'] = false;
    await pumpInventory(tester, api);

    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Thêm SKU'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('I12 chặn tồn ban đầu vượt giới hạn của backend', (tester) async {
    final api = await pumpInventory(tester);
    await tester.tap(find.text('Thêm SKU'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Mã SKU'), 'freedom-big');
    await tester.enterText(field('Tên phiên bản'), 'Big');
    await tester.enterText(field('Giá VND'), '1000');
    await tester.enterText(field('Tồn ban đầu'), '3000000000');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Vượt giới hạn $maxStock'), findsOneWidget);
    expect(api.called('POST', '/api/v1/variants'), isFalse);
  });

  testWidgets('I13 ngừng bán SKU tải lại và đổi nhãn, giữ bản ghi', (
    tester,
  ) async {
    await pumpInventory(tester);
    await openMenu(tester, 'Ngừng bán');
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();

    expect(find.text('FREEDOM-STD · Standard'), findsOneWidget);
    expect(find.text('450.000 ₫ · Tồn 5 · Ngừng bán'), findsOneWidget);
  });

  testWidgets('I14 chặn chênh lệch vượt giới hạn của backend', (tester) async {
    final api = await pumpInventory(tester);
    await submitStock(tester, '3000000000', 'Kiểm kê');

    expect(find.text('Vượt giới hạn $maxStock'), findsOneWidget);
    expect(
      api.called('POST', '/api/v1/variants/v-std/stock-adjustments'),
      isFalse,
    );
  });

  testWidgets('I15 không bật lại SKU khi sản phẩm đã ngừng bán', (
    tester,
  ) async {
    final api = FakeShopApi().seed();
    api.products.first['isActive'] = false;
    api.variants.first['isActive'] = false;
    await pumpInventory(tester, api);
    await openMenu(tester, 'Sửa giá / tên');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Sản phẩm đã ngừng bán.'), findsOneWidget);
    expect(api.variants.first['isActive'], isFalse);
  });
}
