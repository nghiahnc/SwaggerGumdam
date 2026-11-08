// Tác giả: Nguyễn Hữu Tài (AgnesLorem) — CE190387, có AI hỗ trợ
// UC: UC16–UC20 (FL-06)
// Mục đích: widget test cho AdminCategoriesScreen và CategoryDetailScreen

import 'package:five_guys_gundam/core/shop_repository.dart';
import 'package:five_guys_gundam/screens/admin_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/admin_fake_shop_api.dart';

Future<FakeShopApi> pumpCategories(
  WidgetTester tester, [
  FakeShopApi? api,
]) async {
  api ??= FakeShopApi().seed();
  await tester.pumpWidget(
    Provider<ShopRepository>.value(
      value: api.repository(),
      child: const MaterialApp(home: AdminCategoriesScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> openAddForm(WidgetTester tester) =>
    tapAndSettle(tester, find.text('Thêm danh mục'));

Future<void> openHighGrade(WidgetTester tester) =>
    tapAndSettle(tester, find.text('High Grade'));

void main() {
  group('UC16 danh sách', () {
    testWidgets('C1 hiển thị tên, slug và trạng thái', (tester) async {
      await pumpCategories(tester);
      expect(find.text('High Grade'), findsOneWidget);
      expect(find.text('high-grade · Đang bán'), findsOneWidget);
    });

    testWidgets('C17 chưa có danh mục thì báo danh sách trống', (tester) async {
      await pumpCategories(tester, FakeShopApi());
      expect(find.text('Chưa có danh mục nào.'), findsOneWidget);
    });
  });

  group('UC17 chi tiết', () {
    testWidgets('C11 bấm vào dòng thì gọi GET theo id', (tester) async {
      final api = await pumpCategories(tester);
      await openHighGrade(tester);

      expect(api.called('GET', '/api/v1/categories/cat-hg'), isTrue);
      expect(find.text('Chi tiết danh mục'), findsOneWidget);
      expect(find.text('High Grade'), findsOneWidget);
      expect(find.text('high-grade'), findsOneWidget);
      expect(find.text('Chưa có'), findsOneWidget);
      expect(find.text('Đang bán'), findsOneWidget);
    });

    testWidgets('C12 danh mục không còn tồn tại thì hiện 404 và nút thử lại', (
      tester,
    ) async {
      final api = await pumpCategories(tester);
      api.categories.clear();
      await openHighGrade(tester);

      expect(find.text('Không tìm thấy danh mục.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });

  group('UC18 thêm', () {
    testWidgets('C2 gửi POST đã bỏ khoảng trắng và tải lại danh sách', (
      tester,
    ) async {
      final api = await pumpCategories(tester);
      await openAddForm(tester);
      await tester.enterText(field('Tên'), '  Master Grade ');
      await tester.enterText(field('Slug'), 'master-grade');
      await tapAndSettle(tester, find.text('Lưu'));

      final body = api.lastBody('POST', '/api/v1/categories');
      expect(body['name'], 'Master Grade');
      expect(body['description'], isNull);
      expect(find.text('Thêm danh mục'), findsOneWidget);
      expect(find.text('Master Grade'), findsOneWidget);
    });

    testWidgets('C3 form rỗng bị chặn, không gọi API', (tester) async {
      final api = await pumpCategories(tester);
      await openAddForm(tester);
      await tapAndSettle(tester, find.text('Lưu'));

      expect(find.text('Không được để trống'), findsNWidgets(2));
      expect(api.called('POST', '/api/v1/categories'), isFalse);
    });

    testWidgets('C4 slug trùng thì form giữ nguyên và hiện lỗi 409', (
      tester,
    ) async {
      await pumpCategories(tester);
      await openAddForm(tester);
      await tester.enterText(field('Tên'), 'Trùng');
      await tester.enterText(field('Slug'), 'HIGH-GRADE');
      await tapAndSettle(tester, find.text('Lưu'));

      expect(find.text('Slug danh mục đã tồn tại.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Trùng'), findsOneWidget);
      expect(find.text('HIGH-GRADE'), findsOneWidget);
    });

    testWidgets('C18 sửa slug sau lỗi 409 thì lưu được ngay', (tester) async {
      await pumpCategories(tester);
      await openAddForm(tester);
      await tester.enterText(field('Tên'), 'Real Grade');
      await tester.enterText(field('Slug'), 'high-grade');
      await tapAndSettle(tester, find.text('Lưu'));

      await tester.enterText(field('Slug'), 'real-grade');
      await tapAndSettle(tester, find.text('Lưu'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('real-grade · Đang bán'), findsOneWidget);
    });

    testWidgets('C19 bấm Hủy thì không gọi API', (tester) async {
      final api = await pumpCategories(tester);
      await openAddForm(tester);
      await tester.enterText(field('Tên'), 'Bỏ');
      await tapAndSettle(tester, find.text('Hủy'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(api.called('POST', '/api/v1/categories'), isFalse);
    });
  });

  group('UC19 sửa', () {
    testWidgets('C5 form điền sẵn dữ liệu cũ, gửi PUT và cập nhật cả hai màn', (
      tester,
    ) async {
      final api = await pumpCategories(tester);
      await openHighGrade(tester);
      await tapAndSettle(tester, find.text('Sửa'));

      expect(find.text('Sửa danh mục'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'high-grade'), findsOneWidget);

      await tester.enterText(field('Tên'), 'HG Universal');
      await tapAndSettle(tester, find.text('Lưu'));

      expect(api.called('PUT', '/api/v1/categories/cat-hg'), isTrue);
      expect(find.text('HG Universal'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('HG Universal'), findsOneWidget);
      expect(find.text('High Grade'), findsNothing);
    });
  });

  group('UC20 ngừng bán', () {
    testWidgets('C6 còn sản phẩm đang bán thì API từ chối', (tester) async {
      final api = await pumpCategories(tester);
      await openHighGrade(tester);
      await tapAndSettle(tester, find.text('Ngừng bán'));
      await tapAndSettle(tester, find.text('Đồng ý'));

      expect(
        find.text('Còn sản phẩm đang bán trong danh mục.'),
        findsOneWidget,
      );
      expect(api.categories.first['isActive'], isTrue);
    });

    testWidgets('C15 hết sản phẩm đang bán thì đổi nhãn, giữ bản ghi', (
      tester,
    ) async {
      final api = FakeShopApi().seed();
      api.products.first['isActive'] = false;
      await pumpCategories(tester, api);
      await openHighGrade(tester);
      await tapAndSettle(tester, find.text('Ngừng bán'));
      await tapAndSettle(tester, find.text('Đồng ý'));

      expect(api.called('DELETE', '/api/v1/categories/cat-hg'), isTrue);
      expect(find.text('Đã ngừng bán danh mục'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('high-grade · Ngừng bán'), findsOneWidget);
    });

    testWidgets('C20 bấm "Không" ở hộp xác nhận thì không gửi DELETE', (
      tester,
    ) async {
      final api = await pumpCategories(tester);
      await openHighGrade(tester);
      await tapAndSettle(tester, find.text('Ngừng bán'));
      await tapAndSettle(tester, find.text('Không'));

      expect(api.called('DELETE', '/api/v1/categories/cat-hg'), isFalse);
    });

    testWidgets('C21 danh mục đã ngừng thì khóa nút Ngừng bán', (tester) async {
      final api = FakeShopApi().seed();
      api.categories.first['isActive'] = false;
      await pumpCategories(tester, api);
      await openHighGrade(tester);

      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Ngừng bán').last,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });
}
