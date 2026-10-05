import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'account.dart';
import 'payment.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int page = 1;
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

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<SessionController>().isSignedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng')),
      body: !signedIn
          ? Center(
              child: FilledButton(
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
              isEmpty: (items) => items.isEmpty,
              emptyMessage: 'Chưa có đơn hàng.',
              builder: (items) => RefreshIndicator(
                onRefresh: () async => reload(),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final order in items)
                      Card(
                        child: ListTile(
                          title: Text(
                            'Đơn ${order.id.substring(0, 8)} · ${money(order.totalVnd)}',
                          ),
                          subtitle: Text(
                            '${order.status} · ${order.items.length} sản phẩm',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderDetailScreen(orderId: order.id),
                              ),
                            );
                            if (mounted) reload();
                          },
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: page == 1
                              ? null
                              : () {
                                  page--;
                                  reload();
                                },
                          child: const Text('Trang trước'),
                        ),
                        Text('Trang $page'),
                        TextButton(
                          onPressed: items.length < 20
                              ? null
                              : () {
                                  page++;
                                  reload();
                                },
                          child: const Text('Trang sau'),
                        ),
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
    try {
      await context.read<ShopRepository>().cancelOrder(widget.orderId);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> advance(String status) async {
    if (!await confirm(context, 'Chuyển đơn sang $status?') || !mounted) return;
    try {
      await context.read<ShopRepository>().setOrderStatus(
        widget.orderId,
        status,
      );
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<SessionController>().isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
      body: AsyncPanel<ShopOrder>(
        future: future,
        onRetry: reload,
        builder: (order) => RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Đơn ${order.id.substring(0, 8)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('Trạng thái: ${order.status}'),
              Text('Thanh toán: ${order.paymentStatus}'),
              Text('Tạo lúc: ${order.createdAtUtc.toLocal()}'),
              if (order.status == 'PendingPayment')
                Text('Hết hạn: ${order.expiresAtUtc.toLocal()}'),
              const Divider(height: 28),
              for (final item in order.items)
                ListTile(
                  title: Text(item.productName),
                  subtitle: Text('${item.sku} · x${item.quantity}'),
                  trailing: Text(money(item.unitPriceVnd * item.quantity)),
                ),
              const Divider(height: 28),
              Text('Tạm tính: ${money(order.subtotalVnd)}'),
              Text('Giảm giá: ${money(order.discountVnd)}'),
              Text(
                'Tổng: ${money(order.totalVnd)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              if (order.status == 'PendingPayment') ...[
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(orderId: order.id),
                      ),
                    );
                    if (mounted) reload();
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Thanh toán'),
                ),
                OutlinedButton(onPressed: cancel, child: const Text('Hủy đơn')),
              ],
              if (isAdmin && order.status == 'Paid')
                FilledButton(
                  onPressed: () => advance('Shipped'),
                  child: const Text('Xác nhận đã gửi hàng'),
                ),
              if (isAdmin && order.status == 'Shipped')
                FilledButton(
                  onPressed: () => advance('Delivered'),
                  child: const Text('Xác nhận đã giao hàng'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
