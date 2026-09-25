import 'package:flutter/material.dart';

/// Bảng màu riêng, theo đúng tông ảnh mẫu (xanh lá đậm, nền trắng/xám nhạt).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.accentSoft,
    required this.warn,
    required this.warnSoft,
    required this.lateMark,
    required this.dayOffMark,
    required this.overtimeMark,
    required this.openShiftMark,
    required this.noteMark,
    required this.selectMark,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final Color ink2;
  final Color ink3;
  final Color line;
  final Color accentSoft;
  final Color warn;
  final Color warnSoft;
  final Color lateMark;
  final Color dayOffMark;
  final Color overtimeMark;
  final Color openShiftMark;
  final Color noteMark;
  final Color selectMark;
  final Color gradientStart;
  final Color gradientEnd;

  List<Color> get primaryGradient => [gradientStart, gradientEnd];

  static const light = AppColors(
    ink2: Color(0xFF52615B),
    ink3: Color(0xFF86938E),
    line: Color(0xFFE0E6E3),
    accentSoft: Color(0xFFDCEEE9),
    warn: Color(0xFFB45309),
    warnSoft: Color(0xFFFBEFD8),
    lateMark: Color(0xFFD93B3B),
    dayOffMark: Color(0xFFC0459A),
    overtimeMark: Color(0xFFE08A2B),
    openShiftMark: Color(0xFF2F8FD1),
    noteMark: Color(0xFF6E56CF),
    selectMark: Color(0xFFEF7A1A),
    gradientStart: Color(0xFF1CAE8F),
    gradientEnd: Color(0xFF2F7FE0),
  );

  static const dark = AppColors(
    ink2: Color(0xFFA4B2AC),
    ink3: Color(0xFF71807A),
    line: Color(0xFF25312D),
    accentSoft: Color(0xFF1B3A33),
    warn: Color(0xFFF2B34B),
    warnSoft: Color(0xFF3A2E14),
    lateMark: Color(0xFFF27C7C),
    dayOffMark: Color(0xFFE07AC5),
    overtimeMark: Color(0xFFF2A75E),
    openShiftMark: Color(0xFF6BB6EE),
    noteMark: Color(0xFFA694F5),
    selectMark: Color(0xFFFF9F43),
    gradientStart: Color(0xFF1F9C82),
    gradientEnd: Color(0xFF3F6FC9),
  );

  @override
  AppColors copyWith({
    Color? ink2,
    Color? ink3,
    Color? line,
    Color? accentSoft,
    Color? warn,
    Color? warnSoft,
    Color? lateMark,
    Color? dayOffMark,
    Color? overtimeMark,
    Color? openShiftMark,
    Color? noteMark,
    Color? selectMark,
    Color? gradientStart,
    Color? gradientEnd,
  }) => AppColors(
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    line: line ?? this.line,
    accentSoft: accentSoft ?? this.accentSoft,
    warn: warn ?? this.warn,
    warnSoft: warnSoft ?? this.warnSoft,
    lateMark: lateMark ?? this.lateMark,
    dayOffMark: dayOffMark ?? this.dayOffMark,
    overtimeMark: overtimeMark ?? this.overtimeMark,
    openShiftMark: openShiftMark ?? this.openShiftMark,
    noteMark: noteMark ?? this.noteMark,
    selectMark: selectMark ?? this.selectMark,
    gradientStart: gradientStart ?? this.gradientStart,
    gradientEnd: gradientEnd ?? this.gradientEnd,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      ink2: l(ink2, other.ink2),
      ink3: l(ink3, other.ink3),
      line: l(line, other.line),
      accentSoft: l(accentSoft, other.accentSoft),
      warn: l(warn, other.warn),
      warnSoft: l(warnSoft, other.warnSoft),
      lateMark: l(lateMark, other.lateMark),
      dayOffMark: l(dayOffMark, other.dayOffMark),
      overtimeMark: l(overtimeMark, other.overtimeMark),
      openShiftMark: l(openShiftMark, other.openShiftMark),
      noteMark: l(noteMark, other.noteMark),
      selectMark: l(selectMark, other.selectMark),
      gradientStart: l(gradientStart, other.gradientStart),
      gradientEnd: l(gradientEnd, other.gradientEnd),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = dark ? AppColors.dark : AppColors.light;
  final primary = dark ? const Color(0xFF4FB79F) : const Color(0xFF17695A);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: dark ? const Color(0xFF06241D) : const Color(0xFFFFFFFF),
    secondary: primary,
    onSecondary: dark ? const Color(0xFF06241D) : const Color(0xFFFFFFFF),
    secondaryContainer: colors.accentSoft,
    onSecondaryContainer: primary,
    error: dark ? const Color(0xFFF0777B) : const Color(0xFFD6404A),
    onError: dark ? const Color(0xFF2A0A0C) : const Color(0xFFFFFFFF),
    surface: dark ? const Color(0xFF161F1C) : const Color(0xFFFFFFFF),
    onSurface: dark ? const Color(0xFFE8EFEC) : const Color(0xFF17211E),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'BeVietnamPro',
    scaffoldBackgroundColor: dark ? const Color(0xFF111917) : const Color(0xFFF3F5F4),
    dividerColor: colors.line,
    extensions: [colors],
  );
}
