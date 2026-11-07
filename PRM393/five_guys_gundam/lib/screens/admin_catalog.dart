// Phụ trách: Nguyễn Hữu Tài (AgnesLorem) — CE190387
// Scaffold: nhóm, có AI hỗ trợ (nghiahnc, 60b4e16)
// UC: UC21–UC24 (FL-06)
// Mục đích: màn hình quản trị sản phẩm. Danh mục ở admin_categories.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/admin_form_dialog.dart';
import '../widgets/common.dart';

/// UC21: danh sách sản phẩm, gồm cả sản phẩm đã ngừng bán.
class AdminCatalogScreen extends StatefulWidget {
  const AdminCatalogScreen({super.key});
  @override
  State<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<AdminCatalogScreen> {
  late Future<(List<Category>, List<Product>)> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    final repo = context.read<ShopRepository>();
    future = (() async =>
        (await repo.categories(), await repo.adminProducts()))();
  });

  /// UC22, UC23: có [old] là sửa, không có là thêm.
  Future<void> editProduct(List<Category> categories, [Product? old]) async {
    final repo = context.read<ShopRepository>();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductDialog(
        categories: categories,
        old: old,
        onSave: (body) => repo.saveProduct(body, id: old?.id),
      ),
    );
    if (saved == true && mounted) reload();
  }

  /// UC24: backend chỉ xóa mềm, sản phẩm vẫn còn trong danh sách.
  Future<void> remove(Product product) async {
    if (!await confirm(context, 'Ngừng bán sản phẩm này?') || !mounted) return;
    try {
      await context.read<ShopRepository>().deleteProduct(product.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý sản phẩm')),
    body: AsyncPanel<(List<Category>, List<Product>)>(
      future: future,
      onRetry: reload,
      builder: (data) {
        final (categories, products) = data;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sản phẩm',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: categories.where((c) => c.isActive).isEmpty
                      ? null
                      : () => editProduct(categories),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm'),
                ),
              ],
            ),
            for (final product in products)
              Card(
                child: ListTile(
                  leading: ProductArt(url: product.imageUrl),
                  title: Text(product.name),
                  subtitle: Text(
                    '${product.grade} · ${product.scale} · '
                    '${product.isActive ? 'Đang bán' : 'Ngừng bán'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => action == 'edit'
                        ? editProduct(categories, product)
                        : remove(product),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Sửa')),
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

/// UC22, UC23: form thêm và sửa sản phẩm.
class ProductDialog extends StatefulWidget {
  const ProductDialog({
    required this.categories,
    required this.onSave,
    this.old,
    super.key,
  });
  final List<Category> categories;
  final Product? old;
  final Future<void> Function(Json body) onSave;
  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final data = <String, dynamic>{};
  String? categoryId;
  @override
  void initState() {
    super.initState();
    // Danh mục cũ đã ngừng thì để trống, buộc chọn lại thay vì tự đổi.
    final active = widget.categories.where((c) => c.isActive);
    final old = widget.old;
    categoryId = old == null
        ? active.firstOrNull?.id
        : active.where((c) => c.id == old.categoryId).firstOrNull?.id;
  }

  Widget input(
    String field,
    String label,
    String? initial, {
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      initialValue: initial,
      decoration: InputDecoration(labelText: label),
      validator: required ? requiredText : null,
      onSaved: (v) => data[field] = v?.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) => AdminFormDialog(
    title: widget.old == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm',
    width: 460,
    onSubmit: () => widget.onSave({...data, 'categoryId': categoryId}),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: categoryId,
          decoration: const InputDecoration(labelText: 'Danh mục'),
          items: widget.categories
              .where((c) => c.isActive)
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList(),
          onChanged: (v) => categoryId = v,
          validator: (v) => v == null ? 'Chọn danh mục' : null,
        ),
        const SizedBox(height: 10),
        input('name', 'Tên', widget.old?.name),
        input('slug', 'Slug', widget.old?.slug),
        input('grade', 'Grade (HG/MG/...)', widget.old?.grade),
        input('scale', 'Tỉ lệ (1/144/...)', widget.old?.scale),
        input('description', 'Mô tả', widget.old?.description, required: false),
        input('imageUrl', 'URL ảnh', widget.old?.imageUrl, required: false),
      ],
    ),
  );
}
