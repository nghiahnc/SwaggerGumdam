import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/order_status.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'account.dart';
import 'payment.dart';

// API trả UTC; hiển thị giờ địa phương dạng dd/MM/yyyy HH:mm.
String formatDateTime(DateTime utc) {
  final t = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}

// Mã đơn rút gọn để hiển thị, ví dụ "#48A8D86D".
String shortOrderId(String id) =>
    '#${(id.length > 8 ? id.substring(0, 8) : id).toUpperCase()}';

// Tổng số món trong đơn (cộng quantity), không phải số dòng hàng.
int itemCount(ShopOrder order) =>
    order.items.fold(0, (sum, item) => sum + item.quantity);

// Màu theo trạng thái đơn; giá trị lạ dùng màu xám.
MaterialColor orderStatusColor(String status) => switch (status) {
  'PendingPayment' => Colors.orange,
  'Paid' => Colors.blue,
  'Shipped' => Colors.purple,
  'Delivered' => Colors.green,
  'PaymentFailed' => Colors.red,
  _ => Colors.blueGrey,
};

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return StatusPill(
      orderStatusLabel(status),
      color: color.shade700,
      background: color.shade50,
    );
  }
}

// Màn hình trống/chưa đăng nhập: icon + thông điệp + nút (nếu có).
class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.message,
    this.hint,
    this.action,
  });
  final IconData icon;
  final String message;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: EmptyState(
        icon: icon,
        title: message,
        message: hint,
        actions: [?action],
      ),
    ),
  );
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int page = 1;
  // Admin: chỉ xem đơn cần xử lý (Paid/Shipped) trên trang hiện tại.
  bool onlyActionable = false;
  late Future<List<ShopOrder>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<SessionController>().isSignedIn
        ? context.read<ShopRepository>().orders(page: page)
        : Future.value([]);
  });

  Future<void> openDetail(ShopOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      appBar: AppBar(
        title: const HudTitle('Đơn hàng', tag: 'System // Order log'),
      ),
      body: !session.isSignedIn
          ? _Placeholder(
              icon: Icons.receipt_long_outlined,
              message: 'Đăng nhập để theo dõi đơn hàng của bạn.',
              hint: 'Lịch sử đơn, thanh toán và vận chuyển nằm ở đây.',
              action: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                  if (mounted) reload();
                },
                icon: const Icon(Icons.login),
                label: const Text('Đăng nhập để xem đơn'),
              ),
            )
          : AsyncPanel<List<ShopOrder>>(
              future: future,
              onRetry: reload,
              builder: (items) {
                // Trang 1 rỗng = chưa có đơn; trang > 1 rỗng vẫn hiện phân trang.
                if (items.isEmpty && page == 1) {
                  return const _Placeholder(
                    icon: Icons.receipt_long_outlined,
                    message: 'Chưa có đơn hàng.',
                    hint: 'Đơn bạn tạo từ giỏ hàng sẽ xuất hiện ở đây.',
                  );
                }
                final shown = session.isAdmin && onlyActionable
                    ? items.where((o) => nextAdminStatus(o.status) != null)
                    : items;
                return RefreshIndicator(
                  color: Hud.red,
                  onRefresh: () async => reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (session.isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Tất cả'),
                                selected: !onlyActionable,
                                onSelected: (_) =>
                                    setState(() => onlyActionable = false),
                              ),
                              ChoiceChip(
                                label: const Text('Cần xử lý'),
                                selected: onlyActionable,
                                onSelected: (_) =>
                                    setState(() => onlyActionable = true),
                              ),
                            ],
                          ),
                        ),
                      if (shown.isEmpty)
                        EmptyState(
                          icon: Icons.inbox_outlined,
                          title: items.isEmpty
                              ? 'Không còn đơn ở trang này.'
                              : 'Không có đơn cần xử lý ở trang này.',
                        ),
                      for (final order in shown)
                        _OrderCard(
                          order: order,
                          onTap: () => openDetail(order),
                        ),
                      if (page > 1 || items.length >= 20)
                        HudCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: page == 1
                                    ? null
                                    : () {
                                        page--;
                                        reload();
                                      },
                                icon: const Icon(Icons.chevron_left),
                                label: const Text('Trang trước'),
                              ),
                              Expanded(
                                child: Text(
                                  'Trang $page',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: items.length < 20
                                    ? null
                                    : () {
                                        page++;
                                        reload();
                                      },
                                iconAlignment: IconAlignment.end,
                                icon: const Icon(Icons.chevron_right),
                                label: const Text('Trang sau'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final ShopOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = order.items.firstOrNull?.productName ?? '';
    final more = order.items.length > 1
        ? ' và ${order.items.length - 1} sản phẩm khác'
        : '';
    final color = orderStatusColor(order.status);
    return HudCard(
      onTap: onTap,
      accent: color.shade400,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  'Đơn ${shortOrderId(order.id)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamilyFallback: Hud.mono,
                    fontWeight: FontWeight.w800,
                    color: Hud.ink,
                  ),
                ),
              ),
              OrderStatusChip(order.status),
            ],
          ),
          Row(
            spacing: 12,
            children: [
              const ProductArt(size: 52),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      '$first$more',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${formatDateTime(order.createdAtUtc)} · ${itemCount(order)} sản phẩm',
                      style: const TextStyle(color: Hud.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 4),
          Row(
            children: [
              const HudLabel('Tổng thanh toán'),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    money(order.totalVnd),
                    style: const TextStyle(
                      color: Hud.red,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Hud.muted),
            ],
          ),
        ],
      ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({required this.orderId, super.key});
  final String orderId;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<ShopOrder> future;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<ShopRepository>().order(widget.orderId);
  });

  Future<void> cancel() async {
    if (!await confirm(context, 'Hủy đơn này và hoàn tồn kho đã giữ?') ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await context.read<ShopRepository>().cancelOrder(widget.orderId);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> advance(String status) async {
    if (!await confirm(
          context,
          'Chuyển đơn sang "${orderStatusLabel(status)}"?',
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await context.read<ShopRepository>().setOrderStatus(
        widget.orderId,
        status,
      );
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pay(ShopOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(orderId: order.id)),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: const HudTitle('Chi tiết đơn hàng', tag: 'System navigation'),
      ),
      body: AsyncPanel<ShopOrder>(
        future: future,
        onRetry: reload,
        builder: (order) {
          final hint = orderStatusHint(order.status);
          final color = orderStatusColor(order.status);
          // API chỉ cho chủ đơn tạo phiên thanh toán (admin xem đơn khách sẽ bị 404).
          // Backend cũ không trả userId thì giữ hành vi cũ.
          final isOwner =
              order.userId == null || order.userId == session.user?.id;
          final next = isAdmin ? nextAdminStatus(order.status) : null;
          final canPay = order.status == 'PendingPayment' && isOwner;
          final canCancel = canCancelOrder(order.status);
          return Column(
            children: [
              if (busy)
                const LinearProgressIndicator(minHeight: 2, color: Hud.red),
              Expanded(
                child: RefreshIndicator(
                  color: Hud.red,
                  onRefresh: () async => reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      NavyPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6,
                          children: [
                            const HudLabel('Mã đơn', color: Color(0xFFF87171)),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Đơn ${shortOrderId(order.id)}',
                                    style: const TextStyle(
                                      fontFamilyFallback: Hud.mono,
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                OrderStatusChip(order.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _InfoRow(
                              icon: Icons.payments_outlined,
                              label: 'Thanh toán',
                              value: paymentStatusLabel(order.paymentStatus),
                              dark: true,
                            ),
                            _InfoRow(
                              icon: Icons.schedule,
                              label: 'Tạo lúc',
                              value: formatDateTime(order.createdAtUtc),
                              dark: true,
                            ),
                          ],
                        ),
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: color.shade200),
                          ),
                          child: Row(
                            spacing: 10,
                            children: [
                              Icon(Icons.info_outline, color: color.shade700),
                              Expanded(
                                child: Text(
                                  hint,
                                  style: TextStyle(
                                    color: color.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (order.status == 'PendingPayment')
                        HudCard(
                          margin: const EdgeInsets.only(top: 10),
                          color: Hud.navy,
                          borderColor: Hud.navy,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Color(0xFFF87171),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Hạn thanh toán',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                formatDateTime(order.expiresAtUtc),
                                style: const TextStyle(
                                  fontFamilyFallback: Hud.mono,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SectionHeader(
                        'Trình tự vận hành',
                        tag: 'Phase log',
                      ),
                      HudCard(
                        margin: EdgeInsets.zero,
                        child: _Timeline(status: order.status),
                      ),
                      SectionHeader(
                        'Sản phẩm (${itemCount(order)})',
                        tag: 'Payload',
                      ),
                      HudCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          spacing: 12,
                          children: [
                            for (final item in order.items)
                              Row(
                                spacing: 12,
                                children: [
                                  const ProductArt(size: 52),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '${item.sku}\n${money(item.unitPriceVnd)} × ${item.quantity}',
                                          style: const TextStyle(
                                            color: Hud.muted,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    money(item.unitPriceVnd * item.quantity),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SectionHeader('Thanh toán', tag: 'Billing'),
                      HudCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            MoneyRow('Tạm tính', money(order.subtotalVnd)),
                            MoneyRow(
                              'Giảm giá',
                              order.discountVnd > 0
                                  ? '-${money(order.discountVnd)}'
                                  : money(0),
                              valueColor: order.discountVnd > 0
                                  ? Hud.green
                                  : null,
                            ),
                            const Divider(height: 16),
                            MoneyRow(
                              'Tổng cộng',
                              money(order.totalVnd),
                              valueColor: Hud.red,
                              bold: true,
                              big: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (canPay || canCancel || next != null)
                StickyBar(
                  child: Row(
                    spacing: 10,
                    children: [
                      if (canCancel)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : cancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Hud.redDark,
                              side: BorderSide(
                                color: Hud.red.withValues(alpha: .4),
                              ),
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Hủy đơn'),
                          ),
                        ),
                      if (canPay)
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: busy ? null : () => pay(order),
                            icon: const Icon(Icons.payment),
                            label: const Text('Thanh toán'),
                          ),
                        ),
                      if (next != null)
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Hud.navy,
                            ),
                            onPressed: busy ? null : () => advance(next),
                            icon: Icon(
                              next == 'Shipped'
                                  ? Icons.local_shipping_outlined
                                  : Icons.check_circle_outline,
                            ),
                            label: Text(
                              next == 'Shipped'
                                  ? 'Xác nhận đã gửi hàng'
                                  : 'Xác nhận đã giao hàng',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Bốn bước của một đơn: tạo → trả tiền → gửi → nhận. Đơn đóng giữa chừng
/// (hủy, hết hạn, thanh toán lỗi) dừng ở bước đầu và được đánh dấu đỏ.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});
  final String status;

  static const _steps = [
    ('Tạo đơn, giữ tồn kho', Icons.inventory_2_outlined),
    ('Xác nhận tiền về', Icons.payments_outlined),
    ('Bàn giao vận chuyển', Icons.local_shipping_outlined),
    ('Khách đã nhận hàng', Icons.verified_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final reached = switch (status) {
      'PendingPayment' => 0,
      'Paid' => 1,
      'Shipped' => 2,
      'Delivered' => 3,
      _ => 0,
    };
    final closed = const {
      'Cancelled',
      'Expired',
      'PaymentFailed',
    }.contains(status);
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= reached
                          ? (closed && i == 0 ? Hud.redSoft : Hud.greenSoft)
                          : const Color(0xFFF1F5F9),
                      border: Border.all(
                        color: i == reached && !closed
                            ? Hud.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      closed && i == 0
                          ? Icons.block
                          : i < reached || (i == 3 && reached == 3)
                          ? Icons.check
                          : _steps[i].$2,
                      size: 15,
                      color: i <= reached
                          ? (closed && i == 0 ? Hud.redDark : Hud.green)
                          : Hud.muted,
                    ),
                  ),
                  if (i < _steps.length - 1)
                    Container(
                      width: 2,
                      height: 22,
                      color: i < reached && !closed ? Hud.green : Hud.line,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    closed && i == 0
                        ? 'Đơn đã đóng: ${orderStatusLabel(status).toLowerCase()}'
                        : _steps[i].$1,
                    style: TextStyle(
                      fontWeight: i == reached
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: i <= reached ? Hud.ink : Hud.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.dark = false,
  });
  final IconData icon;
  final String label, value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final muted = dark ? Colors.white60 : Hud.muted;
    return Row(
      spacing: 8,
      children: [
        Icon(icon, size: 18, color: muted),
        Text(label, style: TextStyle(color: muted)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : Hud.ink,
            ),
          ),
        ),
      ],
    );
  }
}
