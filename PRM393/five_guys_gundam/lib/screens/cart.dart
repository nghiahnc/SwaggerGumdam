import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
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
  bool busy = false;
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

  // JWT chỉ nằm trong RAM và không có refresh token, nên 401 = cần đăng nhập lại.
  void handleError(Object error) {
    if (error is ApiException && error.statusCode == 401) {
      showError(
        context,
        'Phiên đăng nhập đã hết hạn. Hãy đăng xuất và đăng nhập lại.',
      );
    } else {
      showError(context, error);
    }
  }

  Future<void> change(CartLine line, int quantity) async {
    if (busy || quantity < 1 || quantity > 99) return;
    setState(() => busy = true);
    try {
      await context.read<ShopRepository>().updateCart(line.id, quantity);
      if (mounted) reload();
    } catch (error) {
      if (mounted) handleError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(CartLine line) async {
    if (!await confirm(context, 'Xóa ${line.productName} khỏi giỏ?') ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await context.read<ShopRepository>().deleteCart(line.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) handleError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> checkout(int subtotal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(subtotalVnd: subtotal)),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<SessionController>().isSignedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Giỏ hàng')),
      body: !signedIn
          ? _Placeholder(
              message: 'Đăng nhập để xem giỏ hàng của bạn.',
              action: FilledButton(
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
              builder: (items) {
                if (items.isEmpty) {
                  return const _Placeholder(
                    message: 'Giỏ hàng đang trống.',
                    hint: 'Chọn mô hình ở tab Cửa hàng để thêm vào giỏ.',
                  );
                }
                final subtotal = items.fold<int>(
                  0,
                  (sum, line) => sum + line.totalVnd,
                );
                final count = items.fold<int>(
                  0,
                  (sum, line) => sum + line.quantity,
                );
                return Column(
                  children: [
                    if (busy) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => reload(),
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            for (final line in items)
                              _CartLineCard(
                                line: line,
                                busy: busy,
                                onChange: (quantity) => change(line, quantity),
                                onRemove: () => remove(line),
                              ),
                          ],
                        ),
                      ),
                    ),
                    _CheckoutBar(
                      count: count,
                      subtotal: subtotal,
                      onCheckout: busy ? null : () => checkout(subtotal),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.busy,
    required this.onChange,
    required this.onRemove,
  });
  final CartLine line;
  final bool busy;
  final ValueChanged<int> onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          spacing: 8,
          children: [
            // Hàng trên: ảnh + thông tin + nút xóa.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                const ProductArt(size: 64),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        line.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'SKU ${line.sku}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      Text(
                        'Đơn giá ${money(line.unitPriceVnd)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Xóa khỏi giỏ',
                  onPressed: busy ? null : onRemove,
                  color: theme.colorScheme.error,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            // Hàng dưới trải hết chiều ngang: số lượng | thành tiền.
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  _QuantityStepper(
                    quantity: line.quantity,
                    onMinus: !busy && line.quantity > 1
                        ? () => onChange(line.quantity - 1)
                        : null,
                    onPlus: !busy && line.quantity < 99
                        ? () => onChange(line.quantity + 1)
                        : null,
                  ),
                  const Spacer(),
                  Text(
                    money(line.totalVnd),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bộ tăng/giảm số lượng dạng viên thuốc: [-] 2 [+].
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });
  final int quantity;
  final VoidCallback? onMinus, onPlus;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Giảm',
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: onMinus,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'Tăng',
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: onPlus,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

// Thanh dưới cùng: số món + tạm tính + nút Đặt hàng.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.count,
    required this.subtotal,
    required this.onCheckout,
  });
  final int count, subtotal;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tạm tính ($count sản phẩm)',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      money(subtotal),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onCheckout,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Đặt hàng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Trạng thái chưa đăng nhập / giỏ trống.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.message, this.hint, this.action});
  final String message;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: .5),
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (hint != null)
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ?action, // Chỉ thêm nút khi action khác null.
          ],
        ),
      ),
    );
  }
}
