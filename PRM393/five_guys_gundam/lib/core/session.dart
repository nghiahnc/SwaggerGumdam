import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';

class SessionController extends ChangeNotifier {
  SessionController(this._api);
  final ApiClient _api;
  ShopUser? user;
  bool get isSignedIn => user != null;
  bool get isAdmin => user?.role == 'Admin';

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

  void logout() {
    _api.token = null;
    user = null;
    notifyListeners();
  }
}
