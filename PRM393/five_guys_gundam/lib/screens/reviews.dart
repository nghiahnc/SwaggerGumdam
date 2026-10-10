import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/dates.dart';
import '../core/error_text.dart';
import '../core/models.dart';
import '../core/review_policy.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'account.dart';

/// FL-14 · Reviews of one product. Everyone can read them; a signed-in
/// customer can write one review per product after an order containing it
/// was delivered, then edit or delete it. An admin can delete any review.
///
/// The API decides who may write (403 "Chỉ được đánh giá sản phẩm đã nhận."),
/// so the form shows its answer instead of guessing from the order history.
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

  /// True while a review is being deleted; locks the menus and buttons.
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final next = readable(
      context.read<ShopRepository>().reviews(widget.productId),
    );
    setState(() {
      future = next;
    });
  }

  Future<void> signIn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    // The list itself is the same; reading it again marks the new user's
    // own review and offers "Sửa" instead of "Viết".
    if (mounted) reload();
  }

  /// Sends the form; returns null on success or the message the dialog shows.
  Future<String?> save(int rating, String comment, Review? old) async {
    try {
      await context.read<ShopRepository>().saveReview(
        old == null
            ? {
                'productId': widget.productId,
                'rating': rating,
                'comment': comment,
              }
            : {'rating': rating, 'comment': comment},
        id: old?.id,
      );
      if (mounted) reload();
      return null;
    } on ApiException catch (error) {
      // 404: the review is gone (or not yours); 409: you already reviewed
      // this product from another device. Either way the list was stale.
      if (mounted && (error.statusCode == 404 || error.statusCode == 409)) {
        reload();
      }
      return describeError(error);
    } catch (error) {
      return describeError(error);
    }
  }

  Future<void> edit([Review? old]) async {
    // Taken before any await: the list is rebuilt while the dialog is open.
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      // A tap beside the dialog must not throw away what was typed.
      barrierDismissible: false,
      builder: (_) => ReviewDialog(
        old: old,
        onSubmit: (rating, comment) => save(rating, comment, old),
      ),
    );
    if (saved == true) {
      _show(
        messenger,
        old == null ? 'Đã gửi đánh giá' : 'Đã cập nhật đánh giá',
      );
    }
  }

  Future<void> remove(Review review, {required bool own}) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = context.read<ShopRepository>();
    final agreed = await confirm(
      context,
      own
          ? 'Xóa đánh giá của bạn? Không thể hoàn tác.'
          : 'Xóa đánh giá này của khách? Không thể hoàn tác.',
    );
    if (!agreed || !mounted) return;
    setState(() => busy = true);
    String message;
    try {
      await repository.deleteReview(review.id);
      message = 'Đã xóa đánh giá';
    } catch (error) {
      message = describeError(error);
    }
    if (!mounted) return;
    setState(() => busy = false);
    reload();
    _show(messenger, message);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final userId = session.user?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text('Đánh giá · ${widget.productName}'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: busy ? null : reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(key: Key('reviews-busy')),
              )
            : null,
      ),
      body: AsyncPanel<List<Review>>(
        future: future,
        onRetry: reload,
        builder: (reviews) {
          final own = ReviewPolicy.ownReview(reviews, userId);
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _Summary(reviews: reviews),
                const SizedBox(height: 8),
                _WriteAction(
                  signedIn: session.isSignedIn,
                  own: own,
                  busy: busy,
                  onSignIn: signIn,
                  onWrite: () => edit(),
                  onEditOwn: () => edit(own),
                ),
                const SizedBox(height: 8),
                if (reviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có đánh giá cho sản phẩm này.',
                      key: Key('reviews-empty'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final review in ReviewPolicy.forDisplay(reviews, userId))
                  _ReviewCard(
                    review: review,
                    own: ReviewPolicy.canEdit(review, userId),
                    canDelete: ReviewPolicy.canDelete(
                      review,
                      userId,
                      isAdmin: session.isAdmin,
                    ),
                    busy: busy,
                    onEdit: () => edit(review),
                    onDelete: () => remove(
                      review,
                      own: ReviewPolicy.canEdit(review, userId),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _show(ScaffoldMessengerState messenger, String message) {
  if (!messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _Summary extends StatelessWidget {
  const _Summary({required this.reviews});
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final average = ReviewPolicy.average(reviews);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              average == null
                  ? 'Chưa có điểm đánh giá'
                  : '$average / 5 ★ · ${reviews.length} đánh giá',
              key: const Key('reviews-summary'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Chỉ khách đã nhận hàng mới viết được đánh giá; mỗi khách một '
              'đánh giá cho mỗi sản phẩm.',
            ),
          ],
        ),
      ),
    );
  }
}

class _WriteAction extends StatelessWidget {
  const _WriteAction({
    required this.signedIn,
    required this.own,
    required this.busy,
    required this.onSignIn,
    required this.onWrite,
    required this.onEditOwn,
  });
  final bool signedIn, busy;
  final Review? own;
  final VoidCallback onSignIn, onWrite, onEditOwn;

  @override
  Widget build(BuildContext context) {
    if (!signedIn) {
      return OutlinedButton.icon(
        key: const Key('review-sign-in'),
        onPressed: busy ? null : onSignIn,
        icon: const Icon(Icons.login),
        label: const Text('Đăng nhập để viết đánh giá'),
      );
    }
    if (own != null) {
      return OutlinedButton.icon(
        key: const Key('review-edit-own'),
        onPressed: busy ? null : onEditOwn,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Sửa đánh giá của bạn'),
      );
    }
    return FilledButton.icon(
      key: const Key('review-write'),
      onPressed: busy ? null : onWrite,
      icon: const Icon(Icons.rate_review_outlined),
      label: const Text('Viết đánh giá'),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.own,
    required this.canDelete,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });
  final Review review;
  final bool own, canDelete, busy;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('review-${review.id}'),
      child: ListTile(
        title: Text(
          ReviewPolicy.stars(review.rating),
          semanticsLabel: '${review.rating} trên 5 sao',
          style: const TextStyle(color: Color(0xFFF59E0B)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (own)
              Text(
                'Đánh giá của bạn',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(review.comment),
            const SizedBox(height: 4),
            Text(
              formatLocal(review.createdAtUtc),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        // Customers only see actions on their own review; the API would
        // answer 404 for anyone else's.
        trailing: own || canDelete
            ? PopupMenuButton<String>(
                key: ValueKey('review-menu-${review.id}'),
                enabled: !busy,
                tooltip: 'Thao tác',
                onSelected: (action) =>
                    action == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => [
                  if (own)
                    const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  if (canDelete)
                    const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              )
            : null,
      ),
    );
  }
}

/// Write or edit a review. The dialog sends the request itself through
/// [onSubmit] and closes (returning true) only when it succeeds; when the API
/// refuses, for example before the order was delivered, it stays open with
/// what was typed and shows the reason.
class ReviewDialog extends StatefulWidget {
  const ReviewDialog({required this.onSubmit, this.old, super.key});
  final Review? old;

  /// Returns null on success, otherwise the message to show.
  final Future<String?> Function(int rating, String comment) onSubmit;

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final _form = GlobalKey<FormState>();
  late final _comment = TextEditingController(text: widget.old?.comment ?? '');

  /// 0 until the customer picks a number of stars.
  late int _rating = widget.old?.rating ?? 0;

  /// Errors appear after the first save, then follow the customer's changes.
  bool _checked = false;
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _checked = true);
    final fieldsOk = _form.currentState!.validate();
    if (!fieldsOk || ReviewPolicy.rating(_rating) != null) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });
    final problem = await widget.onSubmit(_rating, _comment.text.trim());
    if (!mounted) return;
    if (problem == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _serverError = problem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final ratingError = _checked ? ReviewPolicy.rating(_rating) : null;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(widget.old == null ? 'Viết đánh giá' : 'Sửa đánh giá'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _form,
            autovalidateMode: _checked
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _rating == 0 ? 'Chọn số sao' : '$_rating / 5 sao',
                  key: const Key('review-rating-label'),
                ),
                Wrap(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        key: Key('star-$i'),
                        tooltip: '$i sao',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _rating = i),
                        icon: Icon(
                          i <= _rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                  ],
                ),
                if (ratingError != null)
                  Text(
                    ratingError,
                    key: const Key('review-rating-error'),
                    style: TextStyle(color: error),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('review-comment'),
                  controller: _comment,
                  enabled: !_saving,
                  maxLines: 4,
                  maxLength: ReviewPolicy.commentMaxLength,
                  decoration: const InputDecoration(
                    labelText: 'Nhận xét',
                    hintText: 'Chất lượng nhựa, độ khớp, hướng dẫn lắp…',
                  ),
                  validator: ReviewPolicy.comment,
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _serverError!,
                    key: const Key('review-server-error'),
                    style: TextStyle(color: error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('review-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
