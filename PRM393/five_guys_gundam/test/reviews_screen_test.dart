import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/reviews.dart';
import 'package:five_guys_gundam/core/dates.dart';

import 'support/fake_shop_api.dart';

/// Reviewing before delivery, editing/deleting someone else's review, the
/// empty form, and the write, edit and delete flows.
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

  testWidgets('a guest opens the latest review from its detail endpoint', (
    tester,
  ) async {
    final created = DateTime.utc(2026, 10, 7, 4, 30);
    fake.on(
      'GET',
      '/api/v1/reviews/r-other',
      reviewJson(
        id: 'r-other',
        rating: 3,
        comment: 'Nhận xét vừa cập nhật.',
        createdAtUtc: created,
      ),
    );
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('review-r-other')));
    await tester.pumpAndSettle();

    expect(fake.count('GET /api/v1/reviews/r-other'), 1);
    expect(find.text('Chi tiết đánh giá'), findsOneWidget);
    expect(find.text('RX-78-2 Gundam'), findsOneWidget);
    expect(find.text('3 / 5 sao'), findsOneWidget);
    expect(find.text('Nhận xét vừa cập nhật.'), findsOneWidget);
    expect(find.text('Ngày đánh giá: ${formatLocal(created)}'), findsOneWidget);
    expect(find.text('Nhựa đẹp, khớp chắc.'), findsNothing);
    expect(find.byType(ReviewDialog), findsNothing);
    expect(fake.calls.where((c) => !c.startsWith('GET ')), isEmpty);
  });

  testWidgets('a missing review shows the API error and can be retried', (
    tester,
  ) async {
    fake.refuse(
      'GET',
      '/api/v1/reviews/r-other',
      404,
      'Không tìm thấy đánh giá.',
    );
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('review-r-other')));
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy đánh giá.'), findsOneWidget);
    expect(find.byKey(const Key('review-detail-comment')), findsNothing);
    fake.on(
      'GET',
      '/api/v1/reviews/r-other',
      reviewJson(id: 'r-other', comment: 'Đã tải lại.'),
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(fake.count('GET /api/v1/reviews/r-other'), 2);
    expect(find.text('Đã tải lại.'), findsOneWidget);
    expect(find.text('Không tìm thấy đánh giá.'), findsNothing);
  });

  testWidgets('refreshing a detail reads again; returning reloads the list', (
    tester,
  ) async {
    fake.signIn(id: 'customer-1', role: 'Customer');
    fake.on(
      'GET',
      '/api/v1/reviews/r-mine',
      reviewJson(id: 'r-mine', userId: 'customer-1'),
    );
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('review-r-mine')));
    await tester.pumpAndSettle();
    expect(find.text('Đánh giá của bạn'), findsOneWidget);

    fake.on(
      'GET',
      '/api/v1/reviews/r-mine',
      reviewJson(
        id: 'r-mine',
        userId: 'customer-1',
        comment: 'Đánh giá sau khi lắp xong.',
      ),
    );
    await tester.tap(find.byTooltip('Tải lại'));
    await tester.pumpAndSettle();
    expect(fake.count('GET /api/v1/reviews/r-mine'), 2);
    expect(find.text('Đánh giá sau khi lắp xong.'), findsOneWidget);

    stored = stored.where((r) => r['id'] != 'r-mine').toList();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fake.count('GET $listPath'), 2);
    expect(find.byKey(const ValueKey('review-r-mine')), findsNothing);
    expect(find.byKey(const Key('review-write')), findsOneWidget);
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

  testWidgets('an admin is not offered to write a review', (tester) async {
    fake.signIn(id: 'admin-1', role: 'Admin');
    await open(tester);
    expect(find.byKey(const Key('review-admin-note')), findsOneWidget);
    expect(find.byKey(const Key('review-write')), findsNothing);
  });

  testWidgets('an admin who already has a review can still edit it', (
    tester,
  ) async {
    stored = [...stored, reviewJson(id: 'r-admin', userId: 'admin-1')];
    fake.signIn(id: 'admin-1', role: 'Admin');
    await open(tester);
    expect(find.byKey(const Key('review-edit-own')), findsOneWidget);
    expect(find.byKey(const Key('review-admin-note')), findsNothing);
  });

  testWidgets('the own review is found beyond the newest 100', (tester) async {
    fake.signIn(id: 'customer-1', role: 'Customer');
    final all = [
      for (var i = 0; i < 100; i++)
        reviewJson(id: 'r-$i', userId: 'buyer-$i', rating: 4),
      reviewJson(id: 'r-mine', userId: 'customer-1', rating: 2),
    ];
    fake.onRequest('GET', listPath, (request) {
      final pageNumber = int.parse(request.url.queryParameters['page']!);
      return FakeShopApi.json({
        'items': all.skip((pageNumber - 1) * 100).take(100).toList(),
        'pageNumber': pageNumber,
        'pageSize': 100,
        'totalCount': all.length,
      });
    });
    await open(tester);
    expect(fake.count('GET $listPath'), 2);
    expect(find.text('Sửa đánh giá của bạn'), findsOneWidget);
    expect(find.byKey(const Key('review-write')), findsNothing);
    // The average and the count cover every review, not only the first 100.
    expect(find.text('4,0 / 5 ★ · 101 đánh giá'), findsOneWidget);
  });
}
