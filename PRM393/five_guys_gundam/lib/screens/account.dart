import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../widgets/common.dart';
import 'addresses.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
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
                  Text(
                    session.user!.fullName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(session.user!.email),
                  Text('Vai trò: ${session.user!.role}'),
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
