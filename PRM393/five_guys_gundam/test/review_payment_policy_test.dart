import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/models.dart';
import 'package:five_guys_gundam/core/payment_policy.dart';
import 'package:five_guys_gundam/core/review_policy.dart';

import 'support/fake_shop_api.dart';

void main() {
  group('review form (form rỗng)', () {
    test('comment is required and at most 1000 characters', () {
      expect(ReviewPolicy.comment(null), 'Hãy viết vài dòng nhận xét');
      expect(ReviewPolicy.comment('   '), 'Hãy viết vài dòng nhận xét');
      expect(ReviewPolicy.comment('a' * 1001), contains('1000'));
      expect(ReviewPolicy.comment('  Đẹp  '), isNull);
    });

    test('rating must be 1 to 5 stars', () {
      expect(ReviewPolicy.rating(0), isNotNull);
      expect(ReviewPolicy.rating(6), isNotNull);
      expect(ReviewPolicy.rating(null), isNotNull);
      expect(ReviewPolicy.rating(3), isNull);
    });
  });

  group('review list', () {
    final mine = Review.fromJson(reviewJson(id: 'a', userId: 'me', rating: 4));
    final other = Review.fromJson(
      reviewJson(id: 'b', userId: 'someone', rating: 5),
    );

    test('stars and average', () {
      expect(ReviewPolicy.stars(4), '★★★★☆');
      expect(ReviewPolicy.average([mine, other]), '4,5');
      expect(ReviewPolicy.average([]), isNull);
    });

    test('own review is listed first', () {
      expect(ReviewPolicy.forDisplay([other, mine], 'me'), [mine, other]);
      expect(ReviewPolicy.forDisplay([other, mine], null), [other, mine]);
      expect(ReviewPolicy.ownReview([other, mine], 'me'), mine);
      expect(ReviewPolicy.ownReview([other, mine], null), isNull);
    });

    test(
      'sửa/xóa của người khác: only the author edits; admins may delete',
      () {
        expect(ReviewPolicy.canEdit(mine, 'me'), isTrue);
        expect(ReviewPolicy.canEdit(other, 'me'), isFalse);
        expect(ReviewPolicy.canEdit(other, null), isFalse);
        expect(ReviewPolicy.canDelete(other, 'me', isAdmin: false), isFalse);
        expect(ReviewPolicy.canDelete(other, 'admin', isAdmin: true), isTrue);
        expect(ReviewPolicy.canEdit(other, 'admin'), isFalse);
      },
    );
  });

  group('payment outcome', () {
    test('order states have Vietnamese labels', () {
      expect(PaymentPolicy.orderStatus('PendingPayment'), 'Chờ thanh toán');
      expect(PaymentPolicy.orderStatus('Paid'), 'Đã thanh toán');
      expect(PaymentPolicy.orderStatus('PaymentFailed'), 'Thanh toán thất bại');
      expect(PaymentPolicy.orderStatus('Unknown'), 'Unknown');
    });

    test('both mock results are explained', () {
      expect(PaymentPolicy.succeeded('Paid'), isTrue);
      expect(
        PaymentPolicy.outcome('Paid'),
        startsWith('Thanh toán thành công'),
      );
      expect(PaymentPolicy.succeeded('PaymentFailed'), isFalse);
      expect(
        PaymentPolicy.outcome('PaymentFailed'),
        contains('tồn kho và lượt voucher'),
      );
    });
  });
}
