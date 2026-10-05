import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});
  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  late Future<List<Voucher>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<ShopRepository>().vouchers();
  });

  Future<void> edit([Voucher? old]) async {
    final body = await showDialog<Json>(
      context: context,
      builder: (_) => VoucherDialog(old: old),
    );
    if (body == null || !mounted) return;
    try {
      await context.read<ShopRepository>().saveVoucher(body, id: old?.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> remove(Voucher voucher) async {
    if (!await confirm(context, 'Ngừng sử dụng voucher ${voucher.code}?') ||
        !mounted) {
      return;
    }
    try {
      await context.read<ShopRepository>().deleteVoucher(voucher.id);
      if (mounted) reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Voucher')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: edit,
      icon: const Icon(Icons.add),
      label: const Text('Thêm voucher'),
    ),
    body: AsyncPanel<List<Voucher>>(
      future: future,
      onRetry: reload,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Chưa có voucher.',
      builder: (items) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final voucher in items)
            Card(
              child: ListTile(
                title: Text('${voucher.code} · -${money(voucher.discountVnd)}'),
                subtitle: Text(
                  'Đơn từ ${money(voucher.minSubtotalVnd)} · '
                  '${voucher.usedCount}/${voucher.maxUses} lượt\n'
                  '${voucher.isActive ? 'Đang hoạt động' : 'Ngừng sử dụng'} · '
                  'đến ${voucher.endsAtUtc.toLocal()}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) =>
                      action == 'edit' ? edit(voucher) : remove(voucher),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Ngừng sử dụng'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class VoucherDialog extends StatefulWidget {
  const VoucherDialog({this.old, super.key});
  final Voucher? old;
  @override
  State<VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<VoucherDialog> {
  final key = GlobalKey<FormState>();
  final data = <String, dynamic>{};
  late DateTime starts =
      widget.old?.startsAtUtc.toLocal() ??
      DateTime.now().subtract(const Duration(minutes: 1));
  late DateTime ends =
      widget.old?.endsAtUtc.toLocal() ??
      DateTime.now().add(const Duration(days: 30));

  Future<void> chooseDate(bool start) async {
    final current = start ? starts : ends;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        starts = selected;
      } else {
        ends = selected;
      }
    });
  }

  Widget field(
    String name,
    String label,
    String? initial, {
    String? Function(String?)? validator,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      initialValue: initial,
      decoration: InputDecoration(labelText: label),
      keyboardType: number ? TextInputType.number : null,
      validator: validator ?? requiredText,
      onSaved: (v) => data[name] = v?.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.old == null ? 'Thêm voucher' : 'Sửa voucher'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field('code', 'Mã voucher', widget.old?.code),
              field(
                'discountVnd',
                'Giảm VND',
                widget.old?.discountVnd.toString(),
                validator: positiveNumber,
                number: true,
              ),
              field(
                'minSubtotalVnd',
                'Đơn tối thiểu VND',
                widget.old?.minSubtotalVnd.toString() ?? '0',
                validator: (v) =>
                    int.tryParse(v ?? '') == null || int.parse(v!) < 0
                    ? 'Nhập số nguyên không âm'
                    : null,
                number: true,
              ),
              field(
                'maxUses',
                'Số lượt dùng tối đa',
                widget.old?.maxUses.toString() ?? '10',
                validator: positiveNumber,
                number: true,
              ),
              ListTile(
                title: const Text('Bắt đầu'),
                subtitle: Text(starts.toString()),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () => chooseDate(true),
              ),
              ListTile(
                title: const Text('Kết thúc'),
                subtitle: Text(ends.toString()),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () => chooseDate(false),
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
          if (!starts.isBefore(ends)) {
            showError(context, 'Thời gian bắt đầu phải trước kết thúc.');
            return;
          }
          key.currentState!.save();
          for (final name in ['discountVnd', 'minSubtotalVnd', 'maxUses']) {
            data[name] = int.parse(data[name] as String);
          }
          data['startsAtUtc'] = starts.toUtc().toIso8601String();
          data['endsAtUtc'] = ends.toUtc().toIso8601String();
          Navigator.pop(context, data);
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
