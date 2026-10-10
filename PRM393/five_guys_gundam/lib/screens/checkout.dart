import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../core/voucher_policy.dart';
import '../widgets/common.dart';
import 'addresses.dart';
import 'orders.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({required this.subtotalVnd, super.key});
  final int subtotalVnd;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late Future<List<Address>> future;
  String? addressId;
  final formKey = GlobalKey<FormState>();
  final voucher = TextEditingController();
  bool busy = false;
  // Lỗi gần nhất từ API (hết tồn, voucher...), hiện cố định trên nút đặt hàng.
  String? lastError;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<ShopRepository>().addresses();
  });
  @override
  void dispose() {
    voucher.dispose();
    super.dispose();
  }

  Future<void> manageAddresses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressesScreen()),
    );
    if (mounted) {
      addressId = null;
      reload();
    }
  }

  Future<void> submit() async {
    if (addressId == null) {
      showError(context, 'Hãy chọn địa chỉ giao hàng.');
      return;
    }
    if (!formKey.currentState!.validate()) return;
    if (!await confirm(
          context,
          'Tạo đơn và giữ tồn kho cho các sản phẩm trong giỏ?',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      busy = true;
      lastError = null;
    });
    try {
      final order = await context.read<ShopRepository>().checkout(
        addressId!,
        normalizeVoucherCode(voucher.text),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      );
    } catch (error) {
      if (mounted) {
        setState(() => lastError = error.toString());
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đặt hàng')),
      body: AsyncPanel<List<Address>>(
        future: future,
        onRetry: reload,
        builder: (addresses) {
          addressId ??=
              addresses.where((a) => a.isDefault).firstOrNull?.id ??
              addresses.firstOrNull?.id;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Section(
                      icon: Icons.location_on_outlined,
                      title: 'Địa chỉ giao hàng',
                      trailing: TextButton(
                        onPressed: manageAddresses,
                        child: const Text('Quản lý địa chỉ'),
                      ),
                      children: [
                        if (addresses.isEmpty)
                          _Notice(
                            text: 'Bạn cần thêm địa chỉ trước khi đặt hàng.',
                            action: OutlinedButton.icon(
                              onPressed: manageAddresses,
                              icon: const Icon(Icons.add),
                              label: const Text('Thêm địa chỉ'),
                            ),
                          ),
                        for (final address in addresses)
                          _AddressOption(
                            address: address,
                            selected: addressId == address.id,
                            onTap: () => setState(() => addressId = address.id),
                          ),
                      ],
                    ),
                    _Section(
                      icon: Icons.local_offer_outlined,
                      title: 'Mã giảm giá',
                      children: [
                        Form(
                          key: formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: TextFormField(
                            controller: voucher,
                            textCapitalization: TextCapitalization.characters,
                            validator: validateVoucherCode,
                            decoration: const InputDecoration(
                              labelText: 'Mã voucher (nếu có)',
                              helperText: 'API sẽ kiểm tra điều kiện voucher khi tạo đơn.',
                            ),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      icon: Icons.receipt_outlined,
                      title: 'Tóm tắt',
                      children: [
                        Row(
                          children: [
                            const Text('Tạm tính'),
                            const Spacer(),
                            Text(money(widget.subtotalVnd)),
                          ],
                        ),
                        Text(
                          'Giảm giá (nếu có) và giá cuối cùng được API xác nhận khi đặt hàng.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: theme.colorScheme.surface,
                elevation: 8,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        if (lastError != null) _ErrorBox(lastError!),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: busy || addresses.isEmpty ? null : submit,
                          child: busy
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Đang tạo đơn...'),
                                  ],
                                )
                              : const Text('Tạo đơn hàng'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Hộp lỗi đỏ nằm cố định trên nút "Tạo đơn hàng" (SnackBar tự ẩn và che nút).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// Khối thẻ có icon + tiêu đề + nút phụ bên phải (tùy chọn).
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 8,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?trailing, // Chỉ thêm khi có nút phụ.
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

// Một địa chỉ có thể chọn; viền màu chủ đạo khi đang được chọn.
class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });
  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer.withValues(alpha: .35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? scheme.primary : null,
        ),
        title: Text(address.recipient),
        subtitle: Text('${address.phone}\n${address.display}'),
        trailing: address.isDefault
            ? Text('Mặc định', style: TextStyle(color: scheme.primary))
            : null,
      ),
    );
  }
}

// Hộp thông báo nhỏ kèm nút hành động.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.action});
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade800),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          ],
        ),
        action,
      ],
    ),
  );
}
