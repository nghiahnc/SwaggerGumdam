import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/addresses.dart';

import 'test_helpers.dart';

// UC04 danh sách, UC05 chi tiết, UC06 thêm, UC07 sửa, UC08 xóa địa chỉ.
Map<String, Object?> address({
  String id = 'a1',
  String recipient = 'Nguyễn Văn A',
  String line1 = '1 Lê Lợi',
  bool isDefault = true,
}) => {
  'id': id,
  'recipient': recipient,
  'phone': '0900000000',
  'line1': line1,
  'ward': 'Bến Nghé',
  'district': 'Quận 1',
  'province': 'TP.HCM',
  'isDefault': isDefault,
};

Map<String, Object?> fields(Map<String, Object?> a) => Map.of(a)..remove('id');

Future<void> fill(WidgetTester tester, String label, String text) =>
    tester.enterText(find.widgetWithText(TextFormField, label), text);

void main() {
  late List<String> requests;
  late Map<String, Object?> bodies;
  late Map<String, Object> responses;

  Future<void> pumpAddresses(WidgetTester tester) => pumpScreen(
    tester,
    const AddressesScreen(),
    responses,
    requests: requests,
    bodies: bodies,
  );

  setUp(() {
    requests = [];
    bodies = {};
    responses = {
      'GET /api/v1/addresses': [
        address(),
        address(id: 'a2', recipient: 'Trần B', isDefault: false),
      ],
      'GET /api/v1/addresses/a1': address(line1: '1 Lê Lợi (mới nhất)'),
      'POST /api/v1/addresses': address(id: 'a3'),
      'PUT /api/v1/addresses/a1': address(),
      'DELETE /api/v1/addresses/a1': '',
    };
  });

  group('UC04 danh sách', () {
    testWidgets('D1 hiện mọi địa chỉ, đánh dấu địa chỉ mặc định', (
      tester,
    ) async {
      await pumpAddresses(tester);
      expect(requests, ['GET /api/v1/addresses']);
      expect(find.text('Nguyễn Văn A · 0900000000'), findsOneWidget);
      expect(find.text('Trần B · 0900000000'), findsOneWidget);
      expect(find.textContaining('Mặc định'), findsOneWidget);
    });

    testWidgets('D2 chưa có địa chỉ thì nhắc thêm trước khi đặt hàng', (
      tester,
    ) async {
      responses['GET /api/v1/addresses'] = <Object>[];
      await pumpAddresses(tester);
      expect(
        find.text('Chưa có địa chỉ. Hãy thêm trước khi đặt hàng.'),
        findsOneWidget,
      );
    });
  });

  group('UC05 chi tiết', () {
    testWidgets('D3 bấm vào địa chỉ thì gọi GET theo id và hiện dữ liệu mới', (
      tester,
    ) async {
      await pumpAddresses(tester);
      await tester.tap(find.text('Nguyễn Văn A · 0900000000'));
      await tester.pumpAndSettle();

      expect(requests.last, 'GET /api/v1/addresses/a1');
      expect(find.text('Chi tiết địa chỉ'), findsOneWidget);
      expect(find.text('1 Lê Lợi (mới nhất)'), findsOneWidget);
      expect(find.text('Bến Nghé'), findsOneWidget);
      expect(find.text('Có'), findsOneWidget);
    });

    testWidgets('D4 địa chỉ không còn hoặc của người khác: 404 và thử lại', (
      tester,
    ) async {
      responses['GET /api/v1/addresses/a1'] = problem(
        404,
        'Không tìm thấy địa chỉ.',
      );
      await pumpAddresses(tester);
      await tester.tap(find.text('Nguyễn Văn A · 0900000000'));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy địa chỉ.'), findsOneWidget);

      responses['GET /api/v1/addresses/a1'] = address();
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('1 Lê Lợi'), findsOneWidget);
    });

    testWidgets('D5 xóa từ màn chi tiết thì quay về và tải lại danh sách', (
      tester,
    ) async {
      await pumpAddresses(tester);
      await tester.tap(find.text('Nguyễn Văn A · 0900000000'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();

      expect(requests, [
        'GET /api/v1/addresses',
        'GET /api/v1/addresses/a1',
        'DELETE /api/v1/addresses/a1',
        'GET /api/v1/addresses',
      ]);
      expect(find.text('Địa chỉ giao hàng'), findsOneWidget);
    });

    testWidgets('D6 sửa từ màn chi tiết gửi PUT rồi đọc lại theo id', (
      tester,
    ) async {
      await pumpAddresses(tester);
      await tester.tap(find.text('Nguyễn Văn A · 0900000000'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sửa'));
      await tester.pumpAndSettle();
      await fill(tester, 'Số nhà / đường', '  9 Hai Bà Trưng ');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(bodies['PUT /api/v1/addresses/a1'], {
        ...fields(address(line1: '9 Hai Bà Trưng')),
      });
      expect(requests.where((r) => r == 'GET /api/v1/addresses/a1').length, 2);
    });
  });

  group('UC06 thêm, UC07 sửa, UC08 xóa', () {
    testWidgets('D7 form trống bị chặn, không gọi API', (tester) async {
      await pumpAddresses(tester);
      await tester.tap(find.text('Thêm địa chỉ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pump();

      expect(find.text('Không được để trống'), findsNWidgets(6));
      expect(requests, ['GET /api/v1/addresses']);
    });

    testWidgets('D8 thêm địa chỉ gửi POST đã bỏ khoảng trắng', (tester) async {
      await pumpAddresses(tester);
      await tester.tap(find.text('Thêm địa chỉ'));
      await tester.pumpAndSettle();
      await fill(tester, 'Người nhận', ' Lê C ');
      await fill(tester, 'Điện thoại', '0911111111');
      await fill(tester, 'Số nhà / đường', '5 Pasteur');
      await fill(tester, 'Phường / xã', 'Bến Thành');
      await fill(tester, 'Quận / huyện', 'Quận 1');
      await fill(tester, 'Tỉnh / thành phố', 'TP.HCM');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(bodies['POST /api/v1/addresses'], {
        'recipient': 'Lê C',
        'phone': '0911111111',
        'line1': '5 Pasteur',
        'ward': 'Bến Thành',
        'district': 'Quận 1',
        'province': 'TP.HCM',
        'isDefault': false,
      });
      expect(find.text('Đã lưu địa chỉ'), findsOneWidget);
      expect(requests.last, 'GET /api/v1/addresses');
    });

    testWidgets('D9 sửa từ menu điền sẵn dữ liệu cũ và gửi PUT', (
      tester,
    ) async {
      await pumpAddresses(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Nguyễn Văn A'),
        findsOneWidget,
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(bodies['PUT /api/v1/addresses/a1'], fields(address()));
    });

    testWidgets('D10 xóa: bấm Không thì không gọi API, Đồng ý thì DELETE', (
      tester,
    ) async {
      await pumpAddresses(tester);
      Future<void> askDelete() async {
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xóa'));
        await tester.pumpAndSettle();
      }

      await askDelete();
      await tester.tap(find.text('Không'));
      await tester.pumpAndSettle();
      expect(requests, isNot(contains('DELETE /api/v1/addresses/a1')));

      await askDelete();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(requests, contains('DELETE /api/v1/addresses/a1'));
      expect(requests.last, 'GET /api/v1/addresses');
    });
  });
}
