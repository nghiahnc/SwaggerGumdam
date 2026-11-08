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
    future = (() async {
      final product = await repo.product(widget.productId);
      final variants = await repo.variants(widget.productId);
      // Giữ SKU đang chọn nếu vẫn còn hàng, nếu không chọn SKU còn hàng đầu tiên.
      final current = variants
          .where((v) => v.id == selectedVariant && v.stock > 0)
          .firstOrNull;
      final variant = current ?? variants.where((v) => v.stock > 0).firstOrNull;
      selectedVariant = variant?.id;
      quantity = _clampQuantity(quantity, variant);
      return (product, variants);
    })();
  });

  static int _clampQuantity(int value, Variant? variant) {
    final max = variant == null ? 1 : maxQuantity(variant.stock);
    return value.clamp(1, max < 1 ? 1 : max);
  }

  /// Giá và tồn có thể đã đổi trong lúc xem, nên quay về là tải lại.
  Future<void> openVariant(Variant variant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VariantDetailScreen(id: variant.id)),
    );
    if (mounted) reload();
  }

  void select(Variant variant) => setState(() {
    selectedVariant = variant.id;
    quantity = _clampQuantity(quantity, variant);
  });

  Future<bool> ensureSignedIn() async {
    if (context.read<SessionController>().isSignedIn) return true;
    final goToLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cần đăng nhập'),
        content: const Text('Hãy đăng nhập để thêm sản phẩm vào giỏ hàng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
    if (goToLogin != true || !mounted) return false;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    return mounted && context.read<SessionController>().isSignedIn;
  }

  Future<void> add(List<Variant> variants) async {
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
    if (!await ensureSignedIn() || !mounted) return;
    setState(() => busy = true);
    try {
      await context.read<ShopRepository>().addToCart(variant.id, quantity);
      if (mounted) {
        showSuccess(context, 'Đã thêm $quantity × ${variant.label} vào giỏ');
      }
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
        final selected = variants
            .where((v) => v.id == selectedVariant)
            .firstOrNull;
        final max = selected == null ? 0 : maxQuantity(selected.stock);
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
                enabled: variant.stock > 0,
                title: Text('${variant.label} · ${money(variant.priceVnd)}'),
                subtitle: Text(
                  variant.stock > 0
                      ? 'SKU ${variant.sku} · Còn ${variant.stock}'
                      : 'SKU ${variant.sku} · Hết hàng',
                ),
                leading: Icon(
                  selectedVariant == variant.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                // Nút riêng, vì chạm vào dòng là chọn SKU; SKU hết hàng vẫn xem được.
                trailing: IconButton(
                  tooltip: 'Chi tiết SKU ${variant.sku}',
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => openVariant(variant),
                ),
                onTap: variant.stock > 0 ? () => select(variant) : null,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Giảm số lượng',
                  onPressed: selected != null && quantity > 1
                      ? () => setState(() => quantity--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$quantity', key: const Key('quantity')),
                IconButton(
                  tooltip: 'Tăng số lượng',
                  onPressed: selected != null && quantity < max
                      ? () => setState(() => quantity++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: busy || selected == null
                      ? null
                      : () => add(variants),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_shopping_cart),
                  label: const Text('Thêm vào giỏ'),
                ),
              ],
            ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Tạm tính ${money(selected.priceVnd * quantity)}'
                  ' · tối đa $max',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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

/// UC14: đọc lại một SKU từ `GET /variants/{id}`. Khách chỉ thấy SKU đang bán
/// của sản phẩm và danh mục đang bán; SKU khác API trả 404.
class VariantDetailScreen extends StatefulWidget {
  const VariantDetailScreen({required this.id, super.key});
  final String id;
  @override
  State<VariantDetailScreen> createState() => _VariantDetailScreenState();
}

class _VariantDetailScreenState extends State<VariantDetailScreen> {
  late Future<Variant> future;

  @override
  void initState() {
    super.initState();
    future = fetch();
  }

  Future<Variant> fetch() => context.read<ShopRepository>().variant(widget.id);

  void reload() => setState(() {
    future = fetch();
  });

  Widget info(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: Theme.of(context).textTheme.labelMedium),
    subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết SKU')),
    body: AsyncPanel<Variant>(
      future: future,
      onRetry: reload,
      builder: (v) => RefreshIndicator(
        onRefresh: () async => reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            info('Mã SKU', v.sku),
            info('Phiên bản', v.label),
            info('Giá', money(v.priceVnd)),
            info('Tồn kho', v.stock > 0 ? '${v.stock}' : 'Hết hàng'),
            info('Trạng thái', v.isActive ? 'Đang bán' : 'Ngừng bán'),
          ],
        ),
      ),
    ),
  );
}
