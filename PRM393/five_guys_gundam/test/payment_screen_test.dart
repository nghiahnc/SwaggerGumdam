import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/payment.dart';
import 'package:http/http.dart' as http;

import 'support/fake_shop_api.dart';

/// Both mock results, the order status read again after paying, and how
/// refused or failed calls are shown.
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

  /// The app goes to the background (the browser opens) and comes back,
  /// through every state a real device passes.
  void leaveAndReturn(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
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
    // Same short form as the order screens ("#48A8D86D").
    expect(find.text('Đơn #ORDER-00'), findsOneWidget);
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
    // Nothing is left to pay, so the amount is the order total.
    expect(find.text('Tổng đơn: 350.000 ₫'), findsOneWidget);
    expect(find.textContaining('Cần thanh toán'), findsNothing);
  });

  for (final closed in ['Cancelled', 'Expired', 'PaymentFailed']) {
    testWidgets('money taken after the order became $closed: a refund is due', (
      tester,
    ) async {
      fake.on(
        'GET',
        orderPath,
        orderJson(id: orderId, status: closed, paymentStatus: 'RefundRequired'),
      );
      await open(tester);
      expect(find.byKey(const Key('outcome-refund')), findsOneWidget);
      expect(find.textContaining('hoàn lại thủ công'), findsOneWidget);
      expect(find.textContaining('không thanh toán lại'), findsOneWidget);
      // None of the closed-order messages, which would hide the payment.
      expect(find.textContaining('Hãy tạo đơn mới'), findsNothing);
      expect(find.textContaining('không thể thanh toán'), findsNothing);
      expect(find.textContaining('Thanh toán thất bại.'), findsNothing);
      expect(find.text('Tổng đơn: 350.000 ₫'), findsOneWidget);
      // The chip names the refund, not the closed status next to it.
      expect(find.text('Cần hoàn tiền'), findsOneWidget);
      for (final label in ['Đã hủy', 'Đã hết hạn', 'Thanh toán thất bại']) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });
  }

  testWidgets('coming back from Stripe Checkout reads the order again', (
    tester,
  ) async {
    fake.on('POST', sessionPath, {
      'orderId': orderId,
      'provider': 'Stripe',
      'status': 'Pending',
      'checkoutUrl': 'https://checkout.stripe.com/c/pay/test',
    });
    await tester.pumpWidget(
      fake.wrap(PaymentScreen(orderId: orderId, openUrl: (_) async => true)),
    );
    await tester.pumpAndSettle();

    // Switching apps before Checkout was opened reads nothing.
    leaveAndReturn(tester);
    await tester.pumpAndSettle();
    expect(fake.count('GET $orderPath'), 1);

    await tester.tap(find.byKey(const Key('stripe-open')));
    await tester.pumpAndSettle();
    // Back without paying yet: read quietly, no repeated snackbar.
    leaveAndReturn(tester);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
    expect(fake.count('GET $orderPath'), 2);
    expect(find.textContaining('Chưa nhận được kết quả'), findsNothing);
    expect(find.byKey(const Key('stripe-open')), findsOneWidget);

    status = 'Paid'; // the webhook arrived while the customer was on Stripe
    leaveAndReturn(tester);
    await tester.pumpAndSettle();
    expect(fake.count('GET $orderPath'), 3);
    expect(find.text('Đã thanh toán'), findsOneWidget);

    // Once the order is settled, focusing the app again reads nothing.
    leaveAndReturn(tester);
    await tester.pumpAndSettle();
    expect(fake.count('GET $orderPath'), 3);
  });

  testWidgets('an older quiet refresh does not replace a newer reload', (
    tester,
  ) async {
    fake.on('POST', sessionPath, {
      'orderId': orderId,
      'provider': 'Stripe',
      'status': 'Pending',
      'checkoutUrl': 'https://checkout.stripe.com/c/pay/test',
    });
    final slow = Completer<void>();
    var reads = 0;
    fake.onRequest('GET', orderPath, (_) async {
      reads++;
      final now = status;
      if (reads == 2) await slow.future; // the read started on return
      return FakeShopApi.json(orderJson(id: orderId, status: now));
    });
    await tester.pumpWidget(
      fake.wrap(PaymentScreen(orderId: orderId, openUrl: (_) async => true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stripe-open')));
    await tester.pumpAndSettle();

    leaveAndReturn(tester); // read 2 starts while the order is still pending
    await tester.pump();
    status = 'Paid';
    await tester.tap(find.byTooltip('Tải lại trạng thái')); // read 3
    await tester.pumpAndSettle();
    expect(find.text('Đã thanh toán'), findsOneWidget);

    slow.complete(); // read 2 answers late with the pending order
    await tester.pumpAndSettle();
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.text('Chờ thanh toán'), findsNothing);
  });

  testWidgets('a refused session does not stop reading on return', (
    tester,
  ) async {
    fake.on('POST', sessionPath, {
      'orderId': orderId,
      'provider': 'Stripe',
      'status': 'Pending',
      'checkoutUrl': 'https://checkout.stripe.com/c/pay/test',
    });
    await tester.pumpWidget(
      fake.wrap(PaymentScreen(orderId: orderId, openUrl: (_) async => true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stripe-open')));
    await tester.pumpAndSettle();

    // A passing failure: the order still waits, only the session call fails.
    fake.refuse('POST', sessionPath, 503, 'Stripe tạm lỗi.');
    leaveAndReturn(tester);
    await tester.pumpAndSettle();
    expect(fake.count('GET $orderPath'), 2);

    status = 'Paid';
    leaveAndReturn(tester);
    await tester.pumpAndSettle();
    expect(fake.count('GET $orderPath'), 3);
    expect(find.text('Đã thanh toán'), findsOneWidget);
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
    // Not a test-mode session id, so no test-card hint.
    expect(find.byKey(const Key('stripe-test-card')), findsNothing);
    status = 'Paid';
    await tester.tap(find.byKey(const Key('stripe-reload')));
    await tester.pumpAndSettle();
    expect(find.text('Đã thanh toán'), findsOneWidget);
  });

  testWidgets('Stripe test mode tells which test card to use', (tester) async {
    fake.on('POST', sessionPath, {
      'orderId': orderId,
      'provider': 'Stripe',
      'status': 'Pending',
      'checkoutUrl': 'https://checkout.stripe.com/c/pay/cs_test_a1B2c3',
    });
    await open(tester);
    expect(find.textContaining('4242 4242 4242 4242'), findsOneWidget);
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
    expect(find.text('Đã hết hạn'), findsOneWidget);
    expect(find.textContaining('quá hạn thanh toán'), findsOneWidget);
  });

  testWidgets('an order id shorter than 8 characters is shown whole', (
    tester,
  ) async {
    fake.on('GET', '/api/v1/orders/a1', orderJson(id: 'a1', status: 'Paid'));
    await tester.pumpWidget(fake.wrap(const PaymentScreen(orderId: 'a1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Đơn #A1'), findsOneWidget);
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

  testWidgets('API down while loading: the error offers a retry that works', (
    tester,
  ) async {
    var down = true;
    fake.onRequest('GET', orderPath, (_) {
      if (down) throw http.ClientException('connection refused');
      return FakeShopApi.json(orderJson(id: orderId, status: status));
    });
    await open(tester);
    expect(find.text('Yêu cầu mạng thất bại. Hãy thử lại.'), findsOneWidget);
    down = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chờ thanh toán'), findsOneWidget);
    expect(find.byKey(const Key('mock-success')), findsOneWidget);
  });

  testWidgets('a 409 while the order is still pending keeps the reason', (
    tester,
  ) async {
    fake.refuse('POST', sessionPath, 409, 'Đơn sắp hết hạn, hãy tạo đơn mới.');
    await open(tester);
    expect(fake.count('GET $orderPath'), 2);
    expect(find.text('Đơn sắp hết hạn, hãy tạo đơn mới.'), findsOneWidget);
    expect(find.text('Chờ thanh toán'), findsOneWidget);
  });

  testWidgets('a payment set-up error (5xx) is shown as one plain sentence', (
    tester,
  ) async {
    fake.refuse(
      'POST',
      sessionPath,
      503,
      'Cần Stripe secret key hợp lệ; live key chỉ được bật trong Production.',
    );
    await open(tester);
    expect(
      find.text('Thanh toán đang tạm gián đoạn, hãy thử lại sau.'),
      findsOneWidget,
    );
    expect(find.textContaining('Stripe secret key'), findsNothing);
  });

  testWidgets('Stripe: reloading before Stripe reports back says so', (
    tester,
  ) async {
    fake.on('POST', sessionPath, {
      'orderId': orderId,
      'provider': 'Stripe',
      'status': 'Pending',
      'checkoutUrl': 'https://checkout.stripe.com/c/pay/test',
    });
    await open(tester);
    await tester.tap(find.byKey(const Key('stripe-reload')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Chưa nhận được kết quả từ Stripe'),
      findsOneWidget,
    );
    expect(fake.count('GET $orderPath'), 2);
  });
}
