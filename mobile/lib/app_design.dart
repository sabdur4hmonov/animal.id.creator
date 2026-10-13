import 'package:flutter/material.dart';

class FieldColors {
  static const forest = Color(0xff183f32);
  static const green = Color(0xff246b4e);
  static const ink = Color(0xff1c2c24);
  static const muted = Color(0xff5a685f);
  static const canvas = Color(0xfff4f6ef);
  static const line = Color(0xffdce3d9);
  static const mint = Color(0xffe6f1e8);
  static const amber = Color(0xff815800);
  static const cream = Color(0xfffff2d4);
  static const red = Color(0xff9e3838);
}

ThemeData fieldTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: FieldColors.green).copyWith(
    primary: FieldColors.forest,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: FieldColors.ink,
    onSurfaceVariant: FieldColors.muted,
    outline: FieldColors.muted,
    outlineVariant: FieldColors.line,
    error: FieldColors.red,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    scaffoldBackgroundColor: FieldColors.canvas,
    textTheme: base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: FieldColors.ink,
          ),
          titleLarge: const TextStyle(
            fontSize: 21,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.4,
            color: FieldColors.ink,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: FieldColors.ink,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: FieldColors.muted,
          ),
        )
        .apply(fontFamily: 'Roboto'),
    appBarTheme: const AppBarTheme(
      backgroundColor: FieldColors.canvas,
      foregroundColor: FieldColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xfff8faf5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FieldColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FieldColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FieldColors.green, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: FieldColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: FieldColors.mint,
      height: 76,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: FieldColors.ink,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: FieldColors.line, space: 1),
  );
}

class FieldCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const FieldCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: FieldColors.line),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class FieldTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool caution;
  const FieldTag(
    this.label, {
    super.key,
    required this.icon,
    this.caution = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: caution ? FieldColors.cream : FieldColors.mint,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: caution ? FieldColors.amber : FieldColors.forest,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: caution ? FieldColors.amber : FieldColors.forest,
            ),
          ),
        ),
      ],
    ),
  );
}

class FieldHeading extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const FieldHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
          color: FieldColors.green,
        ),
      ),
      const SizedBox(height: 8),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(subtitle),
    ],
  );
}

/// Visual positioning aid only: never implies a detected crop or live identity.
class MuzzleGuide extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * .70,
      height: size.height * .64,
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)));
    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: .18),
    );
    final pen = Paint()
      ..color = const Color(0xffcde8b6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const arm = 22.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final sx = corner.dx < size.width / 2 ? 1.0 : -1.0;
      final sy = corner.dy < size.height / 2 ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + sx * arm, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + sy * arm),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MuzzleGuide oldDelegate) => false;
}
