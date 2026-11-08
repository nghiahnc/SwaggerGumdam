// Tác giả: Nguyễn Hữu Tài (AgnesLorem) — CE190387, có AI hỗ trợ
// UC: UC18, UC19, UC22, UC23, UC25, UC26, UC28
// Mục đích: khung dialog cho các form quản trị. Dialog chỉ đóng khi lưu thành
// công, nên API từ chối thì người dùng không mất dữ liệu đã gõ.

import 'package:flutter/material.dart';

/// Dialog có form, tự lo phần kiểm tra, trạng thái đang lưu và lỗi từ API.
///
/// Khi lưu thành công, dialog trả về `true` cho `showDialog`.
class AdminFormDialog extends StatefulWidget {
  const AdminFormDialog({
    required this.title,
    required this.child,
    required this.onSubmit,
    this.submitLabel = 'Lưu',
    this.width = 420,
    this.busy = false,
    super.key,
  });

  final String title;
  final String submitLabel;
  final double width;

  /// Form đang làm việc riêng (ví dụ tải ảnh), tạm khóa nút lưu.
  final bool busy;

  /// Các ô nhập, nằm trong `Form` của dialog.
  final Widget child;

  /// Chạy sau khi form hợp lệ. Ném lỗi thì dialog giữ nguyên và hiện lỗi đó.
  final Future<void> Function() onSubmit;

  @override
  State<AdminFormDialog> createState() => _AdminFormDialogState();
}

class _AdminFormDialogState extends State<AdminFormDialog> {
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  String? error;

  Future<void> submit() async {
    final form = formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = error;
    // Đang gọi API thì không cho đóng, tránh màn hình phía sau không tải lại.
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: widget.width,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Form(key: formKey, child: widget.child),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: saving || widget.busy ? null : submit,
            child: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
