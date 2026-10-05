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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Địa chỉ giao hàng')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: edit,
      icon: const Icon(Icons.add),
      label: const Text('Thêm địa chỉ'),
    ),
    body: AsyncPanel<List<Address>>(
      future: future,
      onRetry: reload,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Chưa có địa chỉ. Hãy thêm trước khi đặt hàng.',
      builder: (items) => RefreshIndicator(
        onRefresh: () async => reload(),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final a = items[index];
            return Card(
              child: ListTile(
                title: Text('${a.recipient} · ${a.phone}'),
                subtitle: Text(
                  '${a.display}${a.isDefault ? '\nMặc định' : ''}',
                ),
                isThreeLine: a.isDefault,
                trailing: PopupMenuButton<String>(
                  onSelected: (choice) =>
                      choice == 'edit' ? edit(a) : remove(a),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ),
            );
          },
        ),
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

  Widget field(String keyName, String label, String? initial) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      initialValue: initial,
      decoration: InputDecoration(labelText: label),
      validator: requiredText,
      onSaved: (value) => values[keyName] = value!.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Thêm địa chỉ' : 'Sửa địa chỉ'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field('recipient', 'Người nhận', widget.existing?.recipient),
              field('phone', 'Điện thoại', widget.existing?.phone),
              field('line1', 'Số nhà / đường', widget.existing?.line1),
              field('ward', 'Phường / xã', widget.existing?.ward),
              field('district', 'Quận / huyện', widget.existing?.district),
              field('province', 'Tỉnh / thành phố', widget.existing?.province),
              SwitchListTile(
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
