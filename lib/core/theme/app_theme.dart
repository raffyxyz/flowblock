import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double contentMax = 720;
}

abstract final class AppRadius {
  static const double small = 12;
  static const double card = 18;
  static const double sheet = 24;
  static const double pill = 100;
}

abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 240);
}

@immutable
class FlowColors extends ThemeExtension<FlowColors> {
  const FlowColors({
    required this.background,
    required this.card,
    required this.heading,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
  });

  final Color background;
  final Color card;
  final Color heading;
  final Color muted;
  final Color line;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;

  @override
  FlowColors copyWith({Color? background, Color? card, Color? heading,
    Color? muted, Color? line, Color? accent, Color? accentSoft,
    Color? onAccent}) => FlowColors(
    background: background ?? this.background,
    card: card ?? this.card,
    heading: heading ?? this.heading,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    onAccent: onAccent ?? this.onAccent,
  );

  @override
  FlowColors lerp(ThemeExtension<FlowColors>? other, double t) {
    if (other is! FlowColors) return this;
    return FlowColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      heading: Color.lerp(heading, other.heading, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension FlowTheme on BuildContext {
  FlowColors get colors => Theme.of(this).extension<FlowColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

abstract final class AppTheme {
  static const Color _accent = Color(0xFF4F7EF7);
  static const FlowColors _light = FlowColors(
    background: Color(0xFFF7F8FA), card: Color(0xFFFFFFFF),
    heading: Color(0xFF1A1D24), muted: Color(0xFF6B7280),
    line: Color(0xFFE8EBF0), accent: _accent,
    accentSoft: Color(0xFFEDF2FF), onAccent: Color(0xFFFFFFFF),
  );
  static const FlowColors _dark = FlowColors(
    background: Color(0xFF101318), card: Color(0xFF1A1E26),
    heading: Color(0xFFF2F4F8), muted: Color(0xFFA3AAB8),
    line: Color(0xFF303640), accent: _accent,
    accentSoft: Color(0xFF263452), onAccent: Color(0xFFFFFFFF),
  );

  static ThemeData light() => _make(_light, Brightness.light);
  static ThemeData dark() => _make(_dark, Brightness.dark);

  static ThemeData _make(FlowColors colors, Brightness brightness) {
    final TextTheme body = GoogleFonts.interTextTheme();
    final TextTheme heading = GoogleFonts.plusJakartaSansTextTheme();
    final TextTheme typography = body.copyWith(
      displaySmall: heading.displaySmall?.copyWith(fontSize: 34, fontWeight: FontWeight.w700, height: 1.25),
      headlineMedium: heading.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.3),
      titleLarge: heading.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700, height: 1.35),
      titleMedium: heading.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
      bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: body.bodySmall?.copyWith(fontSize: 12, height: 1.5),
      labelLarge: body.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: body.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
    ).apply(bodyColor: colors.heading, displayColor: colors.heading);
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _accent, brightness: brightness,
      surface: colors.background, onSurface: colors.heading,
      primary: colors.accent, onPrimary: colors.onAccent,
    );
    return ThemeData(
      useMaterial3: true, brightness: brightness, colorScheme: scheme,
      scaffoldBackgroundColor: colors.background, textTheme: typography,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(backgroundColor: colors.background,
        foregroundColor: colors.heading, elevation: 0, scrolledUnderElevation: 0),
      dividerTheme: DividerThemeData(color: colors.line, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: colors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: colors.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: colors.line)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.card, indicatorColor: colors.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(typography.labelMedium),
        height: 72,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent, foregroundColor: colors.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: colors.card,
        shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)))),
    );
  }
}

/// Shared soft shadow for cards, resolved per brightness so dark mode stays
/// subtle. Keeps shadow definitions out of feature widgets.
abstract final class AppShadow {
  static List<BoxShadow> soft(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return <BoxShadow>[
      BoxShadow(
        color: (dark ? Colors.white : Colors.black)
            .withValues(alpha: dark ? 0.06 : 0.05),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
