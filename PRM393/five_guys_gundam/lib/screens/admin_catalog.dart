// Phụ trách: Nguyễn Hữu Tài (AgnesLorem) — CE190387
// Scaffold: nhóm, có AI hỗ trợ (nghiahnc, 60b4e16)
// UC: UC21–UC24 (FL-06)
// Mục đích: màn hình quản trị sản phẩm. Danh mục ở admin_categories.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/admin_form_dialog.dart';
import '../widgets/common.dart';

/// UC21: danh sách sản phẩm, gồm cả sản phẩm đã ngừng bán.
class AdminCatalogScreen extends StatefulWidget {
  const AdminCatalogScreen({this.pickImage = pickImageFromDevice, super.key});

  /// Hộp chọn ảnh; test thay bằng hàm trả ảnh có sẵn.
  final Future<PickedImage?> Function() pickImage;
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
        onUpload: repo.uploadProductImage,
        pickImage: widget.pickImage,
      ),
    );
    if (saved == true && mounted) reload();
  }

  /// UC24: backend chỉ xóa mềm, sản phẩm vẫn còn trong danh sách.
  Future<void> remove(Product product) async {
    if (!await confirm(context, 'Ngừng bán sản phẩm ${product.name}?') ||
        !mounted) {
      return;
    }
    try {
      await context.read<ShopRepository>().deleteProduct(product.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const HudTitle('Quản lý sản phẩm', tag: 'Admin // Catalog'),
    ),
    body: AsyncPanel<(List<Category>, List<Product>)>(
      future: future,
      onRetry: reload,
      builder: (data) {
        final (categories, products) = data;
        final active = products.where((p) => p.isActive).length;
        // Lúc tải lại, AsyncPanel thay danh sách bằng vòng xoay. Khóa này giữ
        // vị trí cuộn trong PageStorage, nên sửa xong không nhảy về đầu.
        return ListView(
          key: const PageStorageKey('admin-products'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              spacing: 10,
              children: [
                _Stat('Tổng mô hình', '${products.length}', Hud.blue),
                _Stat('Mở bán', '$active', Hud.green),
                _Stat('Danh mục', '${categories.length}', Hud.purple),
              ],
            ),
            SectionHeader(
              'Sản phẩm',
              trailing: FilledButton.icon(
                onPressed: categories.where((c) => c.isActive).isEmpty
                    ? null
                    : () => editProduct(categories),
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
              ),
            ),
            for (final product in products)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  leading: ProductArt(url: product.imageUrl, size: 52),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: HudCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HudLabel(label, color: color, size: 9),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

/// Ảnh admin chọn từ máy: tên file và nội dung.
typedef PickedImage = ({String name, List<int> bytes});

/// Mở hộp chọn ảnh của hệ điều hành. Trên web không có đường dẫn file nên
/// đọc thẳng nội dung.
Future<PickedImage?> pickImageFromDevice() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  return (name: file.name, bytes: await file.xFile.readAsBytes());
}

/// Giới hạn giống API, báo sớm khỏi phải gửi file lớn lên rồi mới bị từ chối.
const maxImageBytes = 5 * 1024 * 1024;

// UC22, UC23: form thêm và sửa sản phẩm.
class ProductDialog extends StatefulWidget {
  const ProductDialog({
    required this.categories,
    required this.onSave,
    required this.onUpload,
    this.old,
    this.pickImage = pickImageFromDevice,
    super.key,
  });
  final List<Category> categories;
  final Product? old;
  final Future<void> Function(Json body) onSave;

  /// Tải ảnh lên, trả về URL để điền vào ô URL ảnh.
  final Future<String> Function(String name, List<int> bytes) onUpload;
  final Future<PickedImage?> Function() pickImage;
  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final data = <String, dynamic>{};
  late final imageUrl = TextEditingController(text: widget.old?.imageUrl);
  String? categoryId;
  bool uploading = false;
  String? uploadError;

  @override
  void dispose() {
    imageUrl.dispose();
    super.dispose();
  }

  Future<void> chooseImage() async {
    setState(() => uploadError = null);
    final PickedImage? picked;
    try {
      picked = await widget.pickImage();
    } catch (_) {
      if (mounted) setState(() => uploadError = 'Không mở được ảnh.');
      return;
    }
    if (picked == null || !mounted) return;
    if (picked.bytes.length > maxImageBytes) {
      setState(() => uploadError = 'Ảnh lớn hơn 5 MB.');
      return;
    }
    setState(() => uploading = true);
    try {
      final url = await widget.onUpload(picked.name, picked.bytes);
      if (mounted) imageUrl.text = url;
    } catch (error) {
      if (mounted) uploadError = error.toString();
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

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

  /// Ảnh xem trước, nút chọn ảnh từ máy, và ô URL để dán link nếu muốn.
  Widget imageField(BuildContext context) {
    final error = uploadError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 12,
          children: [
            ListenableBuilder(
              listenable: imageUrl,
              builder: (_, _) => ProductArt(
                key: const Key('product-image-preview'),
                url: imageUrl.text.trim(),
                size: 72,
              ),
            ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uploading ? null : chooseImage,
                icon: uploading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined),
                label: Text(uploading ? 'Đang tải ảnh...' : 'Chọn ảnh từ máy'),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 10),
        TextFormField(
          controller: imageUrl,
          decoration: const InputDecoration(
            labelText: 'URL ảnh',
            helperText: 'JPG, PNG hoặc WebP, tối đa 5 MB',
          ),
          onSaved: (v) => data['imageUrl'] = v?.trim(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AdminFormDialog(
    title: widget.old == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm',
    width: 460,
    busy: uploading,
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
        imageField(context),
      ],
    ),
  );
}
