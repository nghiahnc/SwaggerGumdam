import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/reviews.dart';

import 'support/fake_shop_api.dart';

/// FL-14 minimum tests: reviewing before delivery, editing/deleting someone
/// else's review, empty form — plus write, edit and delete.
void main() {
  const listPath = '/api/v1/products/p-1/reviews';
  late FakeShopApi fake;
  late List<Map<String, dynamic>> stored;

  setUp(() {
    fake = FakeShopApi();
    stored = [
      reviewJson(id: 'r-other', userId: 'customer-2', rating: 5),
      reviewJson(
        id: 'r-mine',
        userId: 'customer-1',
        rating: 4,
        comment: 'Khớp hơi lỏng.',
      ),
    ];
    fake.onRequest('GET', listPath, (_) => FakeShopApi.json(page(stored)));
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      fake.wrap(
        const ReviewsScreen(productId: 'p-1', productName: 'RX-78-2 Gundam'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a guest reads reviews, has no actions and is offered sign-in', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('4,5 / 5 ★ · 2 đánh giá'), findsOneWidget);
    expect(find.text('Đăng nhập để viết đánh giá'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-menu-r-other')), findsNothing);
    expect(find.byKey(const ValueKey('review-menu-r-mine')), findsNothing);
  });

  testWidgets('sửa/xóa của người khác: only the own review has actions', (
    tester,
  ) async {
    fake.signIn(id: 'customer-1', role: 'Customer');
    await open(tester);
    expect(find.text('Đánh giá của bạn'), findsOneWidget);
    expect(find.text('Sửa đánh giá của bạn'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-menu-r-other')), findsNothing);
    // The own review is listed first.
    final mine = tester.getTopLeft(find.byKey(const ValueKey('review-r-mine')));
    final other = tester.getTopLeft(
      find.byKey(const ValueKey('review-r-other')),
    );
    expect(mine.dy, lessThan(other.dy));
    await tester.tap(find.byKey(const ValueKey('review-menu-r-mine')));
    await tester.pumpAndSettle();
    expect(find.text('Sửa'), findsOneWidget);
    expect(find.text('Xóa'), findsOneWidget);
  });

  testWidgets('an admin may delete another customer\'s review, not edit it', (
    tester,
  ) async {
    fake.signIn(id: 'admin-1', role: 'Admin');
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('review-menu-r-other')));
    await tester.pumpAndSettle();
    expect(find.text('Xóa'), findsOneWidget);
    expect(find.text('Sửa'), findsNothing);
  });

  testWidgets('form rỗng: saving an empty form explains both fields', (
    tester,
  ) async {
    fake.signIn(id: 'customer-3', role: 'Customer');
    await open(tester);
    await tester.tap(find.byKey(const Key('review-write')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-save')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn từ 1 đến 5 sao'), findsOneWidget);
    expect(find.text('Hãy viết vài dòng nhận xét'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('POST')), isEmpty);
  });

  testWidgets('đánh giá trước giao: the API refusal stays in the dialog', (
    tester,
  ) async {
    fake.signIn(id: 'customer-3', role: 'Customer');
    fake.refuse(
      'POST',
      '/api/v1/reviews',
      403,
      'Chỉ được đánh giá sản phẩm đã nhận.',
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('review-write')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.enterText(find.byKey(const Key('review-comment')), ' Đẹp ');
    await tester.tap(find.byKey(const Key('review-save')));
    await tester.pumpAndSettle();

    expect(find.text('Chỉ được đánh giá sản phẩm đã nhận.'), findsOneWidget);
    expect(find.byKey(const Key('review-save')), findsOneWidget);
    final sent = fake.lastBody('POST', '/api/v1/reviews');
    expect(sent, {'productId': 'p-1', 'rating': 4, 'comment': 'Đẹp'});
  });

  testWidgets('writes a review; after reloading it is marked as own', (
    tester,
  ) async {
    fake.signIn(id: 'customer-3', role: 'Customer');
    fake.onRequest('POST', '/api/v1/reviews', (_) {
      final created = reviewJson(
        id: 'r-new',
        userId: 'customer-3',
        rating: 5,
        comment: 'Tuyệt vời',
      );
      stored = [created, ...stored];
      return FakeShopApi.json(created, status: 201);
    });
    await open(tester);
    await tester.tap(find.byKey(const Key('review-write')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.enterText(
      find.byKey(const Key('review-comment')),
      'Tuyệt vời',
    );
    await tester.tap(find.byKey(const Key('review-save')));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi đánh giá'), findsOneWidget);
    expect(find.text('Đánh giá của bạn'), findsOneWidget);
    expect(find.text('Sửa đánh giá của bạn'), findsOneWidget);
    expect(fake.count('GET $listPath'), 2);
  });

  testWidgets('edits the own review with PUT, starting from its values', (
    tester,
  ) async {
    fake.signIn(id: 'customer-1', role: 'Customer');
    fake.on('PUT', '/api/v1/reviews/r-mine', reviewJson(id: 'r-mine'));
    await open(tester);
    await tester.tap(find.byKey(const Key('review-edit-own')));
    await tester.pumpAndSettle();
    expect(find.text('4 / 5 sao'), findsOneWidget);
    expect(find.text('Khớp hơi lỏng.'), findsWidgets);
    await tester.enterText(find.byKey(const Key('review-comment')), 'Đã ổn.');
    await tester.tap(find.byKey(const Key('review-save')));
    await tester.pumpAndSettle();

    expect(fake.lastBody('PUT', '/api/v1/reviews/r-mine'), {
      'rating': 4,
      'comment': 'Đã ổn.',
    });
    expect(find.text('Đã cập nhật đánh giá'), findsOneWidget);
  });

  testWidgets('deletes the own review after confirmation', (tester) async {
    fake.signIn(id: 'customer-1', role: 'Customer');
    fake.onRequest('DELETE', '/api/v1/reviews/r-mine', (_) {
      stored = stored.where((r) => r['id'] != 'r-mine').toList();
      return FakeShopApi.json(null, status: 204);
    });
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('review-menu-r-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('DELETE /api/v1/reviews/r-mine'));
    expect(find.text('Đã xóa đánh giá'), findsOneWidget);
    // The list is read again: the review is gone and writing is offered.
    expect(fake.count('GET $listPath'), 2);
    expect(find.byKey(const ValueKey('review-r-mine')), findsNothing);
    expect(find.byKey(const Key('review-write')), findsOneWidget);
  });

  testWidgets('a 409 (already reviewed elsewhere) explains and reloads', (
    tester,
  ) async {
    fake.signIn(id: 'customer-3', role: 'Customer');
    fake.refuse('POST', '/api/v1/reviews', 409, 'Bạn đã đánh giá sản phẩm.');
    await open(tester);
    await tester.tap(find.byKey(const Key('review-write')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('star-3')));
    await tester.enterText(find.byKey(const Key('review-comment')), 'Ổn');
    await tester.tap(find.byKey(const Key('review-save')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã đánh giá sản phẩm.'), findsOneWidget);
    expect(fake.count('GET $listPath'), 2);
  });

  testWidgets('a 404 on edit (review gone or not yours) reloads the list', (
    tester,
  ) async {
    fake.signIn(id: 'customer-1', role: 'Customer');
    fake.refuse(
      'PUT',
      '/api/v1/reviews/r-mine',
      404,
      'Không tìm thấy đánh giá.',
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('review-edit-own')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-save')));
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy đánh giá.'), findsOneWidget);
    expect(fake.count('GET $listPath'), 2);
  });

  testWidgets('form rỗng: a comment without stars is refused', (tester) async {
    fake.signIn(id: 'customer-3', role: 'Customer');
    await open(tester);
    await tester.tap(find.byKey(const Key('review-write')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('review-comment')), 'Đẹp');
    await tester.tap(find.byKey(const Key('review-save')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn từ 1 đến 5 sao'), findsOneWidget);
    expect(find.text('Hãy viết vài dòng nhận xét'), findsNothing);
    expect(fake.calls.where((c) => c.startsWith('POST')), isEmpty);
  });

  testWidgets('an empty list shows the product and the empty state', (
    tester,
  ) async {
    stored = [];
    fake.signIn(id: 'customer-3', role: 'Customer');
    await open(tester);
    expect(find.text('RX-78-2 Gundam'), findsOneWidget);
    expect(find.text('Chưa có điểm đánh giá'), findsOneWidget);
    expect(find.byKey(const Key('reviews-empty')), findsOneWidget);
    expect(find.byKey(const Key('review-write')), findsOneWidget);
  });

  testWidgets('a refused delete explains and reloads the list', (tester) async {
    fake.signIn(id: 'customer-1', role: 'Customer');
    fake.refuse(
      'DELETE',
      '/api/v1/reviews/r-mine',
      404,
      'Không tìm thấy đánh giá.',
    );
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('review-menu-r-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy đánh giá.'), findsOneWidget);
    expect(fake.count('GET $listPath'), 2);
  });

  testWidgets('the five stars stay on one line on a 320 px phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fake.signIn(id: 'customer-3', role: 'Customer');
    await open(tester);
    await tester.tap(find.byKey(const Key('review-write')));
    await tester.pumpAndSettle();
    final rows = {
      for (var i = 1; i <= 5; i++)
        tester.getTopLeft(find.byKey(Key('star-$i'))).dy,
    };
    expect(rows, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
