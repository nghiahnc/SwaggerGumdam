import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
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
  final voucher = TextEditingController();
  bool busy = false;

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

  Future<void> submit() async {
    if (addressId == null) {
      showError(context, 'Hãy chọn địa chỉ giao hàng.');
      return;
    }
    if (!await confirm(
          context,
          'Tạo đơn và giữ tồn kho cho các sản phẩm trong giỏ?',
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      final order = await context.read<ShopRepository>().checkout(
        addressId!,
        voucher.text.trim().isEmpty ? null : voucher.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xác nhận đặt hàng')),
    body: AsyncPanel<List<Address>>(
      future: future,
      onRetry: reload,
      builder: (addresses) {
        addressId ??=
            addresses.where((a) => a.isDefault).firstOrNull?.id ??
            addresses.firstOrNull?.id;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Địa chỉ giao hàng',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (addresses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Bạn cần thêm địa chỉ trước khi đặt hàng.'),
              ),
            for (final address in addresses)
              ListTile(
                title: Text('${address.recipient} · ${address.phone}'),
                subtitle: Text(address.display),
                leading: Icon(
                  addressId == address.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: () => setState(() => addressId = address.id),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressesScreen()),
                );
                if (mounted) {
                  addressId = null;
                  reload();
                }
              },
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Quản lý địa chỉ'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: voucher,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Mã voucher (nếu có)',
                helperText: 'API sẽ kiểm tra điều kiện voucher khi tạo đơn.',
              ),
            ),
            const SizedBox(height: 24),
            Text('Tạm tính: ${money(widget.subtotalVnd)}'),
            const Text('Giá cuối cùng được API xác nhận khi đặt hàng.'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy || addresses.isEmpty ? null : submit,
              child: busy
                  ? const CircularProgressIndicator()
                  : const Text('Tạo đơn hàng'),
            ),
          ],
        );
      },
    ),
  );
}
