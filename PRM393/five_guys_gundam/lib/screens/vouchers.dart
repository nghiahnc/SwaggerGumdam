import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/error_text.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../core/voucher_policy.dart';
import '../widgets/common.dart';

/// Admin voucher management: list, view, add, edit and stop using vouchers.
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

  Future<void> view(Voucher voucher) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VoucherDetailScreen(voucherId: voucher.id),
      ),
    );
    if (mounted) reload();
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
    if (old != null) {
      // The list may be minutes old; a checkout since then decides whether
      // the code can still change. A failed read must not unlock stale values.
      final repository = context.read<ShopRepository>();
      setState(() => busy = true);
      final Voucher fresh;
      try {
        fresh = await repository.voucher(old.id);
      } catch (error) {
        if (!mounted) return;
        setState(() => busy = false);
        _show(messenger, describeError(error));
        return;
      }
      if (!mounted) return;
      setState(() => busy = false);
      // Stopped by another admin since the list loaded: nothing to edit.
      if (!fresh.isActive) {
        _show(messenger, 'Voucher ${fresh.code} đã ngừng sử dụng');
        reload();
        return;
      }
      old = fresh;
    }
    final current = old;
    final code = await showDialog<String>(
      context: context,
      // A tap beside the dialog must not throw away what was typed.
      barrierDismissible: false,
      builder: (_) => VoucherDialog(
        old: current,
        onSubmit: (input) => save(input, current),
      ),
    );
    if (code == null) return;
    _show(
      messenger,
      current == null ? 'Đã thêm voucher $code' : 'Đã cập nhật voucher $code',
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
        appBar: AppBar(title: const HudTitle('Voucher', tag: 'Admin // Promo')),
        body: const Center(
          child: SingleChildScrollView(
            child: EmptyState(
              key: Key('vouchers-denied'),
              icon: Icons.lock_outline,
              title: 'Chỉ tài khoản quản trị mới quản lý được voucher.',
            ),
          ),
        ),
      );
    }
    final current = future;
    return Scaffold(
      appBar: AppBar(
        title: const HudTitle('Voucher', tag: 'Admin // Promo'),
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
                child: LinearProgressIndicator(
                  key: Key('vouchers-busy'),
                  color: Hud.red,
                ),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    const InfoBanner(
                      key: Key('vouchers-usage-note'),
                      tag: 'Quy tắc lượt dùng',
                      message:
                          'Lượt đã dùng tính cả đơn đang chờ thanh toán. Đơn bị '
                          'hủy, hết hạn hoặc thanh toán thất bại sẽ trả lại lượt.',
                    ),
                    const SizedBox(height: 4),
                    for (final voucher in items)
                      _VoucherCard(
                        voucher: voucher,
                        state: VoucherPolicy.stateOf(voucher, now),
                        busy: busy,
                        onView: () => view(voucher),
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
    required this.onView,
    required this.onEdit,
    required this.onStop,
  });
  final Voucher voucher;
  final VoucherState state;
  final bool busy;
  final VoidCallback onView, onEdit, onStop;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      VoucherState.active => (Icons.check_circle_outline, Hud.green),
      VoucherState.scheduled => (Icons.schedule, Hud.blue),
      VoucherState.expired => (Icons.event_busy_outlined, Hud.redDark),
      VoucherState.usedUp => (Icons.remove_circle_outline, Hud.redDark),
      VoucherState.stopped => (Icons.block, Hud.muted),
    };
    final usage = voucher.maxUses == 0
        ? 0.0
        : (voucher.usedCount / voucher.maxUses).clamp(0.0, 1.0);
    return Padding(
      key: ValueKey('voucher-${voucher.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Hud.radius),
          side: const BorderSide(color: Hud.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onView,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cuống vé: màu theo trạng thái, mép răng cưa.
                Container(
                  width: 14,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .85),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < 6; i++)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Text(
                                '${voucher.code} · giảm ${money(voucher.discountVnd)}',
                                style: const TextStyle(
                                  fontFamilyFallback: Hud.mono,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Hud.ink,
                                ),
                              ),
                              Text(
                                'Đơn từ ${money(voucher.minSubtotalVnd)} · đã dùng '
                                '${voucher.usedCount}/${voucher.maxUses} lượt',
                                style: const TextStyle(color: Hud.muted),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: usage,
                                  minHeight: 5,
                                  color: usage >= 1 ? Hud.redDark : Hud.red,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                ),
                              ),
                              Text(
                                '${formatLocal(voucher.startsAtUtc)} → '
                                '${formatLocal(voucher.endsAtUtc)}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Hud.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              StatusPill(
                                state.label,
                                color: color,
                                key: ValueKey('voucher-state-${voucher.id}'),
                              ),
                            ],
                          ),
                        ),
                        Icon(icon, size: 18, color: color),
                        // A stopped voucher cannot be edited back into use, so
                        // it has no menu.
                        if (voucher.isActive)
                          PopupMenuButton<String>(
                            key: ValueKey('voucher-menu-${voucher.id}'),
                            enabled: !busy,
                            tooltip: 'Thao tác',
                            onSelected: (action) =>
                                action == 'edit' ? onEdit() : onStop(),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Sửa')),
                              PopupMenuItem(
                                value: 'stop',
                                child: Text('Ngừng sử dụng'),
                              ),
                            ],
                          )
                        else
                          const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Reads one voucher independently from the list, including stopped vouchers.
/// This route is read-only: opening details never opens a form or sends a write.
class VoucherDetailScreen extends StatefulWidget {
  const VoucherDetailScreen({required this.voucherId, super.key});
  final String voucherId;

  @override
  State<VoucherDetailScreen> createState() => _VoucherDetailScreenState();
}

class _VoucherDetailScreenState extends State<VoucherDetailScreen> {
  Future<Voucher>? future;

  @override
  void initState() {
    super.initState();
    if (context.read<SessionController>().isAdmin) reload();
  }

  void reload() {
    final next = readable(
      context.read<ShopRepository>().voucher(widget.voucherId),
    );
    setState(() {
      future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allowed = context.watch<SessionController>().isAdmin;
    final current = future;
    return Scaffold(
      appBar: AppBar(
        title: const HudTitle('Chi tiết voucher', tag: 'Admin // Promo spec'),
        actions: [
          if (allowed)
            IconButton(
              tooltip: 'Tải lại',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: !allowed
          ? const Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  key: Key('voucher-detail-denied'),
                  icon: Icons.lock_outline,
                  title:
                      'Chỉ tài khoản quản trị mới xem được chi tiết voucher.',
                ),
              ),
            )
          : current == null
          ? const SizedBox.shrink()
          : AsyncPanel<Voucher>(
              future: current,
              onRetry: reload,
              builder: (voucher) {
                final state = VoucherPolicy.stateOf(voucher, DateTime.now());
                final usable =
                    state == VoucherState.active ||
                    state == VoucherState.scheduled;
                return ListView(
                  key: const Key('voucher-detail'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    NavyPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const HudLabel(
                            'Mã voucher',
                            color: Color(0xFFF87171),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            voucher.code,
                            style: const TextStyle(
                              fontFamilyFallback: Hud.mono,
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          StatusPill(
                            state.label,
                            color: usable
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFCA5A5),
                            background: Colors.white.withValues(alpha: .1),
                          ),
                        ],
                      ),
                    ),
                    const SectionHeader('Điều kiện áp dụng', tag: 'Rules'),
                    HudCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          _VoucherDetailRow(
                            icon: Icons.local_offer_outlined,
                            label: 'Số tiền giảm',
                            value: money(voucher.discountVnd),
                            highlight: true,
                          ),
                          _VoucherDetailRow(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Giá trị đơn tối thiểu',
                            value: money(voucher.minSubtotalVnd),
                          ),
                          _VoucherDetailRow(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Lượt đã dùng / tối đa',
                            value: '${voucher.usedCount}/${voucher.maxUses}',
                          ),
                          _VoucherDetailRow(
                            icon: Icons.play_circle_outline,
                            label: 'Bắt đầu',
                            value: formatLocal(voucher.startsAtUtc),
                          ),
                          _VoucherDetailRow(
                            icon: Icons.stop_circle_outlined,
                            label: 'Kết thúc',
                            value: formatLocal(voucher.endsAtUtc),
                            last: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const InfoBanner(
                      tag: 'Quy tắc lượt dùng',
                      message:
                          'Lượt đã dùng tính cả đơn đang chờ thanh toán. Đơn bị '
                          'hủy, hết hạn hoặc thanh toán thất bại sẽ trả lại lượt.',
                    ),
                    if (!voucher.isActive)
                      const InfoBanner(
                        tone: Tone.danger,
                        message:
                            'Voucher đã ngừng sử dụng và không thể bật lại. '
                            'Các đơn đã dùng mã vẫn giữ nguyên.',
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _VoucherDetailRow extends StatelessWidget {
  const _VoucherDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.last = false,
  });
  final IconData icon;
  final String label, value;
  final bool highlight, last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: Hud.line)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Hud.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(color: Hud.muted)),
        ),
        SelectableText(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: highlight ? Hud.red : Hud.ink,
          ),
        ),
      ],
    ),
  );
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
    // The code hint and the 0 ₫ warning follow what is typed.
    for (final c in [_code, _discount, _minSubtotal]) {
      c.addListener(() => setState(() {}));
    }
  }

  /// Shown under the amounts when the voucher would make some orders free.
  String? get _freeOrderWarning {
    final discount = int.tryParse(_discount.text.trim());
    final minimum = int.tryParse(_minSubtotal.text.trim());
    if (discount == null || minimum == null) return null;
    if (VoucherPolicy.discount(_discount.text) != null ||
        VoucherPolicy.minSubtotal(_minSubtotal.text) != null) {
      return null;
    }
    if (!VoucherPolicy.makesOrdersFree(discount, minimum)) return null;
    return 'Lưu ý: đơn từ ${money(minimum)} đến ${money(discount)} sẽ được '
        'giảm còn 0 ₫.';
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

  /// Month and weekday names come from Material's own translations. The app's
  /// MaterialApp only carries the English ones, so the pickers bring in the
  /// Vietnamese set themselves.
  static Widget _vietnamese(BuildContext context, Widget child) =>
      Localizations.override(
        context: context,
        locale: const Locale('vi'),
        delegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        child: child,
      );

  Future<void> _pick({required bool start}) async {
    final current = start ? _starts : _ends;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      // The API accepts any dates; keep an existing voucher's own date pickable.
      firstDate: current.isBefore(DateTime(2020)) ? current : DateTime(2020),
      lastDate: current.isAfter(DateTime(2100)) ? current : DateTime(2100),
      helpText: 'Chọn ngày',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      fieldLabelText: 'Ngày',
      // The Vietnamese set reads typed dates day first but keeps the English
      // hint "mm/dd/yyyy"; following it would save the wrong day.
      fieldHintText: 'dd/mm/yyyy',
      errorFormatText: 'Sai định dạng ngày',
      errorInvalidText: 'Ngày ngoài phạm vi',
      builder: (context, child) => _vietnamese(context, child!),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'Chọn giờ',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      hourLabelText: 'Giờ',
      minuteLabelText: 'Phút',
      // The form shows 24-hour times (dd/MM/yyyy HH:mm); so does the picker.
      builder: (context, child) => _vietnamese(
        context,
        MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
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
    final codeFixed = !VoucherPolicy.canChangeCode(widget.old);
    final freeWarning = _freeOrderWarning;
    // While saving, closing would hide the outcome of a request in flight.
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        // Scrolls instead of overflowing with large system fonts.
        scrollable: true,
        // Narrow side margins leave room for the field messages on phones.
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                  readOnly: codeFixed,
                  maxLength: VoucherPolicy.codeMaxLength,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Mã voucher',
                    errorMaxLines: 3,
                    helperMaxLines: 2,
                    helperText: codeFixed
                        ? 'Đã có đơn dùng mã này nên không đổi được mã'
                        : typed.isNotEmpty && typed != normalized
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
                if (freeWarning != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      freeWarning,
                      key: const Key('voucher-free-warning'),
                      style: TextStyle(color: Colors.orange.shade800),
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
                      ? 'Đã dùng ${widget.old!.usedCount} lượt (gồm đơn chờ '
                            'thanh toán)'
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
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        errorMaxLines: 3,
        helperMaxLines: 2,
      ),
      validator: validator,
    ),
  );
}
