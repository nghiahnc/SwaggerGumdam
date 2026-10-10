import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/error_text.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../core/voucher_policy.dart';
import '../widgets/common.dart';

/// FL-13 · Admin voucher management: list, add, edit and stop using vouchers.
///
/// Every endpoint here is Admin-only on the API. The list is read again after
/// each write because checkout changes `usedCount` outside this screen.
/// "Ngừng sử dụng" is a soft delete (`IsActive = false`): orders that used the
/// voucher keep it, and the API has no way to switch it back on.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});
  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  Future<List<Voucher>>? future;

  /// True while a voucher is being stopped; locks the menus and the add
  /// button so the same action cannot be sent twice.
  bool busy = false;

  @override
  void initState() {
    super.initState();
    // The admin tab is hidden from customers; check again here so a
    // non-admin who reaches this route sends no request at all.
    if (context.read<SessionController>().isAdmin) reload();
  }

  void reload() {
    final next = readable(context.read<ShopRepository>().vouchers());
    setState(() {
      future = next;
    });
  }

  /// Sends the form; returns null on success or the message the dialog shows.
  Future<String?> save(VoucherInput input, Voucher? old) async {
    try {
      await context.read<ShopRepository>().saveVoucher(
        input.toJson(),
        id: old?.id,
      );
      if (mounted) reload();
      return null;
    } catch (error) {
      return describeError(error);
    }
  }

  Future<void> edit([Voucher? old]) async {
    // Taken before any await: the list is rebuilt while the dialog is open.
    final messenger = ScaffoldMessenger.of(context);
    final code = await showDialog<String>(
      context: context,
      // A tap beside the dialog must not throw away what was typed.
      barrierDismissible: false,
      builder: (_) =>
          VoucherDialog(old: old, onSubmit: (input) => save(input, old)),
    );
    if (code == null) return;
    _show(
      messenger,
      old == null ? 'Đã thêm voucher $code' : 'Đã cập nhật voucher $code',
    );
  }

  Future<void> stop(Voucher voucher) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = context.read<ShopRepository>();
    final agreed = await confirm(
      context,
      'Ngừng sử dụng voucher ${voucher.code}? Khách sẽ không áp dụng được mã '
      'này nữa; các đơn đã dùng mã vẫn giữ nguyên. Không bật lại được.',
    );
    if (!agreed || !mounted) return;
    setState(() => busy = true);
    String message;
    try {
      await repository.deleteVoucher(voucher.id);
      message = 'Đã ngừng sử dụng ${voucher.code}';
    } catch (error) {
      message = describeError(error);
    }
    if (!mounted) return;
    setState(() => busy = false);
    reload();
    _show(messenger, message);
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SessionController>().isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voucher')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Chỉ tài khoản quản trị mới quản lý được voucher.',
              key: Key('vouchers-denied'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final current = future;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: busy ? null : reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(key: Key('vouchers-busy')),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-voucher'),
        onPressed: busy ? null : () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm voucher'),
      ),
      body: current == null
          ? const SizedBox.shrink()
          : AsyncPanel<List<Voucher>>(
              future: current,
              onRetry: reload,
              isEmpty: (items) => items.isEmpty,
              emptyMessage:
                  'Chưa có voucher. Bấm "Thêm voucher" để tạo mã đầu tiên.',
              builder: (items) {
                final now = DateTime.now();
                return ListView(
                  // Leaves room for the floating button over the last card.
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  children: [
                    for (final voucher in items)
                      _VoucherCard(
                        voucher: voucher,
                        state: VoucherPolicy.stateOf(voucher, now),
                        busy: busy,
                        onEdit: () => edit(voucher),
                        onStop: () => stop(voucher),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

void _show(ScaffoldMessengerState messenger, String message) {
  if (!messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.voucher,
    required this.state,
    required this.busy,
    required this.onEdit,
    required this.onStop,
  });
  final Voucher voucher;
  final VoucherState state;
  final bool busy;
  final VoidCallback onEdit, onStop;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final icon = switch (state) {
      VoucherState.active => Icons.check_circle_outline,
      VoucherState.scheduled => Icons.schedule,
      VoucherState.expired => Icons.event_busy_outlined,
      VoucherState.usedUp => Icons.remove_circle_outline,
      VoucherState.stopped => Icons.block,
    };
    final usable =
        state == VoucherState.active || state == VoucherState.scheduled;
    return Card(
      key: ValueKey('voucher-${voucher.id}'),
      child: ListTile(
        title: Text('${voucher.code} · giảm ${money(voucher.discountVnd)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Đơn từ ${money(voucher.minSubtotalVnd)} · đã dùng '
              '${voucher.usedCount}/${voucher.maxUses} lượt',
            ),
            Text(
              '${formatLocal(voucher.startsAtUtc)} → '
              '${formatLocal(voucher.endsAtUtc)}',
            ),
            const SizedBox(height: 6),
            Chip(
              key: ValueKey('voucher-state-${voucher.id}'),
              avatar: Icon(icon, size: 18, color: usable ? null : error),
              label: Text(state.label),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        isThreeLine: true,
        // A stopped voucher cannot be edited back into use, so it has no menu.
        trailing: voucher.isActive
            ? PopupMenuButton<String>(
                key: ValueKey('voucher-menu-${voucher.id}'),
                enabled: !busy,
                tooltip: 'Thao tác',
                onSelected: (action) => action == 'edit' ? onEdit() : onStop(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'stop', child: Text('Ngừng sử dụng')),
                ],
              )
            : null,
      ),
    );
  }
}

/// The values the API's VoucherRequest takes.
class VoucherInput {
  const VoucherInput({
    required this.code,
    required this.discountVnd,
    required this.minSubtotalVnd,
    required this.maxUses,
    required this.starts,
    required this.ends,
  });
  final String code;
  final int discountVnd, minSubtotalVnd, maxUses;
  final DateTime starts, ends;

  Json toJson() => {
    'code': code,
    'discountVnd': discountVnd,
    'minSubtotalVnd': minSubtotalVnd,
    'maxUses': maxUses,
    'startsAtUtc': starts.toUtc().toIso8601String(),
    'endsAtUtc': ends.toUtc().toIso8601String(),
  };
}

/// Add or edit one voucher. The dialog sends the request itself through
/// [onSubmit] and closes (returning the saved code) only when it succeeds; on
/// a refusal such as "Mã voucher đã tồn tại." it stays open with the values
/// typed and shows the reason.
class VoucherDialog extends StatefulWidget {
  const VoucherDialog({required this.onSubmit, this.old, super.key});
  final Voucher? old;

  /// Returns null on success, otherwise the message to show.
  final Future<String?> Function(VoucherInput input) onSubmit;

  @override
  State<VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<VoucherDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.old?.code ?? '');
  late final _discount = TextEditingController(
    text: widget.old?.discountVnd.toString() ?? '',
  );
  late final _minSubtotal = TextEditingController(
    text: widget.old?.minSubtotalVnd.toString() ?? '0',
  );
  late final _maxUses = TextEditingController(
    text: widget.old?.maxUses.toString() ?? '100',
  );
  late DateTime _starts = widget.old?.startsAtUtc.toLocal() ?? _thisMinute();
  late DateTime _ends =
      widget.old?.endsAtUtc.toLocal() ??
      _thisMinute().add(const Duration(days: 30));

  /// Errors appear after the first save, then follow the admin's changes.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _saving = false;
  String? _serverError;

  static DateTime _thisMinute() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  bool get _editing => widget.old != null;

  String? get _periodError => _autovalidate == AutovalidateMode.disabled
      ? null
      : VoucherPolicy.period(_starts, _ends, now: DateTime.now());

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_code, _discount, _minSubtotal, _maxUses]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The app's own rules (plain code, caps) are stricter than the API. A
  /// voucher created elsewhere (Swagger) may break them; editing it, say to
  /// extend the end date, must not force a new code customers do not know,
  /// so a value left as it was is accepted.
  String? Function(String?) _keepOld(
    String? old,
    String? Function(String?) rule, {
    String Function(String) normalize = _trim,
  }) => (value) {
    if (_editing && old != null && normalize(value ?? '') == old) return null;
    return rule(value);
  };

  static String _trim(String value) => value.trim();

  Future<void> _pick({required bool start}) async {
    final current = start ? _starts : _ends;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      // The API accepts any dates; keep an existing voucher's own date pickable.
      firstDate: current.isBefore(DateTime(2020)) ? current : DateTime(2020),
      lastDate: current.isAfter(DateTime(2100)) ? current : DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _starts = picked;
      } else {
        _ends = picked;
      }
    });
  }

  Future<void> _save() async {
    final fieldsOk = _form.currentState!.validate();
    final period = VoucherPolicy.period(_starts, _ends, now: DateTime.now());
    if (!fieldsOk || period != null) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final input = VoucherInput(
      code: VoucherPolicy.normalizeCode(_code.text),
      discountVnd: int.parse(_discount.text.trim()),
      minSubtotalVnd: int.parse(_minSubtotal.text.trim()),
      maxUses: int.parse(_maxUses.text.trim()),
      starts: _starts,
      ends: _ends,
    );
    setState(() {
      _saving = true;
      _serverError = null;
    });
    final problem = await widget.onSubmit(input);
    if (!mounted) return;
    if (problem == null) {
      Navigator.pop(context, input.code);
    } else {
      setState(() {
        _saving = false;
        _serverError = problem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final typed = _code.text;
    final normalized = VoucherPolicy.normalizeCode(typed);
    final period = _periodError;
    // While saving, closing would hide the outcome of a request in flight.
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        // Scrolls instead of overflowing with large system fonts.
        scrollable: true,
        title: Text(_editing ? 'Sửa voucher' : 'Thêm voucher'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _form,
            autovalidateMode: _autovalidate,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const Key('voucher-code'),
                  controller: _code,
                  enabled: !_saving,
                  maxLength: VoucherPolicy.codeMaxLength,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Mã voucher',
                    helperText: typed.isNotEmpty && typed != normalized
                        ? 'Sẽ lưu là $normalized'
                        : 'Khách nhập mã này khi đặt hàng',
                  ),
                  validator: _keepOld(
                    widget.old?.code,
                    VoucherPolicy.code,
                    normalize: VoucherPolicy.normalizeCode,
                  ),
                ),
                const SizedBox(height: 8),
                _number(
                  'voucher-discount',
                  _discount,
                  'Số tiền giảm (VND)',
                  _keepOld(
                    '${widget.old?.discountVnd}',
                    VoucherPolicy.discount,
                  ),
                ),
                _number(
                  'voucher-min-subtotal',
                  _minSubtotal,
                  'Đơn tối thiểu (VND)',
                  _keepOld(
                    '${widget.old?.minSubtotalVnd}',
                    VoucherPolicy.minSubtotal,
                  ),
                ),
                _number(
                  'voucher-max-uses',
                  _maxUses,
                  'Số lượt dùng tối đa',
                  _keepOld(
                    '${widget.old?.maxUses}',
                    (v) => VoucherPolicy.usageLimit(
                      v,
                      usedCount: widget.old?.usedCount ?? 0,
                    ),
                  ),
                  helper: _editing
                      ? 'Đã dùng ${widget.old!.usedCount} lượt'
                      : null,
                ),
                ListTile(
                  key: const Key('voucher-starts'),
                  contentPadding: EdgeInsets.zero,
                  enabled: !_saving,
                  title: const Text('Bắt đầu'),
                  subtitle: Text(formatLocal(_starts)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () => _pick(start: true),
                ),
                ListTile(
                  key: const Key('voucher-ends'),
                  contentPadding: EdgeInsets.zero,
                  enabled: !_saving,
                  title: const Text('Kết thúc'),
                  subtitle: Text(formatLocal(_ends)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () => _pick(start: false),
                ),
                if (period != null)
                  Text(
                    period,
                    key: const Key('voucher-period-error'),
                    style: TextStyle(color: error),
                  ),
                if (_serverError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _serverError!,
                    key: const Key('voucher-server-error'),
                    style: TextStyle(color: error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('voucher-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Widget _number(
    String key,
    TextEditingController controller,
    String label,
    String? Function(String?) validator, {
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      key: Key(key),
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, helperText: helper),
      validator: validator,
    ),
  );
}
