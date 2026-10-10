import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/payment.dart';

import 'support/fake_shop_api.dart';

/// FL-15 minimum tests: both mock results, and the order status read again
/// after paying.
void main() {
  const orderId = 'order-0001-aaaa';
  const orderPath = '/api/v1/orders/$orderId';
  const sessionPath = '/api/v1/payments/orders/$orderId/session';
  const mockPath = '/api/v1/payments/mock/orders/$orderId/complete';

  late FakeShopApi fake;
  late String status;

  setUp(() {
    status = 'PendingPayment';
    fake = FakeShopApi()..signIn(id: 'customer-1', role: 'Customer');
    fake.onRequest(
      'GET',
      orderPath,
      (_) => FakeShopApi.json(orderJson(id: orderId, status: status)),
    );
    fake.on('POST', sessionPath, {
      'orderId': orderId,
      'provider': 'Mock',
      'status': 'Pending',
      'checkoutUrl': null,
    });
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(fake.wrap(const PaymentScreen(orderId: orderId)));
    await tester.pumpAndSettle();
  }

  void mockApiResult({required bool succeeded}) =>
      fake.onRequest('POST', mockPath, (_) {
        status = succeeded ? 'Paid' : 'PaymentFailed';
        return FakeShopApi.json({'orderId': orderId, 'succeeded': succeeded});
      });

  testWidgets('shows the order and the two mock results while pending', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Đơn order-00'), findsOneWidget);
    expect(find.text('Cần thanh toán: 350.000 ₫'), findsOneWidget);
    expect(find.text('Chờ thanh toán'), findsOneWidget);
    expect(find.byKey(const Key('mock-success')), findsOneWidget);
    expect(find.byKey(const Key('mock-fail')), findsOneWidget);
  });

  testWidgets('mock success: the status is read again and shows Paid', (
    tester,
  ) async {
    mockApiResult(succeeded: true);
    await open(tester);
    await tester.tap(find.byKey(const Key('mock-success')));
    await tester.pumpAndSettle();

    expect(fake.lastBody('POST', mockPath), {'succeeded': true});
    expect(fake.count('GET $orderPath'), 2);
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.textContaining('Thanh toán thành công'), findsOneWidget);
    expect(find.byKey(const Key('mock-success')), findsNothing);
    expect(find.byKey(const Key('payment-back')), findsOneWidget);
  });

  testWidgets('mock failure: shows the failed status and what was given back', (
    tester,
  ) async {
    mockApiResult(succeeded: false);
    await open(tester);
    await tester.tap(find.byKey(const Key('mock-fail')));
    await tester.pumpAndSettle();

    expect(fake.lastBody('POST', mockPath), {'succeeded': false});
    expect(find.text('Thanh toán thất bại'), findsOneWidget);
    expect(find.textContaining('tồn kho và lượt voucher'), findsOneWidget);
  });

  testWidgets('an order that is no longer pending skips the payment session', (
    tester,
  ) async {
    status = 'Paid';
    await open(tester);
    expect(fake.calls, isNot(contains('POST $sessionPath')));
    expect(find.textContaining('Thanh toán thành công'), findsOneWidget);
  });

  testWidgets('a refused mock call is reported and the status is reloaded', (
    tester,
  ) async {
    fake.refuse('POST', mockPath, 404, 'Mock payment đang tắt.');
    await open(tester);
    await tester.tap(find.byKey(const Key('mock-success')));
    await tester.pumpAndSettle();

    expect(find.text('Mock payment đang tắt.'), findsOneWidget);
    expect(fake.count('GET $orderPath'), 2);
    expect(find.text('Chờ thanh toán'), findsOneWidget);
  });

  testWidgets('Stripe: offers Checkout and reloads the status on request', (
    tester,
  ) async {
    fake.on('POST', sessionPath, {
      'orderId': orderId,
      'provider': 'Stripe',
      'status': 'Pending',
      'checkoutUrl': 'https://checkout.stripe.com/c/pay/test',
    });
    await open(tester);
    expect(find.byKey(const Key('stripe-open')), findsOneWidget);
    status = 'Paid';
    await tester.tap(find.byKey(const Key('stripe-reload')));
    await tester.pumpAndSettle();
    expect(find.text('Đã thanh toán'), findsOneWidget);
  });

  testWidgets('a free order paid by the session call shows success', (
    tester,
  ) async {
    fake.onRequest('POST', sessionPath, (_) {
      status = 'Paid'; // the API completes a 0 ₫ order inside the call
      return FakeShopApi.json({
        'orderId': orderId,
        'provider': 'Stripe',
        'status': 'Paid',
        'checkoutUrl': null,
      });
    });
    await open(tester);
    expect(fake.count('GET $orderPath'), 2);
    expect(find.textContaining('Thanh toán thành công'), findsOneWidget);
  });

  testWidgets('a 409 from the session call shows what the order became', (
    tester,
  ) async {
    fake.onRequest('POST', sessionPath, (_) {
      status = 'Expired'; // the expiry job ran between the two calls
      return FakeShopApi.json({
        'title': 'Đơn không chờ thanh toán.',
        'status': 409,
      }, status: 409);
    });
    await open(tester);
    expect(find.text('Hết hạn thanh toán'), findsOneWidget);
    expect(find.textContaining('quá hạn thanh toán'), findsOneWidget);
  });

  testWidgets('a refused session keeps the order on screen with the reason', (
    tester,
  ) async {
    fake.refuse('POST', sessionPath, 404, 'Không tìm thấy đơn hàng.');
    await open(tester);
    expect(find.text('Cần thanh toán: 350.000 ₫'), findsOneWidget);
    expect(find.byKey(const Key('payment-problem')), findsOneWidget);
    expect(find.text('Không tìm thấy đơn hàng.'), findsOneWidget);
    expect(find.byKey(const Key('mock-success')), findsNothing);
  });

  testWidgets('Stripe: "Mở Stripe Checkout" opens the session URL', (
    tester,
  ) async {
    const url = 'https://checkout.stripe.com/c/pay/test';
    fake.on('POST', sessionPath, {
      'orderId': orderId,
      'provider': 'Stripe',
      'status': 'Pending',
      'checkoutUrl': url,
    });
    Uri? opened;
    await tester.pumpWidget(
      fake.wrap(
        PaymentScreen(
          orderId: orderId,
          openUrl: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stripe-open')));
    await tester.pumpAndSettle();
    expect(opened, Uri.parse(url));
    expect(find.text('Không mở được trang Stripe Checkout.'), findsNothing);
  });

  testWidgets('while a mock result is sent, buttons and Back are locked', (
    tester,
  ) async {
    final answer = Completer<void>();
    fake.onRequest('POST', mockPath, (_) async {
      await answer.future;
      status = 'Paid';
      return FakeShopApi.json({'orderId': orderId, 'succeeded': true});
    });
    await tester.pumpWidget(
      fake.wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentScreen(orderId: orderId),
              ),
            ),
            child: const Text('Mở thanh toán'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở thanh toán'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mock-success')));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('mock-success')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('mock-fail')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const Key('mock-success')), findsOneWidget);

    answer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Đã thanh toán'), findsOneWidget);
  });
}
