import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/error_text.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';

/// Reads a cart item by ID instead of reusing the cart list's older values.
/// Ownership and missing-item checks remain with the authenticated API.
class CartItemDetailScreen extends StatefulWidget {
  const CartItemDetailScreen({required this.cartItemId, super.key});
  final String cartItemId;

  @override
  State<CartItemDetailScreen> createState() => _CartItemDetailScreenState();
}

class _CartItemDetailScreenState extends State<CartItemDetailScreen> {
  Future<CartLine>? future;
  String? userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUserId = context.watch<SessionController>().user?.id;
    if (currentUserId != userId) {
      userId = currentUserId;
      // Switching accounts must discard the previous account's item data.
      future = currentUserId == null ? null : readItem();
    }
  }

  Future<CartLine> readItem() =>
      readable(context.read<ShopRepository>().cartItem(widget.cartItemId));

  void reload() {
    if (!context.read<SessionController>().isSignedIn) return;
    final next = readItem();
    setState(() {
      future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<SessionController>().isSignedIn;
    final current = future;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết món trong giỏ'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'Tải lại',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: !signedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Đăng nhập để xem món trong giỏ hàng.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : current == null
          ? const Center(child: CircularProgressIndicator())
          : AsyncPanel<CartLine>(
              future: current,
              onRetry: reload,
              builder: (line) => ListView(
                key: const Key('cart-item-detail'),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    line.productName,
                    key: const Key('cart-item-name'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _DetailValue(
                    label: 'SKU',
                    value: line.sku,
                    valueKey: const Key('cart-item-sku'),
                  ),
                  _DetailValue(
                    label: 'Đơn giá',
                    value: money(line.unitPriceVnd),
                    valueKey: const Key('cart-item-unit-price'),
                  ),
                  _DetailValue(
                    label: 'Số lượng',
                    value: '${line.quantity}',
                    valueKey: const Key('cart-item-quantity'),
                  ),
                  _DetailValue(
                    label: 'Thành tiền',
                    value: money(line.totalVnd),
                    valueKey: const Key('cart-item-total'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({
    required this.label,
    required this.value,
    required this.valueKey,
  });
  final String label, value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value, key: valueKey),
      ],
    ),
  );
}
