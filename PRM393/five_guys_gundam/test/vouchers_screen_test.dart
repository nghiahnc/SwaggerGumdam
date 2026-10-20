import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/dates.dart';
import 'package:five_guys_gundam/screens/vouchers.dart';

import 'support/fake_shop_api.dart';

/// Wrong dates, duplicate code, expired voucher and Admin-only access, plus
/// the list, add, edit and stop flows.
void main() {
  const list = 'GET /api/v1/vouchers';
  final now = DateTime.now().toUtc();
  final expiredEnd = DateTime.utc(
    now.year,
    now.month,
    now.day,
    1,
  ).subtract(const Duration(days: 2));
  final activeStart = DateTime.utc(2026, 1, 1, 1, 30);
  final activeEnd = DateTime.utc(2099, 12, 31, 16, 45);

  /// Device-time text built without the code under test, so a screen that
  /// showed UTC (or read the API's zone-less dates as local) would differ.
  String shown(DateTime utc) {
    final t = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  late FakeShopApi fake;
  setUp(() {
    fake = FakeShopApi()..signIn();
    fake.on(
      'GET',
      '/api/v1/vouchers',
      page([
        voucherJson(
          id: 'v-active',
          code: 'SALE10',
          startsAtUtc: activeStart,
          endsAtUtc: activeEnd,
        ),
        voucherJson(
          id: 'v-expired',
          code: 'SUMMER',
          startsAtUtc: expiredEnd.subtract(const Duration(days: 10)),
          endsAtUtc: expiredEnd,
        ),
        voucherJson(id: 'v-stopped', code: 'OLD', isActive: false),
      ]),
    );
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(fake.wrap(const VouchersScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> chooseMenu(WidgetTester tester, String id, String item) async {
    await tester.tap(find.byKey(ValueKey('voucher-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('quyền Admin: a customer is refused and nothing is sent', (
    tester,
  ) async {
    fake.signIn(id: 'customer-1', role: 'Customer');
    await open(tester);
    expect(find.byKey(const Key('vouchers-denied')), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('quyền Admin: a 403 from the API is explained', (tester) async {
    fake.on('GET', '/api/v1/vouchers', null, status: 403);
    await open(tester);
    expect(
      find.text('Tài khoản hiện tại không có quyền thực hiện thao tác này.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('voucher hết hạn: each voucher shows its state and UTC dates', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Đang áp dụng'), findsOneWidget);
    expect(find.text('Hết hạn'), findsOneWidget);
    expect(find.text('Ngừng sử dụng'), findsOneWidget);
    // The API sends the end date without "Z"; it must still be read as UTC.
    expect(find.textContaining(shown(expiredEnd)), findsOneWidget);
    expect(
      find.text('${shown(activeStart)} → ${shown(activeEnd)}'),
      findsOneWidget,
    );
    // A stopped voucher cannot be switched back on, so it has no menu.
    expect(find.byKey(const ValueKey('voucher-menu-v-stopped')), findsNothing);
    expect(
      find.byKey(const ValueKey('voucher-menu-v-expired')),
      findsOneWidget,
    );
  });

  testWidgets('ngày sai: saving an expired period is refused before sending', (
    tester,
  ) async {
    await open(tester);
    await chooseMenu(tester, 'v-expired', 'Sửa');
    expect(find.text('Sửa voucher'), findsOneWidget);
    await tester.tap(find.byKey(const Key('voucher-save')));
    await tester.pumpAndSettle();
    expect(find.text('Thời gian kết thúc đã qua'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('PUT')), isEmpty);
    expect(find.text('Sửa voucher'), findsOneWidget);
  });

  testWidgets('an empty form shows the field errors and sends nothing', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('add-voucher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voucher-save')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập mã voucher'), findsOneWidget);
    expect(find.text('Nhập số tiền giảm là số nguyên (VND)'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('POST')), isEmpty);
  });

  testWidgets(
    'mã trùng: the API refusal keeps the dialog open with its reason',
    (tester) async {
      fake.refuse('POST', '/api/v1/vouchers', 409, 'Mã voucher đã tồn tại.');
      await open(tester);
      await tester.tap(find.byKey(const Key('add-voucher')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('voucher-code')), ' sale10');
      await tester.pump();
      expect(find.text('Sẽ lưu là SALE10'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('voucher-discount')),
        '50000',
      );
      await tester.tap(find.byKey(const Key('voucher-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voucher-server-error')), findsOneWidget);
      expect(find.text('Mã voucher đã tồn tại.'), findsOneWidget);
      expect(
        find.text('Thêm voucher'),
        findsWidgets,
      ); // dialog title still there
      final sent = fake.lastBody('POST', '/api/v1/vouchers');
      expect(sent['code'], 'SALE10');
      expect(sent['discountVnd'], 50000);
      expect(sent['maxUses'], 100);
      expect((sent['startsAtUtc'] as String).endsWith('Z'), isTrue);
      expect((sent['endsAtUtc'] as String).endsWith('Z'), isTrue);
    },
  );

  testWidgets('adds a voucher, closes the dialog and reloads the list', (
    tester,
  ) async {
    fake.on(
      'POST',
      '/api/v1/vouchers',
      voucherJson(id: 'v-new', code: 'NEW50'),
      status: 201,
    );
    await open(tester);
    expect(fake.count(list), 1);
    await tester.tap(find.byKey(const Key('add-voucher')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('voucher-code')), 'new50');
    await tester.enterText(find.byKey(const Key('voucher-discount')), '50000');
    await tester.enterText(
      find.byKey(const Key('voucher-min-subtotal')),
      '300000',
    );
    await tester.tap(find.byKey(const Key('voucher-save')));
    await tester.pumpAndSettle();
    expect(fake.lastBody('POST', '/api/v1/vouchers')['minSubtotalVnd'], 300000);

    expect(find.byKey(const Key('voucher-save')), findsNothing);
    expect(find.text('Đã thêm voucher NEW50'), findsOneWidget);
    expect(fake.count(list), 2);
  });

  testWidgets('stop using asks first, sends DELETE and reloads', (
    tester,
  ) async {
    fake.on('DELETE', '/api/v1/vouchers/v-active', null, status: 204);
    await open(tester);
    await chooseMenu(tester, 'v-active', 'Ngừng sử dụng');
    expect(find.text('Xác nhận'), findsOneWidget);
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('DELETE /api/v1/vouchers/v-active'));
    expect(find.text('Đã ngừng sử dụng SALE10'), findsOneWidget);
    expect(fake.count(list), 2);
  });

  testWidgets(
    'edits a voucher with PUT, keeping its dates as the same instants',
    (tester) async {
      fake.on('PUT', '/api/v1/vouchers/v-active', voucherJson(id: 'v-active'));
      await open(tester);
      await chooseMenu(tester, 'v-active', 'Sửa');
      await tester.enterText(
        find.byKey(const Key('voucher-discount')),
        '70000',
      );
      await tester.tap(find.byKey(const Key('voucher-save')));
      await tester.pumpAndSettle();

      final sent = fake.lastBody('PUT', '/api/v1/vouchers/v-active');
      expect(sent['code'], 'SALE10');
      expect(sent['discountVnd'], 70000);
      expect(parseUtc(sent['startsAtUtc'] as String), activeStart);
      expect(parseUtc(sent['endsAtUtc'] as String), activeEnd);
      expect(fake.calls.where((c) => c == 'POST /api/v1/vouchers'), isEmpty);
      expect(find.text('Đã cập nhật voucher SALE10'), findsOneWidget);
      expect(fake.count(list), 2);
    },
  );

  testWidgets('the usage limit cannot go below the uses already made', (
    tester,
  ) async {
    fake.on(
      'GET',
      '/api/v1/vouchers',
      page([voucherJson(id: 'v-used', usedCount: 5, maxUses: 10)]),
    );
    await open(tester);
    await chooseMenu(tester, 'v-used', 'Sửa');
    expect(
      find.text('Đã dùng 5 lượt (gồm đơn chờ thanh toán)'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('voucher-max-uses')), '3');
    await tester.tap(find.byKey(const Key('voucher-save')));
    await tester.pumpAndSettle();
    expect(find.text('Không được nhỏ hơn số lượt đã dùng (5)'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('PUT')), isEmpty);
  });

  testWidgets(
    'a voucher made elsewhere keeps its code when only dates change',
    (tester) async {
      fake.on(
        'GET',
        '/api/v1/vouchers',
        page([voucherJson(id: 'v-legacy', code: 'TẾT 2026', maxUses: 5000000)]),
      );
      fake.on('PUT', '/api/v1/vouchers/v-legacy', voucherJson(id: 'v-legacy'));
      await open(tester);
      await chooseMenu(tester, 'v-legacy', 'Sửa');
      await tester.tap(find.byKey(const Key('voucher-save')));
      await tester.pumpAndSettle();
      final sent = fake.lastBody('PUT', '/api/v1/vouchers/v-legacy');
      expect(sent['code'], 'TẾT 2026');
      expect(sent['maxUses'], 5000000);
    },
  );

  testWidgets('the form cannot be closed while it is saving', (tester) async {
    final answer = Completer<void>();
    fake.onRequest('POST', '/api/v1/vouchers', (_) async {
      await answer.future;
      return FakeShopApi.json(voucherJson(id: 'v-new'), status: 201);
    });
    await open(tester);
    await tester.tap(find.byKey(const Key('add-voucher')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('voucher-code')), 'wait');
    await tester.enterText(find.byKey(const Key('voucher-discount')), '1000');
    await tester.tap(find.byKey(const Key('voucher-save')));
    await tester.pump();

    final save = tester.widget<FilledButton>(
      find.byKey(const Key('voucher-save')),
    );
    expect(save.onPressed, isNull);
    await tester.tapAt(const Offset(4, 4)); // outside the dialog
    await tester.binding.handlePopRoute(); // Android back
    await tester.pump();
    expect(find.byKey(const Key('voucher-save')), findsOneWidget);

    answer.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voucher-save')), findsNothing);
    expect(find.text('Đã thêm voucher WAIT'), findsOneWidget);
  });

  testWidgets('an empty list says how to start', (tester) async {
    fake.on('GET', '/api/v1/vouchers', page([]));
    await open(tester);
    expect(
      find.text('Chưa có voucher. Bấm "Thêm voucher" để tạo mã đầu tiên.'),
      findsOneWidget,
    );
  });

  testWidgets('field messages may wrap instead of being cut off', (
    tester,
  ) async {
    // Test fonts are far wider than real ones, so the check is on the
    // setting itself: every field lets its message use up to 3 lines.
    await open(tester);
    await tester.tap(find.byKey(const Key('add-voucher')));
    await tester.pumpAndSettle();
    for (final key in [
      'voucher-code',
      'voucher-discount',
      'voucher-min-subtotal',
      'voucher-max-uses',
    ]) {
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextField),
        ),
      );
      expect(field.decoration!.errorMaxLines, 3, reason: key);
    }
  });

  testWidgets('the date and time pickers are fully Vietnamese, 24-hour', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('add-voucher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voucher-starts')));
    await tester.pumpAndSettle();

    // Month, weekdays and navigation come from Material's translations.
    expect(find.textContaining(RegExp(r'^tháng \d+ năm \d{4}$')), findsWidgets);
    expect(find.text('CN'), findsOneWidget);
    expect(find.byTooltip('Tháng sau'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsNothing);

    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn giờ'), findsOneWidget);
    expect(
      MediaQuery.alwaysUse24HourFormatOf(tester.element(find.text('Chọn giờ'))),
      isTrue,
    );
    for (final period in ['AM', 'PM', 'SÁNG', 'CHIỀU']) {
      expect(find.text(period), findsNothing, reason: period);
    }
  });

  testWidgets('a typed date is read day first, as its hint says', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('add-voucher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voucher-starts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chuyển sang chế độ nhập'));
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '');
    await tester.pump();
    expect(find.text('dd/mm/yyyy'), findsOneWidget);

    // 25 cannot be a month, so only a day-first reading accepts it.
    await tester.enterText(field, '25/10/2027');
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    expect(find.text('Sai định dạng ngày'), findsNothing);
    expect(find.textContaining('25/10/2027'), findsOneWidget);
  });

  testWidgets('a discount that reaches the minimum warns about 0 ₫ orders', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('add-voucher')));
    await tester.pumpAndSettle();
    // A typo (500000 for 50000) on a voucher without a minimum order.
    await tester.enterText(find.byKey(const Key('voucher-discount')), '500000');
    await tester.pump();
    expect(
      find.text('Lưu ý: đơn từ 0 ₫ đến 500.000 ₫ sẽ được giảm còn 0 ₫.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('voucher-min-subtotal')),
      '600000',
    );
    await tester.pump();
    expect(find.byKey(const Key('voucher-free-warning')), findsNothing);
  });

  testWidgets('the code of a voucher already used cannot be changed', (
    tester,
  ) async {
    fake.on(
      'GET',
      '/api/v1/vouchers',
      page([
        voucherJson(id: 'v-used', code: 'USED', usedCount: 1),
        voucherJson(id: 'v-new', code: 'FRESH'),
      ]),
    );
    TextField codeField() => tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('voucher-code')),
        matching: find.byType(TextField),
      ),
    );
    await open(tester);
    await chooseMenu(tester, 'v-used', 'Sửa');
    expect(codeField().readOnly, isTrue);
    expect(
      find.text('Đã có đơn dùng mã này nên không đổi được mã'),
      findsOneWidget,
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    await chooseMenu(tester, 'v-new', 'Sửa');
    expect(codeField().readOnly, isFalse);
  });

  testWidgets('the code lock reads the voucher as it is now, not the list', (
    tester,
  ) async {
    // Listed unused, but a customer checked out with it since.
    fake.on('GET', '/api/v1/vouchers', page([voucherJson(id: 'v-1')]));
    fake.on(
      'GET',
      '/api/v1/vouchers/v-1',
      voucherJson(id: 'v-1', usedCount: 1),
    );
    await open(tester);
    await chooseMenu(tester, 'v-1', 'Sửa');
    expect(fake.calls, contains('GET /api/v1/vouchers/v-1'));
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('voucher-code')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.readOnly, isTrue);
    expect(
      find.text('Đã dùng 1 lượt (gồm đơn chờ thanh toán)'),
      findsOneWidget,
    );
  });

  testWidgets('the list says that unpaid orders hold uses', (tester) async {
    await open(tester);
    expect(
      find.textContaining('tính cả đơn đang chờ thanh toán'),
      findsOneWidget,
    );
  });

  test('vouchers beyond the first 100 are read too', () async {
    fake.onRequest('GET', '/api/v1/vouchers', (request) {
      final pageNumber = int.parse(request.url.queryParameters['page']!);
      final items = pageNumber == 1
          ? [
              for (var i = 0; i < 100; i++)
                voucherJson(id: 'v-$i', code: 'A${'$i'.padLeft(3, '0')}'),
            ]
          : [voucherJson(id: 'v-last', code: 'ZZZ-LAST')];
      return FakeShopApi.json({
        'items': items,
        'pageNumber': pageNumber,
        'pageSize': 100,
        'totalCount': 101,
      });
    });
    final vouchers = await fake.repository.vouchers();
    expect(vouchers, hasLength(101));
    expect(vouchers.last.code, 'ZZZ-LAST');
    expect(
      [for (final r in fake.requests) r.url.queryParameters['page']],
      ['1', '2'],
    );
  });

  test(
    'a voucher added between two pages: read again, no duplicates',
    () async {
      var created = false;
      fake.onRequest('GET', '/api/v1/vouchers', (request) {
        final pageNumber = int.parse(request.url.queryParameters['page']!);
        // A new code that sorts first appears right after page 1 was read.
        final all = [
          if (created) voucherJson(id: 'v-aaa', code: 'AAA'),
          for (var i = 0; i < 150; i++)
            voucherJson(id: 'v-$i', code: 'B${'$i'.padLeft(3, '0')}'),
        ];
        final body = {
          'items': all.skip((pageNumber - 1) * 100).take(100).toList(),
          'pageNumber': pageNumber,
          'pageSize': 100,
          'totalCount': all.length,
        };
        created = true;
        return FakeShopApi.json(body);
      });
      final vouchers = await fake.repository.vouchers();
      final ids = vouchers.map((v) => v.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, hasLength(151));
      expect(ids, contains('v-aaa'));
    },
  );

  testWidgets('a voucher stopped since the list loaded is not edited', (
    tester,
  ) async {
    fake.on('GET', '/api/v1/vouchers', page([voucherJson(id: 'v-1')]));
    fake.on(
      'GET',
      '/api/v1/vouchers/v-1',
      voucherJson(id: 'v-1', isActive: false),
    );
    await open(tester);
    await chooseMenu(tester, 'v-1', 'Sửa');
    expect(find.text('Sửa voucher'), findsNothing);
    expect(find.text('Voucher SALE10 đã ngừng sử dụng'), findsOneWidget);
    expect(fake.count(list), 2);
  });

  test('a full page without totalCount reads on until a short page', () async {
    fake.onRequest('GET', '/api/v1/vouchers', (request) {
      final pageNumber = int.parse(request.url.queryParameters['page']!);
      return FakeShopApi.json({
        'items': [
          for (var i = 0; i < (pageNumber == 1 ? 100 : 3); i++)
            voucherJson(id: 'v-$pageNumber-$i'),
        ],
      });
    });
    expect(await fake.repository.vouchers(), hasLength(103));
  });
}
