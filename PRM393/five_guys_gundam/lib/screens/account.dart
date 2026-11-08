import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../widgets/common.dart';
import 'addresses.dart';
import 'admin.dart';
import 'orders.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    return Scaffold(
      appBar: AppBar(title: const HudTitle('Tài khoản', tag: 'Pilot profile')),
      body: user == null
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.smart_toy_outlined,
                  title: 'Chào phi công!',
                  message: 'Đăng nhập để quản lý địa chỉ, giỏ và đơn hàng.',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => _open(context, const AuthScreen()),
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập / Đăng ký'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                NavyPanel(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Hud.red,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        child: Text(
                          user.fullName.trim().isEmpty
                              ? '?'
                              : user.fullName.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 3,
                          children: [
                            const HudLabel(
                              'Pilot ID',
                              color: Color(0xFFF87171),
                            ),
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                            StatusPill(
                              'Vai trò: ${user.role}',
                              color: session.isAdmin
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFF86EFAC),
                              background: Colors.white.withValues(alpha: .1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Bảng điều khiển', tag: 'Cockpit'),
                _MenuTile(
                  icon: Icons.location_on_outlined,
                  color: Hud.blue,
                  title: 'Địa chỉ giao hàng',
                  subtitle: 'Thêm, sửa và chọn địa chỉ mặc định',
                  onTap: () => _open(context, const AddressesScreen()),
                ),
                _MenuTile(
                  icon: Icons.receipt_long_outlined,
                  color: Hud.purple,
                  title: 'Đơn hàng của tôi',
                  subtitle: 'Theo dõi thanh toán và vận chuyển',
                  onTap: () => _open(context, const OrdersScreen()),
                ),
                if (session.isAdmin)
                  _MenuTile(
                    icon: Icons.admin_panel_settings_outlined,
                    color: Hud.red,
                    title: 'Bảng điều khiển quản trị',
                    subtitle: 'Catalog, tồn kho và voucher',
                    highlight: true,
                    onTap: () => _open(context, const AdminHomeScreen()),
                  ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: session.logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Hud.redDark,
                    side: BorderSide(color: Hud.red.withValues(alpha: .4)),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => HudCard(
    onTap: onTap,
    padding: const EdgeInsets.all(12),
    borderColor: highlight ? Hud.red.withValues(alpha: .4) : Hud.line,
    color: highlight ? const Color(0xFFFFF5F5) : Colors.white,
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Hud.ink,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Hud.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Hud.muted),
      ],
    ),
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
    appBar: AppBar(
      title: HudTitle(
        register ? 'Tạo tài khoản' : 'Đăng nhập',
        tag: 'Pilot auth',
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const NavyPanel(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.smart_toy, size: 56, color: Hud.red),
                      SizedBox(height: 8),
                      Text(
                        'FiveGuysGundam',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      HudLabel('Hangar access terminal', color: Colors.white60),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Đăng nhập')),
                    ButtonSegment(value: true, label: Text('Đăng ký')),
                  ],
                  selected: {register},
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Hud.red,
                    selectedForegroundColor: Colors.white,
                    side: const BorderSide(color: Hud.line),
                  ),
                  onSelectionChanged: busy
                      ? null
                      : (v) => setState(() => register = v.first),
                ),
                const SizedBox(height: 16),
                HudCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (register) ...[
                        TextFormField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Họ tên',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: requiredText,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Email không hợp lệ'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) => v == null || v.length < 8
                            ? 'Mật khẩu tối thiểu 8 ký tự'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: busy ? null : submit,
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(register ? 'Đăng ký' : 'Đăng nhập'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
