import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/error_text.dart';
import '../core/models.dart';
import '../core/payment_policy.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';

/// FL-15 · Pay one order that is waiting for payment.
///
/// With `Payments:Provider = Stripe` the API returns a Stripe Checkout URL;
/// the order only changes when Stripe calls the webhook, so the customer
/// reloads the status after paying. In Development the provider is `Mock`:
/// two buttons make the payment succeed or fail on demand.
///
/// After every attempt the screen reads the order again and shows the status
/// the API now reports (Paid, or PaymentFailed with stock and voucher use
/// given back), rather than assuming the outcome.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({required this.orderId, this.openUrl, super.key});
  final String orderId;

  /// Opens the Stripe Checkout page; defaults to the system browser. Tests
  /// pass their own to check the URL without a real browser.
  final Future<bool> Function(Uri url)? openUrl;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

/// The order as the API reports it, plus the payment session when the order
/// still waits for payment, or why the session could not be opened.
class _PaymentView {
  const _PaymentView(this.order, this.session, {this.problem});
  final ShopOrder order;
  final Json? session;
  final String? problem;
  bool get pending => session != null;
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Future<_PaymentView> future;

  /// True while a mock result is being sent; locks both buttons.
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final next = readable(_load(context.read<ShopRepository>()));
    setState(() {
      future = next;
    });
  }

  Future<_PaymentView> _load(ShopRepository repository) async {
    var order = await repository.order(widget.orderId);
    // The API only opens a session for an order that still waits for
    // payment; asking for any other order is refused with 409.
    if (order.status != PaymentPolicy.pending) return _PaymentView(order, null);
    final Json session;
    try {
      session = await repository.paymentSession(widget.orderId);
    } on ApiException catch (error) {
      // 409: the order changed in between (paid through Stripe, expired);
      // show what it is now. Anything else (an order expiring within 30
      // minutes, not this customer's order) keeps the order on screen with
      // the reason, since retrying would only fail again.
      if (error.statusCode == 409) {
        final now = await repository.order(widget.orderId);
        if (now.status != PaymentPolicy.pending) return _PaymentView(now, null);
      }
      return _PaymentView(order, null, problem: describeError(error));
    }
    // A free order (total 0) is marked paid by the session call itself.
    if (session['status'] == 'Paid') {
      order = await repository.order(widget.orderId);
      return _PaymentView(order, null);
    }
    return _PaymentView(order, session);
  }

  Future<void> completeMock(bool succeeded) async {
    final repository = context.read<ShopRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    String? problem;
    try {
      await repository.completeMock(widget.orderId, succeeded);
    } catch (error) {
      problem = describeError(error);
    }
    if (!mounted) return;
    setState(() => busy = false);
    // The order status is the result, whatever the response said.
    reload();
    if (problem != null && messenger.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  Future<void> openStripe(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      final uri = Uri.parse(url);
      opened =
          await (widget.openUrl?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {}
    if (!opened && messenger.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Không mở được trang Stripe Checkout.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Leaving while a result is being sent would let the order screen read
    // the order before the payment is recorded.
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán'),
        actions: [
          IconButton(
            tooltip: 'Tải lại trạng thái',
            onPressed: busy ? null : reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(key: Key('payment-busy')),
              )
            : null,
      ),
      body: AsyncPanel<_PaymentView>(
        future: future,
        onRetry: reload,
        builder: (view) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _OrderSummary(order: view.order),
            const SizedBox(height: 20),
            if (view.problem != null)
              Text(
                view.problem!,
                key: const Key('payment-problem'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (!view.pending)
              _Outcome(
                status: view.order.status,
                onBack: () => Navigator.pop(context),
              )
            else if (view.session!['provider'] == 'Mock')
              _MockActions(busy: busy, onResult: completeMock)
            else if (view.session!['checkoutUrl'] is String)
              _StripeActions(
                onOpen: () =>
                    openStripe(view.session!['checkoutUrl'] as String),
                onReload: reload,
              )
            else
              const Text(
                'Chưa có trang thanh toán cho đơn này. Hãy tải lại trạng thái.',
              ),
          ],
        ),
      ),
    ),
  );
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đơn ${order.id.substring(0, 8)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Tạm tính: ${money(order.subtotalVnd)}'),
            if (order.discountVnd > 0)
              Text('Giảm giá: ${money(order.discountVnd)}'),
            Text(
              'Cần thanh toán: ${money(order.totalVnd)}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Chip(
              key: const Key('order-status'),
              label: Text(PaymentPolicy.orderStatus(order.status)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _MockActions extends StatelessWidget {
  const _MockActions({required this.busy, required this.onResult});
  final bool busy;
  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Chế độ thử (Development): chọn một kết quả để kiểm tra cả luồng đơn '
        'hàng. Thất bại sẽ đóng đơn và hoàn tồn kho.',
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('mock-success'),
        onPressed: busy ? null : () => onResult(true),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Mô phỏng thanh toán thành công'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('mock-fail'),
        onPressed: busy ? null : () => onResult(false),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Mô phỏng thanh toán thất bại'),
      ),
    ],
  );
}

class _StripeActions extends StatelessWidget {
  const _StripeActions({required this.onOpen, required this.onReload});
  final VoidCallback onOpen, onReload;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Thanh toán trên trang Stripe. Đơn chỉ đổi trạng thái khi Stripe báo '
        'kết quả về máy chủ; thanh toán xong hãy quay lại và tải lại trạng thái.',
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('stripe-open'),
        onPressed: onOpen,
        icon: const Icon(Icons.open_in_new),
        label: const Text('Mở Stripe Checkout'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('stripe-reload'),
        onPressed: onReload,
        icon: const Icon(Icons.refresh),
        label: const Text('Tôi đã thanh toán, tải lại trạng thái'),
      ),
    ],
  );
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.status, required this.onBack});
  final String status;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ok = PaymentPolicy.succeeded(status);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.error_outline,
          size: 56,
          color: ok ? Colors.green.shade700 : scheme.error,
        ),
        const SizedBox(height: 12),
        Text(
          PaymentPolicy.outcome(status),
          key: const Key('payment-outcome'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('payment-back'),
          onPressed: onBack,
          child: const Text('Quay lại đơn hàng'),
        ),
      ],
    );
  }
}
