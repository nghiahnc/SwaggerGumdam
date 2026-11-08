import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/error_text.dart';
import '../core/models.dart';
import '../core/order_status.dart';
import '../core/payment_policy.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'orders.dart' show shortOrderId;

/// Pays one order that is waiting for payment.
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

  /// Set once Stripe Checkout was opened in the browser: coming back to the
  /// app then reads the order again, as the Stripe text asks the customer to.
  /// Cleared when the order is no longer pending.
  bool _awaitingStripe = false;
  bool _refreshing = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _backFromStripe);
    reload();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// On web and desktop "resume" also fires on every window focus, so this
  /// refresh is quiet: the screen keeps what it shows until the new answer
  /// arrives, and no snackbar repeats (the button still gives one).
  Future<void> _backFromStripe() async {
    if (!_awaitingStripe || !mounted || busy || _refreshing) return;
    _refreshing = true;
    final shown = future;
    final load = readable(_load(context.read<ShopRepository>()));
    try {
      final view = await load;
      // A reload the customer asked for meanwhile is newer: keep it.
      if (!mounted || !identical(future, shown)) return;
      _settleStripe(view);
      setState(() {
        future = SynchronousFuture(view);
      });
    } catch (_) {
      // Keep the current view; the reload button shows the error.
    } finally {
      _refreshing = false;
    }
  }

  /// Stops reading on resume once the order itself is no longer waiting for
  /// payment. A refused session (no session in the view) is not enough: the
  /// order may still be pending and Stripe may still report back.
  void _settleStripe(_PaymentView view) {
    if (view.order.status != PaymentPolicy.pending) _awaitingStripe = false;
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
      // 409: the order changed in between (paid through Stripe, expired), or
      // (Stripe) it expires within 30 minutes. Read it again: a new status is
      // shown as the outcome; an order still pending keeps the reason. Other
      // refusals (404: not this customer's order; 5xx: payment set-up) keep
      // the order on screen with the reason, since retrying fails again.
      if (error.statusCode == 409) {
        final now = await repository.order(widget.orderId);
        if (now.status != PaymentPolicy.pending) return _PaymentView(now, null);
      }
      return _PaymentView(order, null, problem: _paymentError(error));
    }
    // With Stripe, a free order (total 0) is marked paid by the session call.
    if (session['status'] == PaymentStatus.paid) {
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
      problem = _paymentError(error);
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

  /// 5xx answers carry the API's set-up messages (Stripe keys, provider
  /// name) meant for developers; customers get one plain sentence.
  static String _paymentError(Object error) =>
      error is ApiException && (error.statusCode ?? 0) >= 500
      ? 'Thanh toán đang tạm gián đoạn, hãy thử lại sau.'
      : describeError(error);

  /// After paying on Stripe: read the order again and say so when Stripe has
  /// not reported back yet, instead of silently showing the same screen.
  Future<void> checkStripe() async {
    final messenger = ScaffoldMessenger.of(context);
    reload();
    _PaymentView view;
    try {
      view = await future;
    } catch (_) {
      return; // the error panel already explains it
    }
    _settleStripe(view);
    if (view.pending && messenger.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa nhận được kết quả từ Stripe. Nếu đã trả tiền, hãy đợi vài '
              'giây rồi tải lại.',
            ),
          ),
        );
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
    if (opened) _awaitingStripe = true;
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
        title: const HudTitle('Thanh toán', tag: 'Payment gateway'),
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
                child: LinearProgressIndicator(
                  key: Key('payment-busy'),
                  color: Hud.red,
                ),
              )
            : null,
      ),
      body: AsyncPanel<_PaymentView>(
        future: future,
        onRetry: reload,
        builder: (view) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _OrderSummary(order: view.order),
            const SizedBox(height: 16),
            if (view.problem != null)
              InfoBanner(
                tone: Tone.danger,
                tag: 'Gateway error',
                message: view.problem!,
                key: const Key('payment-problem'),
              )
            else if (!view.pending)
              _Outcome(order: view.order, onBack: () => Navigator.pop(context))
            else if (view.session!['provider'] == PaymentPolicy.mockProvider)
              _MockActions(busy: busy, onResult: completeMock)
            else if (view.session!['checkoutUrl'] is String)
              _StripeActions(
                // Stripe test-mode sessions have ids, and so URLs, with "cs_test_".
                testMode: (view.session!['checkoutUrl'] as String).contains(
                  'cs_test_',
                ),
                onOpen: () =>
                    openStripe(view.session!['checkoutUrl'] as String),
                onReload: checkStripe,
              )
            else
              const InfoBanner(
                tone: Tone.warning,
                message: 'Chưa có trang thanh toán cho đơn này. Hãy tải lại trạng thái.',
              ),
          ],
        ),
      ),
    ),
  );
}

Color _statusColor(ShopOrder order) {
  if (PaymentPolicy.succeeded(
    order.status,
    paymentStatus: order.paymentStatus,
  )) {
    return Hud.green;
  }
  if (PaymentPolicy.needsRefund(order.paymentStatus)) {
    return const Color(0xFFB45309);
  }
  if (order.status == PaymentPolicy.pending) return const Color(0xFFB45309);
  return Hud.redDark;
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final pending = order.status == PaymentPolicy.pending;
    return HudCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: HudLabel('Mã đơn cockpit')),
              StatusPill(
                PaymentPolicy.statusLabel(
                  order.status,
                  paymentStatus: order.paymentStatus,
                ),
                color: _statusColor(order),
                key: const Key('order-status'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Đơn ${shortOrderId(order.id)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Hud.ink,
            ),
          ),
          const Divider(height: 24),
          Text(
            'Tạm tính: ${money(order.subtotalVnd)}',
            style: const TextStyle(color: Hud.muted),
          ),
          if (order.discountVnd > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Giảm giá: ${money(order.discountVnd)}',
                style: const TextStyle(
                  color: Hud.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pending ? Hud.redSoft : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              pending
                  ? 'Cần thanh toán: ${money(order.totalVnd)}'
                  : 'Tổng đơn: ${money(order.totalVnd)}',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: pending ? Hud.red : Hud.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockActions extends StatelessWidget {
  const _MockActions({required this.busy, required this.onResult});
  final bool busy;
  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(Hud.radius),
      border: Border.all(color: Hud.blue.withValues(alpha: .35), width: 1.2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.science_outlined, color: Hud.blue, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Môi trường thử nghiệm',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            StatusPill('Sandbox / test mode', color: Hud.blue, dot: false),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Chế độ thử: chọn một kết quả để kiểm tra cả luồng đơn '
          'hàng. Thất bại sẽ đóng đơn, hoàn tồn kho và lượt voucher.',
          style: TextStyle(color: Hud.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('mock-success'),
          style: FilledButton.styleFrom(backgroundColor: Hud.green),
          onPressed: busy ? null : () => onResult(true),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Mô phỏng thanh toán thành công'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('mock-fail'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Hud.redDark,
            side: BorderSide(color: Hud.red.withValues(alpha: .4)),
            backgroundColor: Hud.redSoft,
          ),
          onPressed: busy ? null : () => onResult(false),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Mô phỏng thanh toán thất bại'),
        ),
      ],
    ),
  );
}

class _StripeActions extends StatelessWidget {
  const _StripeActions({
    required this.testMode,
    required this.onOpen,
    required this.onReload,
  });
  final bool testMode;
  final VoidCallback onOpen, onReload;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const InfoBanner(
        icon: Icons.lock_outline,
        tag: 'Stripe checkout',
        message:
            'Thanh toán trên trang Stripe. Đơn chỉ đổi trạng thái khi Stripe báo '
            'kết quả về máy chủ; trả xong hãy quay lại ứng dụng, màn hình tự đọc '
            'lại trạng thái đơn.',
      ),
      if (testMode)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Hud.amberSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Hud.amber.withValues(alpha: .5)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.credit_card, color: Color(0xFFB45309), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chế độ thử của Stripe: dùng thẻ 4242 4242 4242 4242, ngày hết hạn '
                  'bất kỳ trong tương lai, CVC bất kỳ. Không mất tiền thật.',
                  key: Key('stripe-test-card'),
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('stripe-open'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: onOpen,
        icon: const Icon(Icons.credit_card),
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
  const _Outcome({required this.order, required this.onBack});
  final ShopOrder order;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final status = order.status, paid = order.paymentStatus;
    final ok = PaymentPolicy.succeeded(status, paymentStatus: paid);
    final refund = PaymentPolicy.needsRefund(paid);
    final color = ok
        ? Hud.green
        : refund
        ? const Color(0xFFB45309)
        : Hud.redDark;
    return HudCard(
      margin: EdgeInsets.zero,
      borderColor: color.withValues(alpha: .35),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ok
                    ? Icons.check_circle
                    : refund
                    ? Icons.report_outlined
                    : Icons.error_outline,
                key: Key(
                  ok
                      ? 'outcome-ok'
                      : refund
                      ? 'outcome-refund'
                      : 'outcome-failed',
                ),
                size: 48,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: HudLabel(
              ok
                  ? 'Transaction complete'
                  : refund
                  ? 'Refund required'
                  : 'Transaction closed',
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            PaymentPolicy.outcome(status, paymentStatus: paid),
            key: const Key('payment-outcome'),
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('payment-back'),
            onPressed: onBack,
            child: const Text('Quay lại đơn hàng'),
          ),
        ],
      ),
    );
  }
}
