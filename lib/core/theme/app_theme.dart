import 'package:flutter/material.dart';

/// 초록 앱 테마 정의
class AppTheme {
  // ─── 브랜드 색상 팔레트 ───────────────────────────────────────────
  static const Color primary = Color(0xFF1A3D2B); // 어두운 숲 초록 (배경/버튼)
  static const Color primaryLight = Color(0xFF00FF00); // 핵심 컬러 — 라임 그린
  static const Color accent = Color(0xFF00CC6A); // 보조 강조 (그라디언트 끝값)
  static const Color fireflyColor = Color(0xFF00FF00); // 반딧불 색상
  static const Color warningColor = Color(0xFFFF8C42); // 경고/연속 독서

  // ─── 그린 그라디언트 ─────────────────────────────────────────────
  /// #00FF00 → #00CC6A: 네온 그린의 쨍함을 그라디언트로 완화
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00FF00), Color(0xFF00CC6A)],
  );
  static const LinearGradient greenGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF00FF00), Color(0xFF00CC6A)],
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

  // ─── 다크 배경 ───────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF060B07);
  static const Color darkSurface = Color(0xFF0D1410);
  static const Color darkCard = Color(0xFF131C16);
  static const Color darkCardElevated = Color(0xFF192319);
  static const Color darkBorder = Color(0xFF1E3024);

  // ─── 라이트 배경 ─────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF0FAF4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFE8F5EE);

  // ─── 텍스트 색상 토큰 ────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE8F5EE);
  static const Color textSecondary = Color(0xFF9BC9A8); // 대비비 ~4.6:1 on darkCard
  static const Color textTertiary = Color(0xFF6A9E7A);  // 대비비 ~3.2:1 on darkCard

  // ─── Smooth Corner (Squircle) ──────────────────────────────────
  // Apple / Figma "부드러운 모서리" — ContinuousRectangleBorder 기반
  // 배율 1.35: 정r 대비 미세하게 부드러운 수준 (Apple 스타일)
  //
  // 디자인 라운드 규칙 (4px 배수):
  //   radiusSM  =  8  → 배지, 작은 알약형 요소
  //   radiusMD  = 12  → 칩, 버튼, 인풋 필드
  //   radiusLG  = 16  → 카드, 일반 컨테이너 (기본값)
  //   radiusXL  = 20  → 히어로 카드, 대형 컨테이너
  static const double _smoothK = 1.8;

  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;
  static const double radiusXL = 20;

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
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(radius * _smoothK),
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
  static ContinuousRectangleBorder smoothShape({
    double radius = radiusLG,
    BorderSide side = BorderSide.none,
  }) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius * _smoothK),
      side: side,
    );
  }

  /// ClipPath 용 — Container 안에서 gradient + smooth corner 조합 시
  static ShapeBorder smoothBorder(double radius) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius * _smoothK),
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
    fontFamily: 'Pretendard',
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
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: const Color(0xFF1A3D2B),
      onPrimary: Colors.white,
      secondary: primaryLight,
      onSecondary: Colors.black,
      tertiary: accent,
      onTertiary: Colors.black,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      surface: lightSurface,
      onSurface: const Color(0xFF1A2D24),
      surfaceContainerHighest: lightCard,
      outline: const Color(0xFFB8D9C6),
    ),
    scaffoldBackgroundColor: lightBg,
  );
}
