// Tác giả: Nguyễn Hữu Tài (AgnesLorem) — CE190387, có AI hỗ trợ
// UC: UC16–UC20 (FL-06)
// Mục đích: quản trị danh mục. Màn danh sách (UC16), màn chi tiết (UC17),
// form thêm và sửa (UC18, UC19), ngừng bán (UC20).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/admin_form_dialog.dart';
import '../widgets/common.dart';

String _status(Category category) =>
    category.isActive ? 'Đang bán' : 'Ngừng bán';

/// Mở form danh mục. Có [old] là sửa, không có là thêm.
///
/// Trả về `true` khi đã lưu, để màn gọi tải lại dữ liệu.
Future<bool> _openForm(BuildContext context, {Category? old}) async {
  final repo = context.read<ShopRepository>();
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CategoryForm(
      old: old,
      onSave: (body) => repo.saveCategory(body, id: old?.id),
    ),
  );
  return saved ?? false;
}

/// UC16: danh sách mọi danh mục, gồm cả danh mục đã ngừng bán.
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  late Future<List<Category>> categories = _fetch();

  Future<List<Category>> _fetch() =>
      context.read<ShopRepository>().categories();

  void _reload() {
    setState(() {
      categories = _fetch();
    });
  }

  Future<void> _add() async {
    if (await _openForm(context) && mounted) _reload();
  }

  /// Màn chi tiết có thể sửa hoặc ngừng bán, nên quay về là tải lại.
  Future<void> _openDetail(Category category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryDetailScreen(id: category.id)),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Danh mục')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.add),
      label: const Text('Thêm danh mục'),
    ),
    body: AsyncPanel<List<Category>>(
      future: categories,
      onRetry: _reload,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Chưa có danh mục nào.',
      builder: (items) => ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final category = items[index];
          return ListTile(
            leading: Icon(
              category.isActive
                  ? Icons.check_circle_outline
                  : Icons.block_outlined,
            ),
            title: Text(category.name),
            subtitle: Text('${category.slug} · ${_status(category)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDetail(category),
          );
        },
      ),
    ),
  );
}

/// UC17: đọc lại danh mục từ `GET /categories/{id}`, không dùng dữ liệu của
/// màn danh sách. Từ đây có thể sửa (UC19) và ngừng bán (UC20).
class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({required this.id, super.key});

  final String id;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late Future<Category> category = _fetch();

  Future<Category> _fetch() =>
      context.read<ShopRepository>().category(widget.id);

  void _reload() {
    setState(() {
      category = _fetch();
    });
  }

  Future<void> _edit(Category current) async {
    if (await _openForm(context, old: current) && mounted) _reload();
  }

  /// UC20: backend chỉ xóa mềm và từ chối (409) khi còn sản phẩm đang bán.
  Future<void> _deactivate(Category current) async {
    final accepted = await confirm(
      context,
      'Ngừng bán danh mục ${current.name}?',
    );
    if (!accepted || !mounted) return;
    try {
      await context.read<ShopRepository>().deleteCategory(current.id);
      if (!mounted) return;
      showSuccess(context, 'Đã ngừng bán danh mục');
      _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết danh mục')),
    body: AsyncPanel<Category>(
      future: category,
      onRetry: _reload,
      builder: (current) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Info(label: 'Tên', value: current.name),
          _Info(label: 'Slug', value: current.slug),
          _Info(label: 'Mô tả', value: current.description ?? 'Chưa có'),
          _Info(label: 'Trạng thái', value: _status(current)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _edit(current),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Sửa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // API không có đường bật lại, nên đã ngừng thì khóa nút.
                child: FilledButton.icon(
                  onPressed: current.isActive
                      ? () => _deactivate(current)
                      : null,
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Ngừng bán'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: Theme.of(context).textTheme.labelMedium),
    subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
  );
}

/// UC18, UC19: form thêm và sửa danh mục.
class CategoryForm extends StatefulWidget {
  const CategoryForm({required this.onSave, this.old, super.key});

  final Category? old;

  /// Gọi API lưu. Body đã bỏ khoảng trắng thừa, mô tả rỗng được gửi là `null`.
  final Future<void> Function(Json body) onSave;

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  late final name = TextEditingController(text: widget.old?.name);
  late final slug = TextEditingController(text: widget.old?.slug);
  late final description = TextEditingController(text: widget.old?.description);

  @override
  void dispose() {
    name.dispose();
    slug.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _submit() {
    final note = description.text.trim();
    return widget.onSave({
      'name': name.text.trim(),
      'slug': slug.text.trim(),
      'description': note.isEmpty ? null : note,
    });
  }

  @override
  Widget build(BuildContext context) => AdminFormDialog(
    title: widget.old == null ? 'Thêm danh mục' : 'Sửa danh mục',
    onSubmit: _submit,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Tên'),
          validator: requiredText,
        ),
        TextFormField(
          controller: slug,
          decoration: const InputDecoration(labelText: 'Slug'),
          validator: requiredText,
        ),
        TextFormField(
          controller: description,
          decoration: const InputDecoration(labelText: 'Mô tả'),
        ),
      ],
    ),
  );
}
