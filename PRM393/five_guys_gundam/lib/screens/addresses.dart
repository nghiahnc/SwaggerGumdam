import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  late Future<List<Address>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<ShopRepository>().addresses();
  });

  Future<void> edit([Address? existing]) async {
    final body = await showDialog<Json>(
      context: context,
      builder: (_) => AddressFormDialog(existing: existing),
    );
    if (body == null || !mounted) return;
    try {
      await context.read<ShopRepository>().saveAddress(body, id: existing?.id);
      if (mounted) {
        showSuccess(context, 'Đã lưu địa chỉ');
        reload();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> remove(Address address) async {
    if (!await confirm(context, 'Xóa địa chỉ của ${address.recipient}?') ||
        !mounted) {
      return;
    }
    try {
      await context.read<ShopRepository>().deleteAddress(address.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  /// Màn chi tiết có thể sửa hoặc xóa, nên quay về là tải lại danh sách.
  Future<void> openDetail(Address address) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddressDetailScreen(id: address.id)),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const HudTitle('Địa chỉ giao hàng', tag: 'Delivery coordinates'),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: edit,
      icon: const Icon(Icons.add_location_alt_outlined),
      label: const Text('Thêm địa chỉ'),
    ),
    body: AsyncPanel<List<Address>>(
      future: future,
      onRetry: reload,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Chưa có địa chỉ. Hãy thêm trước khi đặt hàng.',
      builder: (items) => RefreshIndicator(
        color: Hud.red,
        onRefresh: () async => reload(),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final a = items[index];
            return HudCard(
              onTap: () => openDetail(a),
              accent: a.isDefault ? Hud.red : null,
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: a.isDefault
                          ? Hud.redSoft
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: a.isDefault ? Hud.red : Hud.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          '${a.recipient} · ${a.phone}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Hud.ink,
                          ),
                        ),
                        Text(
                          a.display,
                          style: const TextStyle(color: Hud.muted, height: 1.4),
                        ),
                        if (a.isDefault)
                          const StatusPill('Mặc định', color: Hud.red),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Thao tác',
                    onSelected: (choice) =>
                        choice == 'edit' ? edit(a) : remove(a),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// UC05: đọc lại một địa chỉ từ `GET /addresses/{id}`. API chỉ tìm trong địa
/// chỉ của tài khoản đang đăng nhập, nên id sai hoặc của người khác là 404.
class AddressDetailScreen extends StatefulWidget {
  const AddressDetailScreen({required this.id, super.key});
  final String id;
  @override
  State<AddressDetailScreen> createState() => _AddressDetailScreenState();
}

class _AddressDetailScreenState extends State<AddressDetailScreen> {
  late Future<Address> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = fetch();
  }

  Future<Address> fetch() => context.read<ShopRepository>().address(widget.id);

  void reload() => setState(() {
    future = fetch();
  });

  Future<void> edit(Address current) async {
    final body = await showDialog<Json>(
      context: context,
      builder: (_) => AddressFormDialog(existing: current),
    );
    if (body == null || !mounted) return;
    setState(() => busy = true);
    try {
      await context.read<ShopRepository>().saveAddress(body, id: current.id);
      if (!mounted) return;
      showSuccess(context, 'Đã lưu địa chỉ');
      reload();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(Address current) async {
    if (!await confirm(context, 'Xóa địa chỉ của ${current.recipient}?') ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await context.read<ShopRepository>().deleteAddress(current.id);
      if (!mounted) return;
      showSuccess(context, 'Đã xóa địa chỉ');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => busy = false);
        showError(context, error);
      }
    }
  }

  Widget info(String label, String value, IconData icon, {bool last = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Hud.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Hud.muted),
            const SizedBox(width: 10),
            SizedBox(
              width: 116,
              child: Text(label, style: const TextStyle(color: Hud.muted)),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const HudTitle('Chi tiết địa chỉ', tag: 'Delivery coordinates'),
    ),
    body: AsyncPanel<Address>(
      future: future,
      onRetry: reload,
      builder: (a) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (busy) const LinearProgressIndicator(minHeight: 2, color: Hud.red),
          HudCard(
            margin: EdgeInsets.zero,
            accent: a.isDefault ? Hud.red : null,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                info('Người nhận', a.recipient, Icons.person_outline),
                info('Điện thoại', a.phone, Icons.phone_outlined),
                info('Số nhà / đường', a.line1, Icons.home_outlined),
                info('Phường / xã', a.ward, Icons.map_outlined),
                info('Quận / huyện', a.district, Icons.map_outlined),
                info(
                  'Tỉnh / thành phố',
                  a.province,
                  Icons.location_city_outlined,
                ),
                info(
                  'Mặc định',
                  a.isDefault ? 'Có' : 'Không',
                  Icons.star_outline,
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => edit(a),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Sửa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : () => remove(a),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xóa'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class AddressFormDialog extends StatefulWidget {
  const AddressFormDialog({this.existing, super.key});
  final Address? existing;
  @override
  State<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends State<AddressFormDialog> {
  final key = GlobalKey<FormState>();
  final values = <String, String>{};
  late bool isDefault = widget.existing?.isDefault ?? false;

  Widget field(String keyName, String label, String? initial, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          initialValue: initial,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
          ),
          validator: requiredText,
          onSaved: (value) => values[keyName] = value!.trim(),
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HudLabel('Tactical delivery spec', color: Hud.red),
        Text(widget.existing == null ? 'Thêm địa chỉ' : 'Sửa địa chỉ'),
      ],
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(
                'recipient',
                'Người nhận',
                widget.existing?.recipient,
                Icons.person_outline,
              ),
              field(
                'phone',
                'Điện thoại',
                widget.existing?.phone,
                Icons.phone_outlined,
              ),
              field(
                'line1',
                'Số nhà / đường',
                widget.existing?.line1,
                Icons.home_outlined,
              ),
              field(
                'ward',
                'Phường / xã',
                widget.existing?.ward,
                Icons.map_outlined,
              ),
              field(
                'district',
                'Quận / huyện',
                widget.existing?.district,
                Icons.map_outlined,
              ),
              field(
                'province',
                'Tỉnh / thành phố',
                widget.existing?.province,
                Icons.location_city_outlined,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Địa chỉ mặc định'),
                value: isDefault,
                onChanged: (value) => setState(() => isDefault = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate()) return;
          key.currentState!.save();
          Navigator.pop(context, {...values, 'isDefault': isDefault});
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
