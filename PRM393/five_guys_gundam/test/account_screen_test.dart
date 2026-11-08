import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/screens/account.dart';

import 'test_helpers.dart';

// UC01 đăng ký, UC02 đăng nhập, UC03 xem hồ sơ (GET /auth/me).
Map<String, Object?> user({String name = 'Người dùng Test'}) => {
  'id': 'u1',
  'email': 'test@gundam.local',
  'fullName': name,
  'role': 'Customer',
};

Map<String, Object?> token() => {'accessToken': 'jwt', 'user': user()};

void main() {
  group('UC03 hồ sơ', () {
    testWidgets(
      'A1 đọc hồ sơ từ GET /auth/me, không chỉ dùng bản lúc đăng nhập',
      (tester) async {
        final requests = <String>[];
        await pumpScreen(tester, const AccountScreen(), {
          'GET /api/v1/auth/me': user(name: 'Tên mới từ API'),
        }, requests: requests);

        expect(requests, contains('GET /api/v1/auth/me'));
        expect(find.text('Tên mới từ API'), findsOneWidget);
        expect(find.text('test@gundam.local'), findsOneWidget);
        expect(find.text('Vai trò: Customer'), findsOneWidget);
        expect(find.text('Mã tài khoản: u1'), findsOneWidget);
      },
    );

    testWidgets('A2 đăng nhập ngay trên tab Tài khoản thì đọc hồ sơ', (
      tester,
    ) async {
      final requests = <String>[];
      await pumpScreen(
        tester,
        const AccountScreen(),
        {
          'POST /api/v1/auth/login': token(),
          'GET /api/v1/auth/me': user(name: 'Tên mới từ API'),
        },
        requests: requests,
        signedIn: false,
      );
      expect(requests, isEmpty);

      await tester.tap(find.text('Đăng nhập / Đăng ký'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@gundam.local',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'Secret123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(requests, ['POST /api/v1/auth/login', 'GET /api/v1/auth/me']);
      expect(find.text('Tên mới từ API'), findsOneWidget);
    });

    testWidgets('A3 401 giữ thông tin cũ, báo hết phiên và tải lại được', (
      tester,
    ) async {
      final responses = <String, Object>{
        'GET /api/v1/auth/me': problem(401, 'Unauthorized'),
      };
      await pumpScreen(tester, const AccountScreen(), responses);

      expect(find.text('Người dùng Test'), findsOneWidget);
      expect(
        find.text(
          'Phiên đăng nhập đã hết hạn. Hãy đăng xuất và đăng nhập lại.',
        ),
        findsOneWidget,
      );

      responses['GET /api/v1/auth/me'] = user(name: 'Đã đọc lại');
      await tester.tap(find.text('Tải lại hồ sơ'));
      await tester.pumpAndSettle();
      expect(find.text('Đã đọc lại'), findsOneWidget);
      expect(find.text('Tải lại hồ sơ'), findsNothing);
    });

    testWidgets('A4 đăng xuất thì không gọi API nữa và hiện nút đăng nhập', (
      tester,
    ) async {
      final requests = <String>[];
      await pumpScreen(tester, const AccountScreen(), {
        'GET /api/v1/auth/me': user(),
      }, requests: requests);

      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập / Đăng ký'), findsOneWidget);
      expect(requests, ['GET /api/v1/auth/me']);
    });
  });

  group('UC01 đăng ký, UC02 đăng nhập', () {
    Future<Map<String, Object?>> submit(
      WidgetTester tester, {
      bool register = false,
      String email = ' Test@Gundam.local ',
      String password = 'Secret123',
    }) async {
      final requests = <String>[];
      final bodies = <String, Object?>{};
      await pumpScreen(
        tester,
        const AuthScreen(),
        {
          'POST /api/v1/auth/login': token(),
          'POST /api/v1/auth/register': token(),
        },
        requests: requests,
        bodies: bodies,
        signedIn: false,
      );
      if (register) {
        await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Họ tên'),
          '  Nguyễn Văn A ',
        );
      }
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        password,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, register ? 'Đăng ký' : 'Đăng nhập'),
      );
      await tester.pumpAndSettle();
      return {'requests': requests, ...bodies};
    }

    testWidgets('L1 đăng nhập gửi email đã bỏ khoảng trắng', (tester) async {
      final sent = await submit(tester);
      expect(sent['requests'], ['POST /api/v1/auth/login']);
      expect(sent['POST /api/v1/auth/login'], {
        'email': 'Test@Gundam.local',
        'password': 'Secret123',
      });
    });

    testWidgets('L2 mật khẩu dưới 8 ký tự bị chặn, không gọi API', (
      tester,
    ) async {
      final sent = await submit(tester, password: '1234567');
      expect(sent['requests'], isEmpty);
      expect(find.text('Mật khẩu tối thiểu 8 ký tự'), findsOneWidget);
    });

    testWidgets('L3 email sai định dạng bị chặn, không gọi API', (
      tester,
    ) async {
      final sent = await submit(tester, email: 'khong-co-a-cong');
      expect(sent['requests'], isEmpty);
      expect(find.text('Email không hợp lệ'), findsOneWidget);
    });

    testWidgets('R1 đăng ký gửi họ tên, email và mật khẩu', (tester) async {
      final sent = await submit(tester, register: true);
      expect(sent['requests'], ['POST /api/v1/auth/register']);
      expect(sent['POST /api/v1/auth/register'], {
        'fullName': 'Nguyễn Văn A',
        'email': 'Test@Gundam.local',
        'password': 'Secret123',
      });
    });

    testWidgets('R2 email đã dùng (409) hiện lỗi từ API và ở lại form', (
      tester,
    ) async {
      await pumpScreen(tester, const AuthScreen(), {
        'POST /api/v1/auth/register': problem(409, 'Email đã được sử dụng.'),
      }, signedIn: false);
      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Họ tên'), 'A');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@b.c',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'Secret123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.text('Email đã được sử dụng.'), findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
    });
  });
}
