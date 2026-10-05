import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'account.dart';
import 'checkout.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<CartLine>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<SessionController>().isSignedIn
        ? context.read<ShopRepository>().cart()
        : Future.value([]);
  });

  Future<void> change(CartLine line, int quantity) async {
    if (quantity < 1 || quantity > 99) return;
    try {
      await context.read<ShopRepository>().updateCart(line.id, quantity);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> remove(CartLine line) async {
    if (!await confirm(context, 'Xóa ${line.productName} khỏi giỏ?') ||
        !mounted) {
      return;
    }
    try {
      await context.read<ShopRepository>().deleteCart(line.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<SessionController>().isSignedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Giỏ hàng')),
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
                child: const Text('Đăng nhập để xem giỏ'),
              ),
            )
          : AsyncPanel<List<CartLine>>(
              future: future,
              onRetry: reload,
              isEmpty: (items) => items.isEmpty,
              emptyMessage: 'Giỏ hàng đang trống.',
              builder: (items) {
                final subtotal = items.fold<int>(
                  0,
                  (sum, line) => sum + line.totalVnd,
                );
                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => reload(),
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            for (final line in items)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.productName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        'SKU ${line.sku} · ${money(line.unitPriceVnd)}',
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: line.quantity > 1
                                                ? () => change(
                                                    line,
                                                    line.quantity - 1,
                                                  )
                                                : null,
                                            icon: const Icon(Icons.remove),
                                          ),
                                          Text('${line.quantity}'),
                                          IconButton(
                                            onPressed: line.quantity < 99
                                                ? () => change(
                                                    line,
                                                    line.quantity + 1,
                                                  )
                                                : null,
                                            icon: const Icon(Icons.add),
                                          ),
                                          const Spacer(),
                                          Text(money(line.totalVnd)),
                                          IconButton(
                                            onPressed: () => remove(line),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Tạm tính\n${money(subtotal)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            FilledButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CheckoutScreen(subtotalVnd: subtotal),
                                  ),
                                );
                                if (mounted) reload();
                              },
                              child: const Text('Đặt hàng'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
