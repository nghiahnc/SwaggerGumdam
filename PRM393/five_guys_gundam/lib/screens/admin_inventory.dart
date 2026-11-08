// Phụ trách: Nguyễn Hữu Tài (AgnesLorem) — CE190387
// Scaffold: nhóm, có AI hỗ trợ (nghiahnc, 60b4e16)
// UC: UC25–UC28 (FL-07)
// Mục đích: màn hình quản trị SKU và tồn kho

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/admin_form_dialog.dart';
import '../widgets/common.dart';

/// Backend lưu tồn bằng `int` 32 bit, số lớn hơn không gửi lên được.
const maxStock = 2147483647;

/// Danh sách SKU theo sản phẩm đang chọn, kèm giá, tồn và trạng thái.
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
      // Mặc định chọn sản phẩm đang bán: sản phẩm ngừng bán không thêm SKU được.
      productId ??=
          (products.where((p) => p.isActive).firstOrNull ??
                  products.firstOrNull)
              ?.id;
      final variants = productId == null
          ? <Variant>[]
          : await repo.variants(productId!);
      return (products, variants);
    })();
  });

  /// UC25, UC26: có [old] là sửa, không có là thêm.
  Future<void> edit([Variant? old]) async {
    if (productId == null) return;
    final repo = context.read<ShopRepository>();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VariantDialog(
        productId: productId!,
        old: old,
        onSave: (body) => repo.saveVariant(body, id: old?.id),
      ),
    );
    if (saved == true && mounted) reload();
  }

  /// UC28: chỉ báo thành công sau khi API đã nhận điều chỉnh.
  Future<void> adjust(Variant variant) async {
    final repo = context.read<ShopRepository>();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockDialog(
        stock: variant.stock,
        onSave: (delta, reason) => repo.adjustStock(variant.id, delta, reason),
      ),
    );
    if (saved == true && mounted) {
      showSuccess(context, 'Đã cập nhật tồn kho');
      reload();
    }
  }

  /// UC27: backend chỉ xóa mềm, SKU vẫn còn trong danh sách.
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
    appBar: AppBar(
      title: const HudTitle('SKU và tồn kho', tag: 'Admin // Inventory'),
    ),
    body: AsyncPanel<(List<Product>, List<Variant>)>(
      future: future,
      onRetry: reload,
      builder: (data) {
        final (products, variants) = data;
        final selected = products.where((p) => p.id == productId).firstOrNull;
        if (products.isEmpty) {
          return const Center(
            child: SingleChildScrollView(
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Thêm sản phẩm trước khi tạo SKU.',
              ),
            ),
          );
        }
        final totalStock = variants.fold<int>(0, (s, v) => s + v.stock);
        final low = variants.where((v) => v.isActive && v.stock <= 3).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            HudCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HudLabel('Chọn mô hình cần quản lý'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: productId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sản phẩm',
                      prefixIcon: Icon(Icons.smart_toy_outlined),
                    ),
                    items: products
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.isActive ? p.name : '${p.name} · Ngừng bán',
                              overflow: TextOverflow.ellipsis,
                              style: p.isActive
                                  ? null
                                  : const TextStyle(color: Hud.muted),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      productId = v;
                      reload();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    spacing: 8,
                    children: [
                      StatusPill('${variants.length} SKU', color: Hud.navySoft),
                      StatusPill('Tổng tồn $totalStock', color: Hud.blue),
                      if (low > 0)
                        StatusPill('$low sắp hết', color: Hud.redDark),
                    ],
                  ),
                ],
              ),
            ),
            SectionHeader(
              'Danh sách SKU',
              trailing: FilledButton.icon(
                onPressed: selected?.isActive == true ? edit : null,
                icon: const Icon(Icons.add),
                label: const Text('Thêm SKU'),
              ),
            ),
            if (variants.isEmpty)
              const InfoBanner(
                tone: Tone.warning,
                message: 'Sản phẩm chưa có SKU.',
              ),
            for (final variant in variants)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  leading: _StockBox(variant: variant),
                  title: Text(
                    '${variant.sku} · ${variant.label}',
                    style: const TextStyle(
                      fontFamilyFallback: Hud.mono,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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

class _StockBox extends StatelessWidget {
  const _StockBox({required this.variant});
  final Variant variant;

  @override
  Widget build(BuildContext context) {
    final color = !variant.isActive
        ? Hud.muted
        : variant.stock <= 3
        ? Hud.redDark
        : Hud.green;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              '${variant.stock}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          HudLabel('Tồn', color: color, size: 8),
        ],
      ),
    );
  }
}

// UC25, UC26: form thêm và sửa SKU. Mã SKU và tồn ban đầu chỉ nhập khi thêm.
class VariantDialog extends StatefulWidget {
  const VariantDialog({
    required this.productId,
    required this.onSave,
    this.old,
    super.key,
  });
  final String productId;
  final Variant? old;
  final Future<void> Function(Json body) onSave;
  @override
  State<VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<VariantDialog> {
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

  /// Ô nhập lưu chuỗi vào [data], đổi sang số ở đây trước khi gửi API.
  Future<void> submit() {
    data['priceVnd'] = int.parse(data['priceVnd'] as String);
    if (widget.old == null) {
      data['initialStock'] = int.parse(data['initialStock'] as String);
      data['productId'] = widget.productId;
    } else {
      data['isActive'] = active;
    }
    return widget.onSave(data);
  }

  @override
  Widget build(BuildContext context) => AdminFormDialog(
    title: widget.old == null ? 'Thêm SKU' : 'Sửa SKU',
    onSubmit: submit,
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
            validator: (v) {
              final stock = int.tryParse(v ?? '');
              if (stock == null || stock < 0) {
                return 'Nhập số nguyên không âm';
              }
              return stock > maxStock ? 'Vượt giới hạn $maxStock' : null;
            },
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
  );
}

/// UC28: form điều chỉnh tồn. Số dương là nhập, số âm là xuất.
///
/// [stock] là tồn đang hiển thị: xuất quá số này thì báo ngay, khỏi gọi API.
/// API vẫn kiểm tra lại vì tồn có thể đổi sau khi màn hình tải.
class StockDialog extends StatefulWidget {
  const StockDialog({required this.onSave, this.stock, super.key});
  final Future<void> Function(int delta, String reason) onSave;
  final int? stock;
  @override
  State<StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<StockDialog> {
  int delta = 0;
  String reason = '';
  @override
  Widget build(BuildContext context) => AdminFormDialog(
    title: 'Điều chỉnh tồn kho',
    submitLabel: 'Cập nhật',
    width: 400,
    onSubmit: () => widget.onSave(delta, reason),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Chênh lệch (+ nhập / - xuất)',
          ),
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          validator: (v) {
            final delta = int.tryParse(v ?? '');
            if (delta == null || delta == 0) {
              return 'Nhập số nguyên khác 0';
            }
            if (delta.abs() > maxStock) return 'Vượt giới hạn $maxStock';
            final stock = widget.stock;
            if (stock != null && stock + delta < 0) {
              return 'Chỉ còn $stock trong kho, xuất tối đa $stock';
            }
            if (stock != null && stock + delta > maxStock) {
              return 'Tồn sau điều chỉnh vượt $maxStock';
            }
            return null;
          },
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
  );
}
