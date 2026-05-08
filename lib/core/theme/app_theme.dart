import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

// ─── 테마 컨텍스트 확장 — 다크/라이트 자동 분기 ────────────────────────────
extension AppThemeExt on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;
  Color get appBg => _isDark ? AppTheme.darkBg : AppTheme.lightBg;
  Color get appSurface =>
      _isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
  Color get appCard => _isDark ? AppTheme.darkCard : AppTheme.lightCard;
  Color get appCardElevated =>
      _isDark ? AppTheme.darkCardElevated : AppTheme.lightSurface;
  Color get appBorder =>
      _isDark ? AppTheme.darkBorder : AppTheme.lightBorderColor;
  Color get appDivider => _isDark ? AppTheme.darkBorder : AppTheme.lightDivider;
  Color get appTextPrimary =>
      _isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
  Color get appTextSecondary =>
      _isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
  Color get appTextTertiary =>
      _isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;

  // 브랜드 초록 — 다크: 네온 그린(#00FF00), 라이트: 접근성 보장 딥 그린(#1B7A3A)
  Color get appPrimaryAccent =>
      _isDark ? AppTheme.primaryLight : AppTheme.lightPrimaryAccent;
  // accent 계열 — 다크: #00CC6A, 라이트: lightPrimaryAccent와 동일 톤
  Color get appAccentColor =>
      _isDark ? AppTheme.accent : AppTheme.lightPrimaryAccent;

  // 읽기 관련 배경 틴트 — #009B58 라이트 모드에서 1.5배 보상
  Color primaryBg(double alpha) => _isDark
      ? AppTheme.primaryLight.withValues(alpha: alpha)
      : AppTheme.lightPrimaryAccent.withValues(alpha: (alpha * 1.5).clamp(0, 1));

  // 읽기 관련 진행 그라디언트 — DESIGN.md Primary Green 기반
  Gradient get appReadingGradient => _isDark
      ? AppTheme.greenGradient
      : const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF009B58), Color(0xFF00C870)],
        );
}

/// 초록 앱 테마 정의
class AppTheme {
  // ─── 브랜드 색상 팔레트 ───────────────────────────────────────────
  static const Color primary = Color(0xFF1A3D2B); // 어두운 숲 초록 (CTA 버튼 fill)
  static const Color primaryLight = Color(0xFF10B981); // 다크 모드 브랜드 에메랄드
  static const Color accent = Color(0xFF059669); // 보조 강조 (그라디언트 끝값)
  static const Color fireflyColor = Color(0xFF00FF00); // 반딧불 이펙트 전용
  static const Color warningColor = Color(0xFFFF8C42); // 경고/연속 독서

  // ─── 그린 그라디언트 ─────────────────────────────────────────────
  /// #10B981 → #059669: 에메랄드 그린 그라디언트
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );
  static const LinearGradient greenGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  /// 카드/배경에 쓸 어두운 그린 그라디언트
  static const LinearGradient greenCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A4D2E), Color(0xFF0D2B18)],
  );

  // ─── 책 표지 그라디언트 팔레트 ──────────────────────────────────────
  /// home_screen / explore_screen 공용 — 책 표지 그라디언트
  static const List<List<Color>> coverGradients = [
    [Color(0xFF1A4D2E), Color(0xFF00CC6A)],
    [Color(0xFF0D3D2B), Color(0xFF00A86B)],
    [Color(0xFF163B30), Color(0xFF00BF7A)],
    [Color(0xFF0A3320), Color(0xFF009955)],
    [Color(0xFF1E4A35), Color(0xFF00D47A)],
    [Color(0xFF112D22), Color(0xFF00B36B)],
    [Color(0xFF0E3828), Color(0xFF00C880)],
    [Color(0xFF184230), Color(0xFF00E090)],
  ];

  /// 문자열 키 → 책 표지 그라디언트 (hashCode 기반 안정 매핑)
  static List<Color> coverGradientFor(String key) =>
      coverGradients[key.hashCode.abs() % coverGradients.length];

  /// 인덱스 → 책 표지 그라디언트 (음수/오버플로우 안전)
  static List<Color> coverGradientByIndex(int index) =>
      coverGradients[index.abs() % coverGradients.length];

  // ─── 다크 배경 (중립 다크 — DESIGN.md §1) ──────────────────────
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color darkCardElevated = Color(0xFF222222);
  static const Color darkBorder = Color(0xFF2C2C2C);
  static const Color darkPrimaryContainer = Color(0xFF1E3A2F);

  // ─── 라이트 배경 (Toss 스타일 — DESIGN.md §1) ────────────────────
  static const Color lightBg = Color(0xFFF2F4F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFE6F5ED);

  // ─── 다크 텍스트 색상 토큰 ──────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFADADAD);
  static const Color textTertiary = Color(0xFF6B6B6B);

  // ─── 라이트 텍스트 색상 토큰 ─────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF191F28);
  static const Color lightTextSecondary = Color(0xFF8B95A1);
  static const Color lightTextTertiary = Color(0xFFB0B8C1);
  static const Color lightBorderColor = Color(0xFFE5E8EB);
  static const Color lightDivider = Color(0xFFE5E8EB);

  // 라이트 모드 전용 브랜드 초록 — DESIGN.md §1 Primary Green
  static const Color lightPrimaryAccent = Color(0xFF009B58);

  // ─── Smooth Corner — DESIGN.md §2 Radius Hierarchy ──────────────
  //   radiusSM  =  8  → 태그, 작은 아이콘 배경 (Small)
  //   radiusMD  = 12  → 표준 버튼, 검색창, ListTile (Medium)
  //   radiusLG  = 18  → 콘텐츠 박스, 히어로 섹션 (Large)
  //   radiusXL  = 24  → 메인 컨테이너, 바텀 시트 (XL)
  static const double _smoothness = 1;

  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 18;
  static const double radiusXL = 24;

  /// BoxDecoration 대체용 — color, gradient, border, shadow 모두 지원
  static ShapeDecoration smoothBox({
    Color? color,
    Gradient? gradient,
    double radius = radiusLG,
    BorderSide side = BorderSide.none,
    List<BoxShadow>? shadows,
  }) {
    return ShapeDecoration(
      color: color,
      gradient: gradient,
      shadows: shadows,
      shape: SmoothRectangleBorder(
        borderRadius: SmoothBorderRadius(
          cornerRadius: radius,
          cornerSmoothing: _smoothness,
        ),
        side: side,
      ),
    );
  }

  /// 알약형(Pill) 전용 — 높이에 관계없이 완벽한 라운드 양끝
  static ShapeDecoration smoothPill({
    Color? color,
    Gradient? gradient,
    BorderSide side = BorderSide.none,
    List<BoxShadow>? shadows,
  }) {
    return ShapeDecoration(
      color: color,
      gradient: gradient,
      shadows: shadows,
      shape: StadiumBorder(side: side),
    );
  }

  /// 버튼/카드 shape 용
  static OutlinedBorder smoothShape({
    double radius = radiusLG,
    BorderSide side = BorderSide.none,
  }) {
    return SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius(
        cornerRadius: radius,
        cornerSmoothing: _smoothness,
      ),
      side: side,
    );
  }

  /// ClipPath 용 — Container 안에서 gradient + smooth corner 조합 시
  static ShapeBorder smoothBorder(double radius) {
    return SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius(
        cornerRadius: radius,
        cornerSmoothing: _smoothness,
      ),
    );
  }

  // ─── 스페이싱 토큰 ───────────────────────────────────────────────
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 12.0;
  static const double spaceLG = 16.0;
  static const double spaceXL = 20.0;
  static const double space2XL = 24.0;
  static const double space3XL = 32.0;
  static const double screenPadding = 20.0;
  static const double sectionGap = 8.0;
  static const double cardPaddingLG = 20.0;
  static const double cardPaddingMD = 16.0;

  // ─── 타이포그래피 토큰 ───────────────────────────────────────────
  static const TextStyle headingLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );
  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );
  static const TextStyle headingSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    height: 1.0,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.1,
  );
  static const TextStyle displaySmall = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.1,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );
  static const TextStyle captionLarge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );
  static const TextStyle captionSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.3,
  );
  static const TextStyle labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ─── 다크 테마 ───────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: primaryLight,
      onPrimary: Colors.black,
      secondary: accent,
      onSecondary: Colors.black,
      tertiary: fireflyColor,
      onTertiary: Colors.black,
      error: const Color(0xFFCF6679),
      onError: Colors.black,
      surface: darkSurface,
      onSurface: textPrimary,
      surfaceContainerHighest: darkCard,
      outline: darkBorder,
    ),
    scaffoldBackgroundColor: darkBg,
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: smoothShape(radius: 16, side: const BorderSide(color: darkBorder)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurface,
      indicatorColor: Colors.transparent,
      height: 60,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return labelStyle.copyWith(color: primaryLight);
        }
        return captionSmall.copyWith(color: textTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryLight);
        }
        return IconThemeData(color: textTertiary);
      }),
      elevation: 0,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    ),
    dividerColor: darkBorder,
    chipTheme: ChipThemeData(
      backgroundColor: darkCard,
      labelStyle: captionLarge.copyWith(color: textSecondary),
      shape: const StadiumBorder(),
    ),
  );

  // ─── 라이트 테마 ─────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: primaryLight,
      onSecondary: Colors.black,
      tertiary: accent,
      onTertiary: Colors.black,
      error: Color(0xFFB00020),
      onError: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightCard,
      outline: lightBorderColor,
    ),
    scaffoldBackgroundColor: lightBg,
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      shape: smoothShape(
        radius: radiusLG,
        side: const BorderSide(color: lightBorderColor),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightSurface,
      indicatorColor: Colors.transparent,
      height: 60,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return labelStyle.copyWith(color: primary);
        }
        return captionSmall.copyWith(color: lightTextTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primary);
        }
        return const IconThemeData(color: lightTextTertiary);
      }),
      elevation: 0,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBg,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: lightTextPrimary,
      ),
    ),
    dividerColor: lightDivider,
    chipTheme: ChipThemeData(
      backgroundColor: lightCard,
      labelStyle: captionLarge.copyWith(color: lightTextSecondary),
      shape: const StadiumBorder(),
    ),
  );
}
