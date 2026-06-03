import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppTheme — ThemeExtension holding all semantic color tokens.
//
// Access via: context.colors  (see BuildContext extension below)
//
// Dark and light palettes mirror the FocusFlight design system:
//   • Dark  → matte #0C0D10 surfaces, 60%/38% white text, warm amber accent
//   • Light → Apple-style #F2F2F7 surfaces, dark text, same amber accent
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class AppTheme extends ThemeExtension<AppTheme> {
  const AppTheme({
    required this.surf0,
    required this.surf1,
    required this.surf2,
    required this.surf3,
    required this.card,
    required this.tx1,
    required this.tx2,
    required this.tx3,
    required this.amber,
    required this.amber2,
    required this.amberSoft,
    required this.hair,
    required this.hair2,
    required this.isDark,
  });

  final Color surf0;
  final Color surf1;
  final Color surf2;
  final Color surf3;
  final Color card;
  final Color tx1;
  final Color tx2;
  final Color tx3;
  final Color amber;
  final Color amber2;
  final Color amberSoft;
  final Color hair;
  final Color hair2;
  final bool isDark;

  // ── Dark palette ───────────────────────────────────────────────────────────

  static const dark = AppTheme(
    surf0:     Color(0xFF000000),
    surf1:     Color(0xFF0C0D10),
    surf2:     Color(0xFF131519),
    surf3:     Color(0xFF191C22),
    card:      Color(0xFF16181D),
    tx1:       Color(0xFFF6F7F9),
    tx2:       Color(0x99FFFFFF), // 60%
    tx3:       Color(0x61FFFFFF), // 38%
    amber:     Color(0xFFF6A93B),
    amber2:    Color(0xFFFFC267),
    amberSoft: Color(0x29F6A93B), // 16%
    hair:      Color(0x17FFFFFF), // 9%
    hair2:     Color(0x29FFFFFF), // 16%
    isDark:    true,
  );

  // ── Light palette ──────────────────────────────────────────────────────────

  static const light = AppTheme(
    surf0:     Color(0xFFFFFFFF),
    surf1:     Color(0xFFF2F2F7), // iOS system grouped background
    surf2:     Color(0xFFFFFFFF),
    surf3:     Color(0xFFE5E5EA),
    card:      Color(0xFFFFFFFF),
    tx1:       Color(0xFF0A0B0D),
    tx2:       Color(0x99000000), // 60%
    tx3:       Color(0x61000000), // 38%
    amber:     Color(0xFFF6A93B), // accent never changes
    amber2:    Color(0xFFFFC267),
    amberSoft: Color(0x1EF6A93B), // 12%
    hair:      Color(0x14000000), // 8%
    hair2:     Color(0x24000000), // 14%
    isDark:    false,
  );

  // ── ThemeExtension API ─────────────────────────────────────────────────────

  @override
  AppTheme copyWith({
    Color? surf0,
    Color? surf1,
    Color? surf2,
    Color? surf3,
    Color? card,
    Color? tx1,
    Color? tx2,
    Color? tx3,
    Color? amber,
    Color? amber2,
    Color? amberSoft,
    Color? hair,
    Color? hair2,
    bool? isDark,
  }) {
    return AppTheme(
      surf0:     surf0     ?? this.surf0,
      surf1:     surf1     ?? this.surf1,
      surf2:     surf2     ?? this.surf2,
      surf3:     surf3     ?? this.surf3,
      card:      card      ?? this.card,
      tx1:       tx1       ?? this.tx1,
      tx2:       tx2       ?? this.tx2,
      tx3:       tx3       ?? this.tx3,
      amber:     amber     ?? this.amber,
      amber2:    amber2    ?? this.amber2,
      amberSoft: amberSoft ?? this.amberSoft,
      hair:      hair      ?? this.hair,
      hair2:     hair2     ?? this.hair2,
      isDark:    isDark    ?? this.isDark,
    );
  }

  @override
  AppTheme lerp(AppTheme? other, double t) {
    if (other == null) return this;
    return AppTheme(
      surf0:     Color.lerp(surf0,     other.surf0,     t)!,
      surf1:     Color.lerp(surf1,     other.surf1,     t)!,
      surf2:     Color.lerp(surf2,     other.surf2,     t)!,
      surf3:     Color.lerp(surf3,     other.surf3,     t)!,
      card:      Color.lerp(card,      other.card,      t)!,
      tx1:       Color.lerp(tx1,       other.tx1,       t)!,
      tx2:       Color.lerp(tx2,       other.tx2,       t)!,
      tx3:       Color.lerp(tx3,       other.tx3,       t)!,
      amber:     Color.lerp(amber,     other.amber,     t)!,
      amber2:    Color.lerp(amber2,    other.amber2,    t)!,
      amberSoft: Color.lerp(amberSoft, other.amberSoft, t)!,
      hair:      Color.lerp(hair,      other.hair,      t)!,
      hair2:     Color.lerp(hair2,     other.hair2,     t)!,
      isDark:    t < 0.5 ? isDark : other.isDark,
    );
  }
}

// ── Shorthand ──────────────────────────────────────────────────────────────────

extension AppThemeX on BuildContext {
  AppTheme get colors => Theme.of(this).extension<AppTheme>()!;
}
