import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';

class SessionController extends ChangeNotifier {
  SessionController(this._api);
  final ApiClient _api;
  ShopUser? user;
  bool get isSignedIn => user != null;

  /// Vai trò quản trị, trùng `Role` của API và policy "Admin".
  static const adminRole = 'Admin';
  bool get isAdmin => user?.role == adminRole;

  Future<void> login(String email, String password) => _authenticate(
    '/api/v1/auth/login',
    {'email': email.trim(), 'password': password},
  );

  Future<void> register(String name, String email, String password) =>
      _authenticate('/api/v1/auth/register', {
        'fullName': name.trim(),
        'email': email.trim(),
        'password': password,
      });

  Future<void> _authenticate(String path, Json body) async {
    final data = asJson(await _api.request('POST', path, body: body));
    _api.token = data['accessToken'] as String;
    user = ShopUser.fromJson(asJson(data['user']));
    notifyListeners();
  }

  /// UC03: reads the profile again from `GET /auth/me` (the account is taken
  /// from the JWT). A reply that arrives after logout or after another login
  /// is returned but not kept.
  Future<ShopUser> loadProfile() async {
    final me = ShopUser.fromJson(
      asJson(await _api.request('GET', '/api/v1/auth/me')),
    );
    if (user?.id == me.id) {
      user = me;
      notifyListeners();
    }
    return me;
  }

  void logout() {
    _api.token = null;
    user = null;
    notifyListeners();
  }
}
