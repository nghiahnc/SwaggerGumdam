import 'package:five_guys_gundam/core/api_client.dart';
import 'package:five_guys_gundam/core/session.dart';
import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:five_guys_gundam/screens/admin.dart';
import 'package:five_guys_gundam/screens/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/admin_fake_shop_api.dart';

Future<void> pumpWithRepo(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    Provider<ShopRepository>.value(
      value: FakeShopApi().seed().repository(),
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (entry, title) in [
    ('Danh mục và sản phẩm', 'Catalog quản trị'),
    ('Thêm, sửa và ngừng bán', 'Catalog quản trị'),
    ('Quản lý phiên bản, giá, điều chỉnh tồn', 'SKU và tồn kho'),
    ('Thiết lập mã giảm giá và thời hạn', 'Voucher'),
  ]) {
    testWidgets('H1 "$entry" mở màn hình $title', (tester) async {
      await pumpWithRepo(tester, const AdminHomeScreen());
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
    });
  }

  Future<void> pumpShell(WidgetTester tester, String email) async {
    final fake = FakeShopApi();
    final repo = fake.repository();
    final session = SessionController(repo.api);
    await session.login(email, 'x');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: repo.api),
          Provider<ShopRepository>.value(value: repo),
          ChangeNotifierProvider<SessionController>.value(value: session),
        ],
        child: const MaterialApp(home: ShopShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('H2 Customer không thấy tab Quản trị', (tester) async {
    await pumpShell(tester, 'user@gundam.local');
    expect(find.text('Quản trị'), findsNothing);
  });

  testWidgets('H3 Admin thấy tab Quản trị và mở được', (tester) async {
    await pumpShell(tester, 'admin@gundam.local');
    await tester.tap(find.text('Quản trị'));
    await tester.pumpAndSettle();
    expect(find.text('Quản trị cửa hàng'), findsOneWidget);
  });
}
