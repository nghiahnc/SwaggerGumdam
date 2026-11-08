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
    appBar: AppBar(
      title: const HudTitle('Chi tiết sản phẩm', tag: 'Unit spec sheet'),
    ),
    body: AsyncPanel<(Product, List<Variant>)>(
      future: future,
      onRetry: reload,
      builder: (data) {
        final (product, variants) = data;
        final selected = variants
            .where((v) => v.id == selectedVariant)
            .firstOrNull;
        final max = selected == null ? 0 : maxQuantity(selected.stock);
        final prices = variants.map((v) => v.priceVnd).toList()..sort();
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _Hero(product: product),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      SpecBadge(
                        product.grade,
                        color: gradeColor(product.grade),
                      ),
                      SpecBadge(product.scale),
                      if (!product.isActive)
                        const SpecBadge('Ngừng bán', color: Hud.redDark),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Hud.ink,
                      height: 1.2,
                    ),
                  ),
                  if (prices.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      prices.first == prices.last
                          ? money(prices.first)
                          : '${money(prices.first)} – ${money(prices.last)}',
                      style: const TextStyle(
                        color: Hud.red,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  const SectionHeader('Thông số kỹ thuật', tag: 'Spec'),
                  HudCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        _SpecRow('Grade', product.grade),
                        _SpecRow('Tỷ lệ', product.scale),
                        _SpecRow('Số phiên bản', '${variants.length}'),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            product.description?.isNotEmpty == true
                                ? product.description!
                                : 'Mô hình Gundam chính hãng.',
                            style: const TextStyle(height: 1.45),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SectionHeader('Chọn phiên bản', tag: 'Variant'),
                  if (variants.isEmpty)
                    const InfoBanner(
                      tone: Tone.warning,
                      message: 'Sản phẩm chưa có phiên bản đang bán.',
                    ),
                  for (final variant in variants)
                    _VariantTile(
                      variant: variant,
                      selected: selectedVariant == variant.id,
                      onTap: variant.stock > 0 ? () => select(variant) : null,
                    ),
                  const SizedBox(height: 8),
                  HudCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewsScreen(
                          productId: product.id,
                          productName: product.name,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    child: const ListTile(
                      leading: Icon(Icons.star_rounded, color: Hud.amber),
                      title: Text(
                        'Đánh giá sau mua',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Xem đánh giá hoặc viết sau khi đơn đã giao',
                      ),
                      trailing: Icon(Icons.chevron_right),
                    ),
                  ),
                ],
              ),
            ),
            StickyBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Tạm tính ${money(selected.priceVnd * quantity)}'
                        ' · tối đa $max',
                        style: const TextStyle(
                          color: Hud.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      QtyStepper(
                        value: quantity,
                        valueKey: const Key('quantity'),
                        minusTooltip: 'Giảm số lượng',
                        plusTooltip: 'Tăng số lượng',
                        onMinus: selected != null && quantity > 1
                            ? () => setState(() => quantity--)
                            : null,
                        onPlus: selected != null && quantity < max
                            ? () => setState(() => quantity++)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy || selected == null
                              ? null
                              : () => add(variants),
                          icon: busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_shopping_cart),
                          label: const Text('Thêm vào giỏ'),
                        ),
                      ),
                    ],
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

class _Hero extends StatelessWidget {
  const _Hero({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) => NavyPanel(
    padding: const EdgeInsets.all(14),
    child: Column(
      children: [
        const Row(
          children: [
            HudLabel('Hangar // Unit view', color: Color(0xFFF87171)),
            Spacer(),
            HudLabel('Scan: OK', color: Color(0xFF4ADE80)),
          ],
        ),
        const SizedBox(height: 12),
        Center(child: ProductArt(url: product.imageUrl, size: 210)),
        const SizedBox(height: 8),
        HudLabel(product.slug, color: Colors.white54),
      ],
    ),
  );
}

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Hud.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Hud.muted)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.variant,
    required this.selected,
    required this.onTap,
  });
  final Variant variant;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inStock = variant.stock > 0;
    return HudCard(
      padding: EdgeInsets.zero,
      borderColor: selected ? Hud.red : Hud.line,
      color: selected ? const Color(0xFFFFF5F5) : Colors.white,
      child: ListTile(
        enabled: inStock,
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? Hud.red : Hud.muted,
        ),
        title: Text(
          '${variant.label} · ${money(variant.priceVnd)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          inStock
              ? 'SKU ${variant.sku} · Còn ${variant.stock}'
              : 'SKU ${variant.sku} · Hết hàng',
        ),
        trailing: StatusPill(
          inStock ? (variant.stock <= 3 ? 'Sắp hết' : 'Còn hàng') : 'Hết',
          color: inStock
              ? (variant.stock <= 3 ? const Color(0xFFB45309) : Hud.green)
              : Hud.muted,
        ),
      ),
    );
  }
}
