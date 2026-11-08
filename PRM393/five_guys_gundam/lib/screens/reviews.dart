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

/// Reviews of one product. Everyone can read them; a signed-in
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

  Future<void> openDetail(Review review) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewDetailScreen(
          reviewId: review.id,
          productName: widget.productName,
        ),
      ),
    );
    // The detail read may have found a newer version or a deleted review.
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
        title: const HudTitle('Đánh giá', tag: 'Pilot reports'),
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
                child: LinearProgressIndicator(
                  key: Key('reviews-busy'),
                  color: Hud.red,
                ),
              )
            : null,
      ),
      body: AsyncPanel<List<Review>>(
        future: future,
        onRetry: reload,
        builder: (reviews) {
          final own = ReviewPolicy.ownReview(reviews, userId);
          return RefreshIndicator(
            color: Hud.red,
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _Summary(productName: widget.productName, reviews: reviews),
                const SizedBox(height: 12),
                _WriteAction(
                  signedIn: session.isSignedIn,
                  isAdmin: session.isAdmin,
                  own: own,
                  busy: busy,
                  onSignIn: signIn,
                  onWrite: () => edit(),
                  onEditOwn: () => edit(own),
                ),
                SectionHeader(
                  'Nhận xét từ khách',
                  tag: '${reviews.length} báo cáo',
                ),
                if (reviews.isEmpty)
                  const EmptyState(
                    icon: Icons.rate_review_outlined,
                    title: 'Chưa có đánh giá cho sản phẩm này.',
                    message:
                        'Hãy là người đầu tiên chia sẻ cảm nhận sau khi '
                        'nhận hàng.',
                    key: Key('reviews-empty'),
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
                    onOpen: () => openDetail(review),
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

/// Reads one review from the API so a detail view never relies on a stale
/// item from the product's review list. Guests can read this screen too.
class ReviewDetailScreen extends StatefulWidget {
  const ReviewDetailScreen({
    required this.reviewId,
    required this.productName,
    super.key,
  });
  final String reviewId, productName;

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  late Future<Review> future;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final next = readable(
      context.read<ShopRepository>().review(widget.reviewId),
    );
    setState(() {
      future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<SessionController>().user?.id;
    return Scaffold(
      appBar: AppBar(
        title: const HudTitle('Chi tiết đánh giá', tag: 'Pilot report'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncPanel<Review>(
        future: future,
        onRetry: reload,
        builder: (review) {
          final own = ReviewPolicy.canEdit(review, userId);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              NavyPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HudLabel('Mô hình', color: Color(0xFFF87171)),
                    const SizedBox(height: 4),
                    Text(
                      widget.productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              HudCard(
                margin: EdgeInsets.zero,
                borderColor: own ? Hud.red : Hud.line,
                accent: own ? Hud.red : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ReviewPolicy.stars(review.rating),
                            semanticsLabel: '${review.rating} trên 5 sao',
                            style: const TextStyle(
                              color: Hud.amber,
                              fontSize: 26,
                            ),
                          ),
                        ),
                        StatusPill(
                          '${review.rating} / 5 sao',
                          color: const Color(0xFFB45309),
                          background: Hud.amberSoft,
                          dot: false,
                        ),
                      ],
                    ),
                    if (own) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Đánh giá của bạn',
                        style: TextStyle(
                          color: Hud.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    Text(
                      review.comment,
                      key: const Key('review-detail-comment'),
                      style: const TextStyle(height: 1.5, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Hud.muted),
                        const SizedBox(width: 6),
                        Text(
                          'Ngày đánh giá: ${formatLocal(review.createdAtUtc)}',
                          style: const TextStyle(
                            color: Hud.muted,
                            fontSize: 12.5,
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
}

void _show(ScaffoldMessengerState messenger, String message) {
  if (!messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _Summary extends StatelessWidget {
  const _Summary({required this.productName, required this.reviews});
  final String productName;
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final average = ReviewPolicy.average(reviews);
    final counts = List.filled(6, 0);
    for (final r in reviews) {
      if (r.rating >= 1 && r.rating <= 5) counts[r.rating]++;
    }
    final total = reviews.isEmpty ? 1 : reviews.length;
    return HudCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Here rather than in the app bar, where a long kit name is cut.
          Text(
            productName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Hud.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 92,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Hud.amberSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      average ?? '–',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Hud.ink,
                      ),
                    ),
                    const Icon(Icons.star_rounded, color: Hud.amber),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    for (var star = 5; star >= 1; star--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              child: Text(
                                '$star',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: counts[star] / total,
                                  minHeight: 6,
                                  color: Hud.amber,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 20,
                              child: Text(
                                '${counts[star]}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Hud.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            average == null
                ? 'Chưa có điểm đánh giá'
                : '$average / 5 ★ · ${reviews.length} đánh giá',
            key: const Key('reviews-summary'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chỉ khách đã nhận hàng mới viết được đánh giá; mỗi khách một '
            'đánh giá cho mỗi sản phẩm.',
            style: TextStyle(color: Hud.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _WriteAction extends StatelessWidget {
  const _WriteAction({
    required this.signedIn,
    required this.isAdmin,
    required this.own,
    required this.busy,
    required this.onSignIn,
    required this.onWrite,
    required this.onEditOwn,
  });
  final bool signedIn, isAdmin, busy;
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
    // The API would accept a review from an admin who delivered an order to
    // themself, which would read like a real buyer's; the shop only moderates.
    if (isAdmin) {
      return const InfoBanner(
        tag: 'Admin mode',
        message:
            'Tài khoản quản trị chỉ xóa được đánh giá của khách, không viết '
            'đánh giá.',
        key: Key('review-admin-note'),
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
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final Review review;
  final bool own, canDelete, busy;
  final VoidCallback onOpen, onEdit, onDelete;

  @override
  Widget build(BuildContext context) => HudCard(
    key: ValueKey('review-${review.id}'),
    borderColor: own ? Hud.red : Hud.line,
    accent: own ? Hud.red : null,
    onTap: busy ? null : onOpen,
    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: own ? Hud.redSoft : const Color(0xFFF1F5F9),
          child: Icon(
            own ? Icons.person : Icons.person_outline,
            size: 20,
            color: own ? Hud.red : Hud.muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (own)
                const Text(
                  'Đánh giá của bạn',
                  style: TextStyle(color: Hud.red, fontWeight: FontWeight.w800),
                ),
              Text(
                ReviewPolicy.stars(review.rating),
                semanticsLabel: '${review.rating} trên 5 sao',
                style: const TextStyle(color: Hud.amber, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(review.comment, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 6),
              HudLabel(formatLocal(review.createdAtUtc), size: 9),
            ],
          ),
        ),
        // Customers only see actions on their own review; the API would
        // answer 404 for anyone else's.
        if (own || canDelete)
          PopupMenuButton<String>(
            key: ValueKey('review-menu-${review.id}'),
            enabled: !busy,
            tooltip: 'Thao tác',
            onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => [
              if (own) const PopupMenuItem(value: 'edit', child: Text('Sửa')),
              if (canDelete)
                const PopupMenuItem(value: 'delete', child: Text('Xóa')),
            ],
          ),
      ],
    ),
  );
}

// Write or edit a review. The dialog sends the request itself through
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
        // Narrow side margins keep the five stars on one line on phones.
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                  // Count like the validator and the API (UTF-16 units), so
                  // the counter never says "600/1000" next to "tối đa 1000".
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => Text(
                        '${_comment.text.length}/${ReviewPolicy.commentMaxLength}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  decoration: const InputDecoration(
                    labelText: 'Nhận xét',
                    hintText: 'Chất lượng nhựa, độ khớp, hướng dẫn lắp…',
                    errorMaxLines: 3,
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
