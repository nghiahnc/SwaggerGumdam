import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cart_policy.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'account.dart';
import 'reviews.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({required this.productId, super.key});
  final String productId;
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<(Product, List<Variant>)> future;
  String? selectedVariant;
  int quantity = 1;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    final repo = context.read<ShopRepository>();
    future = (() async => (
      await repo.product(widget.productId),
      await repo.variants(widget.productId),
    ))();
  });

  Future<void> add(List<Variant> variants) async {
    if (!context.read<SessionController>().isSignedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (!mounted || !context.read<SessionController>().isSignedIn) return;
    }
    final variant = variants.where((v) => v.id == selectedVariant).firstOrNull;
    if (variant == null) {
      showError(context, 'Hãy chọn phiên bản.');
      return;
    }
    final problem = validateQuantity(quantity, variant.stock);
    if (problem != null) {
      showError(context, problem);
      return;
    }
    setState(() => busy = true);
    try {
      await context.read<ShopRepository>().addToCart(variant.id, quantity);
      if (mounted) showSuccess(context, 'Đã thêm vào giỏ');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
    body: AsyncPanel<(Product, List<Variant>)>(
      future: future,
      onRetry: reload,
      builder: (data) {
        final (product, variants) = data;
        selectedVariant ??= variants
            .where((variant) => variant.stock > 0)
            .firstOrNull
            ?.id;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: ProductArt(url: product.imageUrl, size: 210)),
            const SizedBox(height: 20),
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${product.grade} · ${product.scale}'),
            const SizedBox(height: 12),
            Text(
              product.description?.isNotEmpty == true
                  ? product.description!
                  : 'Mô hình Gundam chính hãng.',
            ),
            const SizedBox(height: 24),
            Text(
              'Chọn phiên bản',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (variants.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sản phẩm chưa có phiên bản đang bán.'),
              ),
            for (final variant in variants)
              ListTile(
                title: Text('${variant.label} · ${money(variant.priceVnd)}'),
                subtitle: Text('SKU ${variant.sku} · Còn ${variant.stock}'),
                leading: Icon(
                  selectedVariant == variant.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: variant.stock == 0
                    ? null
                    : () => setState(() => selectedVariant = variant.id),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: quantity > 1
                      ? () => setState(() => quantity--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$quantity'),
                IconButton(
                  onPressed: quantity < 99
                      ? () => setState(() => quantity++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: busy || !variants.any((v) => v.stock > 0)
                      ? null
                      : () => add(variants),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Thêm vào giỏ'),
                ),
              ],
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Đánh giá sau mua'),
              subtitle: const Text(
                'Xem đánh giá hoặc viết sau khi đơn đã giao',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewsScreen(
                    productId: product.id,
                    productName: product.name,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
