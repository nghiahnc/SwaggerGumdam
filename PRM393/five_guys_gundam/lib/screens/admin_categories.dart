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
    appBar: AppBar(
      title: const HudTitle('Danh mục', tag: 'Admin // Categories'),
    ),
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
      builder: (items) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: items.length,
        itemBuilder: (_, index) {
          final category = items[index];
          return HudCard(
            onTap: () => _openDetail(category),
            accent: category.isActive ? Hud.green : Hud.muted,
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.isActive
                      ? Hud.greenSoft
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  category.isActive
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                  color: category.isActive ? Hud.green : Hud.muted,
                ),
              ),
              title: Text(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${category.slug} · ${_status(category)}'),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    ),
  );
}

// UC17: đọc lại danh mục từ `GET /categories/{id}`, không dùng dữ liệu của
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
    appBar: AppBar(
      title: const HudTitle('Chi tiết danh mục', tag: 'Admin // Category'),
    ),
    body: AsyncPanel<Category>(
      future: category,
      onRetry: _reload,
      builder: (current) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          NavyPanel(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.category_outlined, color: Hud.red),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HudLabel('Category record', color: Color(0xFFF87171)),
                      SizedBox(height: 2),
                      Text(
                        'Dữ liệu đọc trực tiếp từ máy chủ',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HudCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                _Info(label: 'Tên', value: current.name),
                _Info(label: 'Slug', value: current.slug),
                _Info(label: 'Mô tả', value: current.description ?? 'Chưa có'),
                _Info(
                  label: 'Trạng thái',
                  value: _status(current),
                  color: current.isActive ? Hud.green : Hud.redDark,
                  last: true,
                ),
              ],
            ),
          ),
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
  const _Info({
    required this.label,
    required this.value,
    this.color,
    this.last = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: Hud.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: const TextStyle(color: Hud.muted)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color ?? Hud.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

// UC18, UC19: form thêm và sửa danh mục.
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
