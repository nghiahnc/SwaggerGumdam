import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/cart_policy.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'account.dart';
import 'cart_item_detail.dart';
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
    if (busy || quantity < minCartQuantity || quantity > maxCartQuantity) {
      return;
    }
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

  Future<void> openDetail(CartLine line) async {
    if (busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CartItemDetailScreen(cartItemId: line.id),
      ),
    );
    // The item may have changed or been removed while its details were open.
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<SessionController>().isSignedIn;
    return Scaffold(
      appBar: AppBar(
        title: const HudTitle('Giỏ hàng', tag: 'FiveGuys // Payload'),
      ),
      body: !signedIn
          ? _Placeholder(
              icon: Icons.lock_outline,
              message: 'Đăng nhập để xem giỏ hàng của bạn.',
              hint: 'Giỏ hàng được đồng bộ theo tài khoản phi công.',
              action: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                  if (mounted) reload();
                },
                icon: const Icon(Icons.login),
                label: const Text('Đăng nhập để xem giỏ'),
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
                    _ManifestBar(lines: items.length),
                    if (busy)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: Hud.red,
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        color: Hud.red,
                        onRefresh: () async => reload(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'CHI TIẾT KIỆN HÀNG',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .3,
                                    ),
                                  ),
                                ),
                                StatusPill(
                                  '${items.length.toString().padLeft(2, '0')} mặt hàng',
                                  color: Hud.red,
                                  dot: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            for (final line in items)
                              _CartLineCard(
                                line: line,
                                busy: busy,
                                onView: () => openDetail(line),
                                onChange: (quantity) => change(line, quantity),
                                onRemove: () => remove(line),
                              ),
                            const SizedBox(height: 4),
                            const Text(
                              'Chạm vào một kiện hàng để xem chi tiết mới nhất từ máy chủ.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Hud.muted, fontSize: 12),
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

// Dải trạng thái trên cùng: "PAYLOAD MANIFEST" + số kiện.
class _ManifestBar extends StatelessWidget {
  const _ManifestBar({required this.lines});
  final int lines;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFFE1E8FD),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Hud.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: HudLabel('Payload manifest // cargo check', color: Hud.red),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 14, color: Hud.red),
              const SizedBox(width: 4),
              Text(
                '$lines KIỆN',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.busy,
    required this.onView,
    required this.onChange,
    required this.onRemove,
  });
  final CartLine line;
  final bool busy;
  final ValueChanged<int> onChange;
  final VoidCallback onView, onRemove;

  @override
  Widget build(BuildContext context) => HudCard(
    key: ValueKey('cart-item-${line.id}'),
    onTap: busy ? null : onView,
    padding: const EdgeInsets.all(12),
    child: Column(
      spacing: 10,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            const ProductArt(size: 88),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          line.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: Hud.ink,
                            height: 1.25,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          tooltip: 'Xóa khỏi giỏ',
                          padding: EdgeInsets.zero,
                          onPressed: busy ? null : onRemove,
                          color: Hud.muted,
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ),
                    ],
                  ),
                  SpecBadge('SKU: ${line.sku}'),
                  const SizedBox(height: 2),
                  Text(
                    'Đơn giá ${money(line.unitPriceVnd)}',
                    style: const TextStyle(color: Hud.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(line.totalVnd),
                  style: const TextStyle(
                    color: Hud.red,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            QtyStepper(
              value: line.quantity,
              onMinus: !busy && line.quantity > minCartQuantity
                  ? () => onChange(line.quantity - 1)
                  : null,
              onPlus: !busy && line.quantity < maxCartQuantity
                  ? () => onChange(line.quantity + 1)
                  : null,
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: Hud.blue),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Xem chi tiết kiện hàng',
                  style: TextStyle(
                    fontSize: 12,
                    color: Hud.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: Hud.blue),
            ],
          ),
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
  Widget build(BuildContext context) => StickyBar(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tạm tính ($count sản phẩm)',
                style: const TextStyle(
                  color: Hud.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(subtotal),
                  style: const TextStyle(
                    color: Hud.red,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onCheckout,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Đặt hàng'),
        ),
      ],
    ),
  );
}

// Trạng thái chưa đăng nhập / giỏ trống.
class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.message,
    this.hint,
    this.action,
    this.icon = Icons.shopping_cart_outlined,
  });
  final String message;
  final String? hint;
  final Widget? action;
  final IconData icon;

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
