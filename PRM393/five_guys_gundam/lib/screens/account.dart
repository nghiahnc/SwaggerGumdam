import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'addresses.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // UC03: hồ sơ đọc lại từ GET /auth/me, mỗi lần có tài khoản mới đăng nhập.
  Future<ShopUser>? profile;
  String? profileFor;

  void loadProfile() => setState(() {
    profile = context.read<SessionController>().loadProfile();
  });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final userId = session.user?.id;
    if (userId != profileFor) {
      // Đăng nhập ngay trên tab này cũng phải đọc lại hồ sơ, không chỉ initState.
      // `session` lấy bằng watch ở trên, nên gọi API từ đây không vi phạm luật
      // "không read trong build" của Provider; kết quả về sau, ngoài lúc build.
      profileFor = userId;
      profile = userId == null ? null : session.loadProfile();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: session.user == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 70),
                  const SizedBox(height: 16),
                  const Text('Đăng nhập để quản lý địa chỉ, giỏ và đơn hàng.'),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    ),
                    child: const Text('Đăng nhập / Đăng ký'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Profile(
                    future: profile!,
                    cached: session.user!,
                    onRetry: loadProfile,
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Địa chỉ giao hàng'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddressesScreen(),
                      ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: session.logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Shows the profile from the API. While it loads, or when it fails, the copy
/// kept since login stays on screen so the tab is never empty.
class _Profile extends StatelessWidget {
  const _Profile({
    required this.future,
    required this.cached,
    required this.onRetry,
  });
  final Future<ShopUser> future;
  final ShopUser cached;
  final VoidCallback onRetry;

  static String _problem(Object error) =>
      error is ApiException && error.statusCode == 401
      ? 'Phiên đăng nhập đã hết hạn. Hãy đăng xuất và đăng nhập lại.'
      : 'Không tải được hồ sơ: $error';

  @override
  Widget build(BuildContext context) => FutureBuilder<ShopUser>(
    future: future,
    builder: (context, snapshot) {
      final user = snapshot.data ?? cached;
      final loading = snapshot.connectionState != ConnectionState.done;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.fullName, style: Theme.of(context).textTheme.headlineSmall),
          Text(user.email),
          Text('Vai trò: ${user.role}'),
          Text(
            'Mã tài khoản: ${user.id}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (snapshot.hasError) ...[
            const SizedBox(height: 8),
            Text(
              _problem(snapshot.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại hồ sơ'),
            ),
          ],
        ],
      );
    },
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final session = context.read<SessionController>();
      if (register) {
        await session.register(name.text, email.text, password.text);
      } else {
        await session.login(email.text, password.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(register ? 'Tạo tài khoản' : 'Đăng nhập')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.smart_toy, size: 64, color: Color(0xFFDC2626)),
                const SizedBox(height: 24),
                if (register) ...[
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Họ tên'),
                    validator: requiredText,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Email không hợp lệ'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu'),
                  validator: (v) => v == null || v.length < 8
                      ? 'Mật khẩu tối thiểu 8 ký tự'
                      : null,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(register ? 'Đăng ký' : 'Đăng nhập'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => register = !register),
                  child: Text(
                    register
                        ? 'Đã có tài khoản? Đăng nhập'
                        : 'Chưa có tài khoản? Đăng ký',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
