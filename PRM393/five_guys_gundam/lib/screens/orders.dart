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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade200),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        orderStatusLabel(status),
        style: TextStyle(
          color: color.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Màn hình trống/chưa đăng nhập: icon + thông điệp + nút (nếu có).
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Icon(icon, size: 64, color: scheme.primary.withValues(alpha: .5)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ?action, // Chỉ thêm nút khi action khác null.
          ],
        ),
      ),
    );
  }
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
      appBar: AppBar(title: const Text('Đơn hàng')),
      body: !session.isSignedIn
          ? _Placeholder(
              icon: Icons.receipt_long_outlined,
              message: 'Đăng nhập để theo dõi đơn hàng của bạn.',
              action: FilledButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                  if (mounted) reload();
                },
                child: const Text('Đăng nhập để xem đơn'),
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
                  );
                }
                final shown = session.isAdmin && onlyActionable
                    ? items.where((o) => nextAdminStatus(o.status) != null)
                    : items;
                return RefreshIndicator(
                  onRefresh: () async => reload(),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
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
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            items.isEmpty
                                ? 'Không còn đơn ở trang này.'
                                : 'Không có đơn cần xử lý ở trang này.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final order in shown)
                        _OrderCard(
                          order: order,
                          onTap: () => openDetail(order),
                        ),
                      if (page > 1 || items.length >= 20)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            Text('Trang $page'),
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final first = order.items.firstOrNull?.productName ?? '';
    final more = order.items.length > 1
        ? ' và ${order.items.length - 1} sản phẩm khác'
        : '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      'Đơn ${shortOrderId(order.id)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OrderStatusChip(order.status),
                ],
              ),
              Text('$first$more', maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatDateTime(order.createdAtUtc)} · ${itemCount(order)} sản phẩm',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                  Text(
                    money(order.totalVnd),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: muted),
                ],
              ),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
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
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (busy) const LinearProgressIndicator(minHeight: 2),
                _Section(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Đơn ${shortOrderId(order.id)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OrderStatusChip(order.status),
                      ],
                    ),
                    _InfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Thanh toán',
                      value: paymentStatusLabel(order.paymentStatus),
                    ),
                    _InfoRow(
                      icon: Icons.schedule,
                      label: 'Tạo lúc',
                      value: formatDateTime(order.createdAtUtc),
                    ),
                    if (order.status == 'PendingPayment')
                      _InfoRow(
                        icon: Icons.timer_outlined,
                        label: 'Hạn thanh toán',
                        value: formatDateTime(order.expiresAtUtc),
                      ),
                    if (hint != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          spacing: 10,
                          children: [
                            Icon(Icons.info_outline, color: color.shade700),
                            Expanded(
                              child: Text(
                                hint,
                                style: TextStyle(color: color.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                _Section(
                  title: 'Sản phẩm (${itemCount(order)})',
                  children: [
                    for (final item in order.items)
                      Row(
                        spacing: 12,
                        children: [
                          const ProductArt(size: 48),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  '${item.sku}\n${money(item.unitPriceVnd)} × ${item.quantity}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(money(item.unitPriceVnd * item.quantity)),
                        ],
                      ),
                  ],
                ),
                _Section(
                  title: 'Thanh toán',
                  children: [
                    _AmountRow('Tạm tính', money(order.subtotalVnd)),
                    _AmountRow(
                      'Giảm giá',
                      order.discountVnd > 0
                          ? '-${money(order.discountVnd)}'
                          : money(0),
                      valueStyle: order.discountVnd > 0
                          ? TextStyle(color: Colors.green.shade700)
                          : null,
                    ),
                    const Divider(height: 8),
                    _AmountRow(
                      'Tổng cộng',
                      money(order.totalVnd),
                      labelStyle: theme.textTheme.titleMedium,
                      valueStyle: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    if (order.status == 'PendingPayment' && isOwner)
                      FilledButton.icon(
                        onPressed: busy ? null : () => pay(order),
                        icon: const Icon(Icons.payment),
                        label: const Text('Thanh toán'),
                      ),
                    if (canCancelOrder(order.status))
                      OutlinedButton.icon(
                        onPressed: busy ? null : cancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('Hủy đơn'),
                      ),
                    if (nextAdminStatus(order.status) case final next?
                        when isAdmin)
                      FilledButton.icon(
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
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Khối nội dung dạng thẻ trắng, có tiêu đề tùy chọn.
class _Section extends StatelessWidget {
  const _Section({required this.children, this.title});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (title != null)
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
          ...children,
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      spacing: 8,
      children: [
        Icon(icon, size: 18, color: muted),
        Text(label, style: TextStyle(color: muted)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value, {this.labelStyle, this.valueStyle});
  final String label, value;
  final TextStyle? labelStyle, valueStyle;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      Text(label, style: labelStyle),
      Expanded(
        child: Text(value, textAlign: TextAlign.end, style: valueStyle),
      ),
    ],
  );
}
