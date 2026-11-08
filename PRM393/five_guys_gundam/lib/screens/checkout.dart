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
    // ListView chỉ dựng phần đang hiện: nhiều địa chỉ/màn thấp thì ô voucher
    // có thể chưa được dựng, khi đó currentState là null nên kiểm tra thẳng.
    final form = formKey.currentState;
    if (form == null) {
      final error = validateVoucherCode(voucher.text);
      if (error != null) {
        showError(context, error);
        return;
      }
    } else if (!form.validate()) {
      return;
    }
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const HudTitle('Xác nhận đặt hàng', tag: 'Launch sequence'),
    ),
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  SectionHeader(
                    'Địa chỉ giao hàng',
                    number: 1,
                    trailing: TextButton(
                      onPressed: manageAddresses,
                      child: const Text('Quản lý địa chỉ'),
                    ),
                  ),
                  if (addresses.isEmpty)
                    InfoBanner(
                      tone: Tone.warning,
                      tag: 'Thiếu tọa độ giao hàng',
                      message: 'Bạn cần thêm địa chỉ trước khi đặt hàng.',
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
                  const SectionHeader('Mã giảm giá', number: 2, tag: 'Voucher'),
                  HudCard(
                    margin: EdgeInsets.zero,
                    child: Form(
                      key: formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: TextFormField(
                        controller: voucher,
                        textCapitalization: TextCapitalization.characters,
                        validator: validateVoucherCode,
                        decoration: const InputDecoration(
                          labelText: 'Mã voucher (nếu có)',
                          prefixIcon: Icon(Icons.local_offer_outlined),
                          helperText:
                              'API sẽ kiểm tra điều kiện voucher khi tạo đơn.',
                          helperMaxLines: 2,
                        ),
                      ),
                    ),
                  ),
                  const SectionHeader('Tóm tắt', number: 3, tag: 'Summary'),
                  HudCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MoneyRow('Tạm tính', money(widget.subtotalVnd)),
                        const Divider(height: 20),
                        const Text(
                          'Giảm giá (nếu có) và giá cuối cùng được API xác nhận khi đặt hàng.',
                          style: TextStyle(color: Hud.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            StickyBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  if (lastError != null) _ErrorBox(lastError!),
                  Row(
                    children: [
                      const HudLabel('Tạm tính đơn'),
                      const Spacer(),
                      Flexible(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            money(widget.subtotalVnd),
                            style: const TextStyle(
                              color: Hud.red,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
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
                                  color: Colors.white,
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
          ],
        );
      },
    ),
  );
}

// Hộp lỗi đỏ nằm cố định trên nút "Tạo đơn hàng" (SnackBar tự ẩn và che nút).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Hud.redSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Hud.red.withValues(alpha: .3)),
    ),
    child: Row(
      spacing: 8,
      children: [
        const Icon(Icons.error_outline, color: Hud.redDark),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Hud.redDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

// Một địa chỉ có thể chọn; viền đỏ khi đang được chọn.
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
  Widget build(BuildContext context) => HudCard(
    onTap: onTap,
    borderColor: selected ? Hud.red : Hud.line,
    color: selected ? const Color(0xFFFFF5F5) : Colors.white,
    padding: const EdgeInsets.all(14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? Hud.red : Hud.muted,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      address.recipient,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Hud.ink,
                      ),
                    ),
                  ),
                  if (address.isDefault)
                    const StatusPill('Mặc định', color: Hud.red),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${address.phone}\n${address.display}',
                style: const TextStyle(color: Hud.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
