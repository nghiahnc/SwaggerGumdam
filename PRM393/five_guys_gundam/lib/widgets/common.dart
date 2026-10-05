import 'package:flutter/material.dart';

String money(int value) {
  final digits = value.toString();
  final reversed = digits.split('').reversed.toList();
  final groups = <String>[];
  for (var i = 0; i < reversed.length; i += 3) {
    groups.add(reversed.skip(i).take(3).toList().reversed.join());
  }
  return '${groups.reversed.join('.')} ₫';
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Không được để trống' : null;

String? positiveNumber(String? value) {
  final number = int.tryParse(value?.trim() ?? '');
  return number == null || number <= 0 ? 'Nhập số nguyên lớn hơn 0' : null;
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.toString())));
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    ) ??
    false;

class AsyncPanel<T> extends StatelessWidget {
  const AsyncPanel({
    required this.future,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.emptyMessage = 'Chưa có dữ liệu',
    super.key,
  });
  final Future<T> future;
  final Widget Function(T) builder;
  final VoidCallback onRetry;
  final bool Function(T)? isEmpty;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_outlined, size: 42),
                const SizedBox(height: 12),
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );
      }
      final data = snapshot.data as T;
      if (isEmpty?.call(data) ?? false) {
        return Center(child: Text(emptyMessage));
      }
      return builder(data);
    },
  );
}

class ProductArt extends StatelessWidget {
  const ProductArt({this.url, this.size = 72, super.key});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: url == null || url!.isEmpty
        ? Container(
            width: size,
            height: size,
            color: const Color(0xFFFEE2E2),
            child: Icon(
              Icons.smart_toy_outlined,
              size: size * .52,
              color: const Color(0xFFB91C1C),
            ),
          )
        : Image.network(
            url!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: size,
              height: size,
              color: const Color(0xFFFEE2E2),
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
  );
}
