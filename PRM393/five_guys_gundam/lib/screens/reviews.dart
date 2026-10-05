import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'account.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({
    required this.productId,
    required this.productName,
    super.key,
  });
  final String productId, productName;
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late Future<List<Review>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<ShopRepository>().reviews(widget.productId);
  });

  Future<void> edit([Review? old]) async {
    if (!context.read<SessionController>().isSignedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (!mounted || !context.read<SessionController>().isSignedIn) return;
    }
    final body = await showDialog<Json>(
      context: context,
      builder: (_) => ReviewFormDialog(old: old),
    );
    if (body == null || !mounted) return;
    try {
      await context.read<ShopRepository>().saveReview(
        old == null ? {...body, 'productId': widget.productId} : body,
        id: old?.id,
      );
      if (mounted) {
        showSuccess(context, 'Đã lưu đánh giá');
        reload();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> remove(Review review) async {
    if (!await confirm(context, 'Xóa đánh giá này?') || !mounted) return;
    try {
      await context.read<ShopRepository>().deleteReview(review.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<SessionController>().user?.id;
    return Scaffold(
      appBar: AppBar(title: Text('Đánh giá · ${widget.productName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: edit,
        icon: const Icon(Icons.edit),
        label: const Text('Viết đánh giá'),
      ),
      body: AsyncPanel<List<Review>>(
        future: future,
        onRetry: reload,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Chưa có đánh giá cho sản phẩm này.',
        builder: (items) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Chỉ khách đã nhận hàng mới có thể viết đánh giá.'),
            ),
            for (final review in items)
              Card(
                child: ListTile(
                  title: Text(
                    '${'★' * review.rating}${'☆' * (5 - review.rating)}',
                  ),
                  subtitle: Text(review.comment),
                  trailing: review.userId == userId
                      ? PopupMenuButton<String>(
                          onSelected: (action) =>
                              action == 'edit' ? edit(review) : remove(review),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Sửa')),
                            PopupMenuItem(value: 'delete', child: Text('Xóa')),
                          ],
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReviewFormDialog extends StatefulWidget {
  const ReviewFormDialog({this.old, super.key});
  final Review? old;
  @override
  State<ReviewFormDialog> createState() => _ReviewFormDialogState();
}

class _ReviewFormDialogState extends State<ReviewFormDialog> {
  final key = GlobalKey<FormState>();
  late int rating = widget.old?.rating ?? 5;
  String comment = '';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.old == null ? 'Viết đánh giá' : 'Sửa đánh giá'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: rating,
              decoration: const InputDecoration(labelText: 'Số sao'),
              items: [
                for (var i = 1; i <= 5; i++)
                  DropdownMenuItem(value: i, child: Text('$i sao')),
              ],
              onChanged: (value) => rating = value ?? 5,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: widget.old?.comment,
              decoration: const InputDecoration(labelText: 'Nhận xét'),
              maxLines: 4,
              maxLength: 1000,
              validator: requiredText,
              onSaved: (value) => comment = value!.trim(),
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
          Navigator.pop(context, {'rating': rating, 'comment': comment});
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
