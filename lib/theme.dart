import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'engine/engine.dart';

class AccentOption {
  final String name;
  final Color color;
  AccentOption(this.name, this.color);
}

/// App palette. Values follow the current theme mode and accent, which
/// AppState sets before every rebuild (see main.dart).
class C {
  static bool dark = true;
  static int accentIndex = 0;

  static final List<AccentOption> accents = [
    AccentOption('Clutch orange', const Color(0xFFFF5A14)),
    AccentOption('Electric blue', const Color(0xFF3B82F6)),
    AccentOption('Mint', const Color(0xFF10B981)),
    AccentOption('Violet', const Color(0xFF8B5CF6)),
    AccentOption('Rose', const Color(0xFFF43F5E)),
  ];

  static Color get accent => accents[accentIndex.clamp(0, accents.length - 1).toInt()].color;
  static Color get bg => dark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F5);
  static Color get surface => dark ? const Color(0xFF151515) : const Color(0xFFFFFFFF);
  static Color get surface2 => dark ? const Color(0xFF1C1C1C) : const Color(0xFFEFEFEC);
  static Color get border => dark ? const Color(0xFF262626) : const Color(0xFFE2E2DE);
  static Color get text => dark ? const Color(0xFFF5F5F5) : const Color(0xFF141414);
  static Color get muted => dark ? const Color(0xFF8A8A8A) : const Color(0xFF6B6B6B);
  static Color get onAccent => Colors.white;
  static const green = Color(0xFF22C55E);
  static const yellow = Color(0xFFEAB308);
  static const red = Color(0xFFEF4444);

  static String get logoMark =>
      dark ? 'assets/images/logo_mark_dark.png' : 'assets/images/logo_mark_light.png';
  static String get wordmark =>
      dark ? 'assets/images/wordmark_dark.png' : 'assets/images/wordmark_light.png';

  static Color level(DayLevel l) => switch (l) {
        DayLevel.free => dark ? const Color(0xFF3A3A3A) : const Color(0xFFD4D4D0),
        DayLevel.smooth => green,
        DayLevel.hectic => yellow,
        DayLevel.critical => red,
      };
}

TextStyle heading(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
    GoogleFonts.spaceGrotesk(
        fontSize: size, fontWeight: weight, color: color ?? C.text, letterSpacing: -0.3);

ThemeData buildTheme() {
  final base = ThemeData(brightness: C.dark ? Brightness.dark : Brightness.light, useMaterial3: true);
  final scheme = C.dark
      ? ColorScheme.dark(
          primary: C.accent,
          secondary: C.accent,
          surface: C.surface,
          onPrimary: C.onAccent,
          onSurface: C.text,
          error: C.red,
        )
      : ColorScheme.light(
          primary: C.accent,
          secondary: C.accent,
          surface: C.surface,
          onPrimary: C.onAccent,
          onSurface: C.text,
          error: C.red,
        );
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: scheme,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: C.text,
      displayColor: C.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.surface2,
      contentTextStyle: TextStyle(color: C.text),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: C.border,
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor ?? C.border, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;
  const Pill(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class PriorityChip extends StatelessWidget {
  final double priority;
  const PriorityChip(this.priority, {super.key});

  /// P1 = most urgent.
  static int rank(double p) {
    if (p >= 0.8) return 1;
    if (p >= 0.65) return 2;
    if (p >= 0.5) return 3;
    if (p >= 0.35) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final r = rank(priority);
    final color = r == 1 ? C.accent : (r == 2 ? C.yellow : C.muted);
    return Pill('P$r', color);
  }
}

/// The CLUTCH wordmark image, in the right colour for the current theme.
class ClutchWordmark extends StatelessWidget {
  final double size;
  const ClutchWordmark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Image.asset(C.wordmark, height: size, fit: BoxFit.contain);
  }
}

class ClutchLogo extends StatelessWidget {
  final double width;
  const ClutchLogo({super.key, this.width = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset(C.logoMark, width: width, fit: BoxFit.contain);
  }
}
