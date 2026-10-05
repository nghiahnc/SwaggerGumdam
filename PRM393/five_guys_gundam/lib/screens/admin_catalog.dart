import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';

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

  Future<void> editCategory([Category? old]) async {
    final body = await showDialog<Json>(
      context: context,
      builder: (_) => CategoryDialog(old: old),
    );
    if (body == null || !mounted) return;
    try {
      await context.read<ShopRepository>().saveCategory(body, id: old?.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> editProduct(List<Category> categories, [Product? old]) async {
    final body = await showDialog<Json>(
      context: context,
      builder: (_) => ProductDialog(categories: categories, old: old),
    );
    if (body == null || !mounted) return;
    try {
      await context.read<ShopRepository>().saveProduct(body, id: old?.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> remove(String kind, String id) async {
    if (!await confirm(context, 'Ngừng bán $kind này?') || !mounted) return;
    try {
      final repo = context.read<ShopRepository>();
      if (kind == 'danh mục') {
        await repo.deleteCategory(id);
      } else {
        await repo.deleteProduct(id);
      }
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catalog quản trị')),
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
                    'Danh mục',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: editCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm'),
                ),
              ],
            ),
            for (final category in categories)
              Card(
                child: ListTile(
                  title: Text(category.name),
                  subtitle: Text(
                    '${category.slug} · ${category.isActive ? 'Đang bán' : 'Ngừng bán'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => action == 'edit'
                        ? editCategory(category)
                        : remove('danh mục', category.id),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      PopupMenuItem(value: 'delete', child: Text('Ngừng bán')),
                    ],
                  ),
                ),
              ),
            const Divider(height: 32),
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
                        : remove('sản phẩm', product.id),
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

class CategoryDialog extends StatefulWidget {
  const CategoryDialog({this.old, super.key});
  final Category? old;
  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final key = GlobalKey<FormState>();
  final data = <String, dynamic>{};
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.old == null ? 'Thêm danh mục' : 'Sửa danh mục'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: widget.old?.name,
              decoration: const InputDecoration(labelText: 'Tên'),
              validator: requiredText,
              onSaved: (v) => data['name'] = v!.trim(),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: widget.old?.slug,
              decoration: const InputDecoration(labelText: 'Slug'),
              validator: requiredText,
              onSaved: (v) => data['slug'] = v!.trim(),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: widget.old?.description,
              decoration: const InputDecoration(labelText: 'Mô tả'),
              onSaved: (v) => data['description'] = v?.trim(),
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
          Navigator.pop(context, data);
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

class ProductDialog extends StatefulWidget {
  const ProductDialog({required this.categories, this.old, super.key});
  final List<Category> categories;
  final Product? old;
  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final key = GlobalKey<FormState>();
  final data = <String, dynamic>{};
  String? categoryId;
  @override
  void initState() {
    super.initState();
    categoryId =
        widget.categories
            .where((c) => c.isActive && c.id == widget.old?.categoryId)
            .firstOrNull
            ?.id ??
        widget.categories.where((c) => c.isActive).firstOrNull?.id;
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.old == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: widget.categories
                    .where((c) => c.isActive)
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) => categoryId = v,
                validator: (v) => v == null ? 'Chọn danh mục' : null,
              ),
              const SizedBox(height: 10),
              input('name', 'Tên', widget.old?.name),
              input('slug', 'Slug', widget.old?.slug),
              input('grade', 'Grade (HG/MG/...)', widget.old?.grade),
              input('scale', 'Tỉ lệ (1/144/...)', widget.old?.scale),
              input(
                'description',
                'Mô tả',
                widget.old?.description,
                required: false,
              ),
              input(
                'imageUrl',
                'URL ảnh',
                widget.old?.imageUrl,
                required: false,
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
          Navigator.pop(context, {...data, 'categoryId': categoryId});
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
