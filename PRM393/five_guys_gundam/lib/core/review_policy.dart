import 'models.dart';

/// Rules for writing a review (FL-14) and for who may change one.
///
/// The API is the authority (PromotionService.AddReview/UpdateReview/
/// DeleteReview): one review per customer per product, only after an order
/// with that product was delivered, edits by the author only, deletes by the
/// author or an admin. These rules decide what the screen offers.
abstract final class ReviewPolicy {
  /// `[MaxLength(1000)]` on ReviewRequest.Comment.
  static const commentMaxLength = 1000;

  static String? comment(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Hãy viết vài dòng nhận xét';
    if (value.length > commentMaxLength) {
      return 'Nhận xét tối đa $commentMaxLength ký tự';
    }
    return null;
  }

  static String? rating(int? value) =>
      value == null || value < 1 || value > 5 ? 'Chọn từ 1 đến 5 sao' : null;

  static String stars(int rating) =>
      '${'★' * rating.clamp(0, 5)}${'☆' * (5 - rating.clamp(0, 5))}';

  /// Average rating rounded to one decimal, e.g. "4,5"; null when empty.
  static String? average(List<Review> reviews) {
    if (reviews.isEmpty) return null;
    final sum = reviews.fold<int>(0, (total, r) => total + r.rating);
    return (sum / reviews.length).toStringAsFixed(1).replaceAll('.', ',');
  }

  static Review? ownReview(List<Review> reviews, String? userId) =>
      userId == null
      ? null
      : reviews.where((r) => r.userId == userId).firstOrNull;

  /// The signed-in customer's own review first, the rest newest first (the
  /// order the API already returns).
  static List<Review> forDisplay(List<Review> reviews, String? userId) => [
    ...reviews.where((r) => userId != null && r.userId == userId),
    ...reviews.where((r) => userId == null || r.userId != userId),
  ];

  static bool canEdit(Review review, String? userId) =>
      userId != null && review.userId == userId;

  static bool canDelete(
    Review review,
    String? userId, {
    required bool isAdmin,
  }) => isAdmin || canEdit(review, userId);
}
