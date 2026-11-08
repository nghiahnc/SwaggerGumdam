import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/vouchers.dart';

import 'support/fake_shop_api.dart';

void main() {
  late FakeShopApi fake;

  setUp(() {
    fake = FakeShopApi()..signIn();
  });

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(fake.wrap(screen));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a voucher reads its current details without editing', (
    tester,
  ) async {
    fake.on('GET', '/api/v1/vouchers', page([voucherJson(usedCount: 0)]));
    fake.on(
      'GET',
      '/api/v1/vouchers/v-1',
      voucherJson(
        code: 'CURRENT50',
        usedCount: 3,
        maxUses: 20,
        minSubtotalVnd: 300000,
      ),
    );
    await open(tester, const VouchersScreen());
    await tester.tap(find.byKey(const ValueKey('voucher-v-1')));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết voucher'), findsOneWidget);
    expect(find.text('CURRENT50'), findsOneWidget);
    expect(find.text('3/20'), findsOneWidget);
    expect(find.text('50.000 ₫'), findsOneWidget);
    expect(find.text('300.000 ₫'), findsOneWidget);
    expect(fake.count('GET /api/v1/vouchers/v-1'), 1);
    expect(find.byType(TextFormField), findsNothing);
    expect(fake.calls.every((call) => call.startsWith('GET ')), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fake.count('GET /api/v1/vouchers'), 2);
  });

  testWidgets('a stopped voucher still has readable details', (tester) async {
    final stopped = voucherJson(code: 'STOPPED', isActive: false);
    fake.on('GET', '/api/v1/vouchers', page([stopped]));
    fake.on('GET', '/api/v1/vouchers/v-1', stopped);
    await open(tester, const VouchersScreen());
    expect(find.byKey(const ValueKey('voucher-menu-v-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('voucher-v-1')));
    await tester.pumpAndSettle();

    expect(find.text('STOPPED'), findsOneWidget);
    expect(find.text('Ngừng sử dụng'), findsOneWidget);
    expect(find.textContaining('không thể bật lại'), findsOneWidget);
    expect(fake.count('GET /api/v1/vouchers/v-1'), 1);
  });

  testWidgets('failed detail reads can be retried with a fresh response', (
    tester,
  ) async {
    fake.refuse('GET', '/api/v1/vouchers/v-1', 404, 'Không tìm thấy voucher.');
    await open(tester, const VoucherDetailScreen(voucherId: 'v-1'));
    expect(find.text('Không tìm thấy voucher.'), findsOneWidget);
    expect(find.byKey(const Key('voucher-detail')), findsNothing);

    fake.on('GET', '/api/v1/vouchers/v-1', voucherJson());
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('SALE10'), findsOneWidget);
    expect(find.text('Không tìm thấy voucher.'), findsNothing);
    expect(fake.count('GET /api/v1/vouchers/v-1'), 2);
  });

  testWidgets('refresh reads changed usage and status', (tester) async {
    fake.on('GET', '/api/v1/vouchers/v-1', voucherJson(usedCount: 0));
    await open(tester, const VoucherDetailScreen(voucherId: 'v-1'));
    expect(find.text('0/10'), findsOneWidget);

    fake.on('GET', '/api/v1/vouchers/v-1', voucherJson(usedCount: 10));
    await tester.tap(find.byTooltip('Tải lại'));
    await tester.pumpAndSettle();
    expect(find.text('10/10'), findsOneWidget);
    expect(find.text('Hết lượt'), findsOneWidget);
    expect(fake.count('GET /api/v1/vouchers/v-1'), 2);
  });

  testWidgets('customers cannot open voucher details or send the read', (
    tester,
  ) async {
    fake.signIn(role: 'Customer');
    await open(tester, const VoucherDetailScreen(voucherId: 'v-1'));
    expect(find.byKey(const Key('voucher-detail-denied')), findsOneWidget);
    expect(fake.calls, isEmpty);
    expect(find.byTooltip('Tải lại'), findsNothing);
  });

  testWidgets('expired login on a detail read explains the next action', (
    tester,
  ) async {
    fake.on('GET', '/api/v1/vouchers/v-1', null, status: 401);
    await open(tester, const VoucherDetailScreen(voucherId: 'v-1'));
    expect(
      find.text('Phiên đăng nhập đã hết hạn. Hãy đăng xuất rồi đăng nhập lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
