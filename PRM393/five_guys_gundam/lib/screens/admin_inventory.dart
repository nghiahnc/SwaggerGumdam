import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';

class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});
  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  String? productId;
  late Future<(List<Product>, List<Variant>)> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    final repo = context.read<ShopRepository>();
    future = (() async {
      final products = await repo.adminProducts();
      productId ??= products.firstOrNull?.id;
      final variants = productId == null
          ? <Variant>[]
          : await repo.variants(productId!);
      return (products, variants);
    })();
  });

  Future<void> edit([Variant? old]) async {
    if (productId == null) return;
    final body = await showDialog<Json>(
      context: context,
      builder: (_) => VariantDialog(productId: productId!, old: old),
    );
    if (body == null || !mounted) return;
    try {
      await context.read<ShopRepository>().saveVariant(body, id: old?.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> adjust(Variant variant) async {
    final body = await showDialog<Json>(
      context: context,
      builder: (_) => const StockDialog(),
    );
    if (body == null || !mounted) return;
    try {
      await context.read<ShopRepository>().adjustStock(
        variant.id,
        body['delta'] as int,
        body['reason'] as String,
      );
      if (mounted) {
        showSuccess(context, 'Đã cập nhật tồn kho');
        reload();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> remove(Variant variant) async {
    if (!await confirm(context, 'Ngừng bán SKU ${variant.sku}?') || !mounted) {
      return;
    }
    try {
      await context.read<ShopRepository>().deleteVariant(variant.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SKU và tồn kho')),
    body: AsyncPanel<(List<Product>, List<Variant>)>(
      future: future,
      onRetry: reload,
      builder: (data) {
        final (products, variants) = data;
        if (products.isEmpty) {
          return const Center(child: Text('Thêm sản phẩm trước khi tạo SKU.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: productId,
              decoration: const InputDecoration(labelText: 'Sản phẩm'),
              items: products
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (v) {
                productId = v;
                reload();
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: edit,
              icon: const Icon(Icons.add),
              label: const Text('Thêm SKU'),
            ),
            const SizedBox(height: 12),
            if (variants.isEmpty) const Text('Sản phẩm chưa có SKU.'),
            for (final variant in variants)
              Card(
                child: ListTile(
                  title: Text('${variant.sku} · ${variant.label}'),
                  subtitle: Text(
                    '${money(variant.priceVnd)} · '
                    'Tồn ${variant.stock} · '
                    '${variant.isActive ? 'Đang bán' : 'Ngừng bán'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'edit') edit(variant);
                      if (action == 'stock') adjust(variant);
                      if (action == 'delete') remove(variant);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Sửa giá / tên'),
                      ),
                      PopupMenuItem(
                        value: 'stock',
                        child: Text('Điều chỉnh tồn'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Ngừng bán')),
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

class VariantDialog extends StatefulWidget {
  const VariantDialog({required this.productId, this.old, super.key});
  final String productId;
  final Variant? old;
  @override
  State<VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<VariantDialog> {
  final key = GlobalKey<FormState>();
  final data = <String, dynamic>{};
  late bool active = widget.old?.isActive ?? true;
  Widget field(
    String name,
    String label,
    String? initial, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      initialValue: initial,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboard,
      validator: validator ?? requiredText,
      onSaved: (v) => data[name] = v?.trim(),
    ),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.old == null ? 'Thêm SKU' : 'Sửa SKU'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.old == null) field('sku', 'Mã SKU', null),
              field('label', 'Tên phiên bản', widget.old?.label),
              field(
                'priceVnd',
                'Giá VND',
                widget.old?.priceVnd.toString(),
                validator: positiveNumber,
                keyboard: TextInputType.number,
              ),
              if (widget.old == null)
                field(
                  'initialStock',
                  'Tồn ban đầu',
                  '0',
                  validator: (v) =>
                      int.tryParse(v ?? '') == null || int.parse(v!) < 0
                      ? 'Nhập số nguyên không âm'
                      : null,
                  keyboard: TextInputType.number,
                ),
              if (widget.old != null)
                SwitchListTile(
                  title: const Text('Đang bán'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate()) return;
          key.currentState!.save();
          data['priceVnd'] = int.parse(data['priceVnd'] as String);
          if (widget.old == null) {
            data['initialStock'] = int.parse(data['initialStock'] as String);
            data['productId'] = widget.productId;
          } else {
            data['isActive'] = active;
          }
          Navigator.pop(context, data);
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

class StockDialog extends StatefulWidget {
  const StockDialog({super.key});
  @override
  State<StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<StockDialog> {
  final key = GlobalKey<FormState>();
  int delta = 0;
  String reason = '';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Điều chỉnh tồn kho'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Chênh lệch (+ nhập / - xuất)',
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              validator: (v) =>
                  int.tryParse(v ?? '') == null || int.parse(v!) == 0
                  ? 'Nhập số nguyên khác 0'
                  : null,
              onSaved: (v) => delta = int.parse(v!),
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Lý do'),
              validator: requiredText,
              onSaved: (v) => reason = v!.trim(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate()) return;
          key.currentState!.save();
          Navigator.pop(context, {'delta': delta, 'reason': reason});
        },
        child: const Text('Cập nhật'),
      ),
    ],
  );
}
