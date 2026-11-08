// Bộ giao diện "Mecha HUD" dùng chung theo bản thiết kế Figma:
// nền sáng, thẻ trắng viền mảnh, đỏ chủ đạo, khối navy, nhãn HUD chữ nhỏ.
import 'package:flutter/material.dart';

abstract final class Hud {
  static const red = Color(0xFFDC2626);
  static const redDark = Color(0xFFB91C1C);
  static const redSoft = Color(0xFFFEE2E2);
  static const navy = Color(0xFF0F172A);
  static const navySoft = Color(0xFF1E293B);
  static const bg = Color(0xFFF4F5F8);
  static const line = Color(0xFFE5E7EB);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFEF3C7);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFDCFCE7);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFDBEAFE);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFEDE9FE);

  static const radius = 16.0;
  static const mono = ['RobotoMono', 'Menlo', 'Consolas', 'monospace'];

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: red,
      primary: red,
      onPrimary: Colors.white,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: line,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          minimumSize: const Size(48, 48),
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 46),
          side: const BorderSide(color: line),
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: red,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: border(line),
        enabledBorder: border(line),
        focusedBorder: border(red, 1.5),
        errorBorder: border(redDark),
        focusedErrorBorder: border(redDark, 1.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: red,
        side: const BorderSide(color: line),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: ink),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        checkmarkColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: redSoft,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? red : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? red : muted,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: red,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        shape: rounded,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: line, space: 24),
      listTileTheme: const ListTileThemeData(iconColor: muted),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? red : null,
        ),
      ),
    );
  }
}

/// Nhãn HUD: chữ in hoa nhỏ, giãn chữ, font đơn cách.
class HudLabel extends StatelessWidget {
  const HudLabel(
    this.text, {
    this.color = Hud.muted,
    this.size = 10,
    super.key,
  });
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamilyFallback: Hud.mono,
      fontSize: size,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
      color: color,
    ),
  );
}

/// Tiêu đề AppBar có logo "FG" và nhãn HUD nhỏ phía trên.
class HudTitle extends StatelessWidget {
  const HudTitle(this.title, {this.tag = 'FG GUNDAM', super.key});
  final String title;
  final String tag;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const ShapeDecoration(
          color: Hud.red,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
        ),
        child: const Text(
          'FG',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            HudLabel(tag, color: Hud.red, size: 9),
            Text(title, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );
}

/// Thẻ trắng viền mảnh, tùy chọn vạch màu bên trái.
class HudCard extends StatelessWidget {
  const HudCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.color = Colors.white,
    this.borderColor = Hud.line,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? accent;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Hud.radius);
    Widget body = Padding(padding: padding, child: child);
    if (accent != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent!, width: 4)),
        ),
        child: body,
      );
    }
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// Viên trạng thái có chấm màu.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    this.color = Hud.muted,
    this.background,
    this.dot = true,
    super.key,
  });
  final String label;
  final Color color;
  final Color? background;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Huy hiệu thông số nhỏ (grade, tỷ lệ, SKU).
class SpecBadge extends StatelessWidget {
  const SpecBadge(this.text, {this.dark = false, this.color, super.key});
  final String text;
  final bool dark;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : (color ?? Hud.navySoft);
    final bg = dark
        ? Hud.navy.withValues(alpha: .85)
        : (color?.withValues(alpha: .1) ?? const Color(0xFFF1F5F9));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: dark ? null : Border.all(color: fg.withValues(alpha: .18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamilyFallback: Hud.mono,
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

Color gradeColor(String grade) => switch (grade.toUpperCase()) {
  'HG' => Hud.green,
  'MG' => Hud.blue,
  'RG' => Hud.purple,
  'PG' => const Color(0xFFB45309),
  _ => Hud.navySoft,
};

enum Tone { info, warning, danger, success }

/// Dải thông báo có biểu tượng và nhãn HUD.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.message,
    this.tag,
    this.tone = Tone.info,
    this.icon,
    this.action,
    super.key,
  });
  final String message;
  final String? tag;
  final Tone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, defaultIcon) = switch (tone) {
      Tone.info => (Hud.blue, Hud.blueSoft, Icons.info_outline),
      Tone.warning => (
        const Color(0xFFB45309),
        Hud.amberSoft,
        Icons.warning_amber_rounded,
      ),
      Tone.danger => (Hud.redDark, Hud.redSoft, Icons.error_outline),
      Tone.success => (Hud.green, Hud.greenSoft, Icons.check_circle_outline),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag != null) ...[
                  HudLabel(tag!, color: fg, size: 9),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TextStyle(
                    color: fg == Hud.blue ? Hud.navySoft : fg,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// Tiêu đề mục: số thứ tự đỏ (tùy chọn), tên đậm, nhãn HUD bên phải.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    this.number,
    this.tag,
    this.trailing,
    super.key,
  });
  final String title;
  final int? number;
  final String? tag;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
    child: Row(
      children: [
        if (number != null) ...[
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Hud.red,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ] else ...[
          Container(width: 3, height: 18, color: Hud.red),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
              color: Hud.ink,
            ),
          ),
        ),
        if (tag != null) HudLabel(tag!, size: 9),
        ?trailing,
      ],
    ),
  );
}

/// Thanh hành động cố định phía dưới.
class StickyBar extends StatelessWidget {
  const StickyBar({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Hud.line)),
      boxShadow: [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: child,
      ),
    ),
  );
}

/// Dòng nhãn – giá trị trong bảng tóm tắt tiền.
class MoneyRow extends StatelessWidget {
  const MoneyRow(
    this.label,
    this.value, {
    this.valueColor,
    this.bold = false,
    this.big = false,
    super.key,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final bool big;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: bold ? Hud.ink : Hud.muted,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? Hud.ink,
                fontSize: big ? 22 : 14.5,
                fontWeight: bold || big ? FontWeight.w900 : FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Trạng thái rỗng thân thiện với biểu tượng robot.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon = Icons.smart_toy_outlined,
    this.actions = const [],
    super.key,
  });
  final String title;
  final String? message;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Hud.redSoft,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Hud.red.withValues(alpha: .25)),
          ),
          child: Icon(icon, size: 42, color: Hud.red),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Hud.ink,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Hud.muted, height: 1.4),
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ],
    ),
  );
}

/// Khối navy có lưới HUD mờ, dùng cho phần đầu trang.
class NavyPanel extends StatelessWidget {
  const NavyPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = Hud.radius,
    this.margin = EdgeInsets.zero,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Hud.navy, Color(0xFF172554)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
    ),
    clipBehavior: Clip.antiAlias,
    child: CustomPaint(
      painter: _GridPainter(),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .05)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Góc ngoặc HUD.
    final bracket = Paint()
      ..color = Hud.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const l = 14.0;
    canvas.drawPath(
      Path()
        ..moveTo(6, 6 + l)
        ..lineTo(6, 6)
        ..lineTo(6 + l, 6),
      bracket,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 6 - l, size.height - 6)
        ..lineTo(size.width - 6, size.height - 6)
        ..lineTo(size.width - 6, size.height - 6 - l),
      bracket,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bộ tăng/giảm số lượng gọn.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.minusTooltip = 'Giảm',
    this.plusTooltip = 'Tăng',
    this.valueKey,
    this.child,
    super.key,
  });
  final int value;
  final VoidCallback? onMinus, onPlus;
  final String minusTooltip, plusTooltip;
  final Key? valueKey;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Hud.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: minusTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onMinus,
          icon: const Icon(Icons.remove, size: 18),
        ),
        child ??
            SizedBox(
              width: 28,
              child: Text(
                '$value',
                key: valueKey,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        IconButton(
          tooltip: plusTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onPlus,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    ),
  );
}
