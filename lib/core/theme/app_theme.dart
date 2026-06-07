import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';

// ─── 테마 컨텍스트 확장 — 다크/라이트 자동 분기 ────────────────────────────
extension AppThemeExt on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;
  Color get appBg => _isDark ? AppTheme.darkBg : AppTheme.lightBg;
  Color get appSurface =>
      _isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
  Color get appCard => _isDark ? AppTheme.darkCard : AppTheme.lightCard;
  Color get appCardElevated =>
      _isDark ? AppTheme.darkCardElevated : AppTheme.lightCardElevated;
  Color get appBorder =>
      _isDark ? AppTheme.darkBorder : AppTheme.lightBorderColor;
  Color get appDivider => _isDark ? AppTheme.darkBorder : AppTheme.lightDivider;
  Color get appTextPrimary =>
      _isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
  Color get appTextSecondary =>
      _isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
  Color get appTextTertiary =>
      _isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;

  // 브랜드 초록 — 다크: 라이브 포레스트 네온, 라이트: 같은 hue를 낮춘 포레스트 라임
  Color get appPrimaryAccent =>
      _isDark ? AppTheme.primaryLight : AppTheme.lightPrimaryAccent;
  // accent 계열 — 다크: #00CC6A, 라이트: lightPrimaryAccent와 동일 톤
  Color get appAccentColor =>
      _isDark ? AppTheme.accent : AppTheme.lightPrimaryAccent;

  // 진행 바 트랙 색상 (비어 있는 구간 배경)
  Color get appProgressTrack =>
      _isDark ? const Color(0xFF2C2C2C) : const Color(0xFFD7E4D0);

  // 비활성 액션 버튼 fill (다크: #161616 / 라이트: #EAEEF2)
  Color get appActionBg =>
      _isDark ? AppTheme.darkActionBg : AppTheme.lightActionBg;

  // 비활성 컨트롤 테두리 (다크: white 12% / 라이트: #191F28 10%)
  Color get appBorderSubtle => _isDark
      ? Colors.white.withValues(alpha: 0.14)
      : const Color(0xFF191F28).withValues(alpha: 0.12);

  // 활성 버튼 배경 fill (다크: 네온그린 15% / 라이트: 포레스트 라임 12%)
  Color get appActiveFill => _isDark
      ? AppTheme.primaryLight.withValues(alpha: 0.15)
      : AppTheme.lightPrimaryAccent.withValues(alpha: 0.12);

  // pill 활성 보더 (다크: 네온그린 45% / 라이트: 포레스트 라임 45%)
  Color get appPillBorderActive => _isDark
      ? AppTheme.primaryLight.withValues(alpha: 0.45)
      : AppTheme.lightPrimaryAccent.withValues(alpha: 0.45);

  // pill 뮤트 보더 — 일시정지 상태 (다크: 네온그린 25% / 라이트: 포레스트 라임 24%)
  Color get appPillBorderMuted => _isDark
      ? AppTheme.primaryLight.withValues(alpha: 0.25)
      : AppTheme.lightPrimaryAccent.withValues(alpha: 0.24);

  // 카드 내 컨트롤(칩·입력) 배경 — 다크: elevated 카드(#1E1E1E), 라이트: 배경색 recessed(#F2F4F6)
  Color get appControlBg =>
      _isDark ? AppTheme.darkCardElevated : AppTheme.lightBg;

  // 읽기 관련 배경 틴트 — 라이트 모드는 흰 카드 위에서도 보이도록 1.5배 보상
  Color primaryBg(double alpha) => _isDark
      ? AppTheme.primaryLight.withValues(alpha: alpha)
      : AppTheme.lightPrimaryAccent.withValues(
          alpha: (alpha * 1.5).clamp(0, 1),
        );

  // 읽기 관련 진행 그라디언트 — 라이브 포레스트 키 컬러 기반
  Gradient get appReadingGradient => _isDark
      ? AppTheme.greenGradient
      : const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppTheme.lightPrimaryAccent, AppTheme.accent],
        );
}

/// 초록 앱 테마 정의
class AppTheme {
  static const String fontFamily = 'ChosunGu';

  // ─── 브랜드 색상 팔레트 ───────────────────────────────────────────
  static const Color primary = Color(0xFF131313); // 어두운 배경 (CTA 버튼 fill 등)
  static const Color primaryLight = Color(0xFF8DFF54); // 다크 모드 브랜드 네온 그린
  static const Color accent = Color(0xFF6DE034); // 보조 강조 (그라디언트 끝값)
  static const Color fireflyColor = Color(0xFF8DFF54); // 반딧불 이펙트 전용
  static const Color warningColor = Color(0xFFFF8C42); // 경고/연속 독서
  static const Color empathyColor = Color(0xFFFF6B6B); // 공감/좋아요 하트

  // ─── 그린 그라디언트 ─────────────────────────────────────────────
  /// #8DFF54 → #6DE034: 네온 그린 그라디언트
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8DFF54), Color(0xFF6DE034)],
  );
  static const LinearGradient greenGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF8DFF54), Color(0xFF6DE034)],
  );

  /// 카드/배경에 쓸 어두운 그린 그라디언트
  static const LinearGradient greenCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF132A13), Color(0xFF0D1A0D)],
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
  static const Color darkBg = Colors.black;
  static const Color darkSurface = Color(0xFF0B0D0B);
  static const Color darkCard = Color(0xFF111411);
  static const Color darkCardElevated = Color(0xFF1B211B);
  static const Color darkActionBg = Color(0xFF161616); // 비활성 액션 버튼 fill (다크)
  static const Color darkBorder = Color(0x3D8DFF54); // 네온 그린 투명 테두리
  static const Color darkPrimaryContainer = Color(0xFF132A13);
  static const Color primaryPaused = Color(0xFF2A7A3D); // 일시정지/뮤트 그린 (다크 전용)

  // ─── 라이트 배경 (Toss 스타일 — DESIGN.md §1) ────────────────────
  static const Color lightBg = Color(0xFFEEF3EC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = Color(0xFFF7FAF5);
  static const Color lightActionBg = Color(0xFFEAEEF2); // 비활성 액션 버튼 fill (라이트)
  static const Color lightPrimaryContainer = Color(0xFFE7F4DE);
  static const Color receiptBg = Color(0xFFF9F7F1); // 공유 카드/영수증 배경 (모드 무관)

  // ─── 다크 텍스트 색상 토큰 ──────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8C2B2);
  static const Color textTertiary = Color(0xFF7D8878);

  // ─── 라이트 텍스트 색상 토큰 ─────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF3F4D38);
  static const Color lightTextTertiary = Color(0xFF5F6D5A);
  static const Color lightBorderColor = Color(0xFFC5D8BD);
  static const Color lightDivider = Color(0xFFD8E7D2);

  // 라이트 모드 전용 브랜드 초록 — #8DFF54/#6DE034와 같은 라임 hue를 접근성 대비까지 낮춘 값
  static const Color lightPrimaryAccent = Color(0xFF347A12);

  // 라이트 모드 카드 그림자
  static const List<BoxShadow> lightCardShadows = [
    BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x14000000)),
  ];

  // ─── Smooth Corner — 곡률 전체 통일: radius 10 / smoothing 0.6 ──────
  //   기존 계층(SM 8 / MD 12 / LG 18 / XL 24)은 단일 값 10으로 통일.
  //   토큰명은 호환을 위해 유지하되 모두 10을 가리킨다.
  static const double _smoothness = 0.6;

  static const double radiusSM = 10;
  static const double radiusMD = 10;
  static const double radiusLG = 10;
  static const double radiusXL = 10;

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
        smoothness: _smoothness,
        borderRadius: BorderRadius.circular(radius),
        side: side,
      ),
    );
  }

  /// (구) 알약형 — 곡률 통일 정책에 따라 radius 10 smooth rect 로 통일.
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
      shape: SmoothRectangleBorder(
        smoothness: _smoothness,
        borderRadius: BorderRadius.circular(radiusMD),
        side: side,
      ),
    );
  }

  /// 버튼/카드 shape 용
  static OutlinedBorder smoothShape({
    double radius = radiusLG,
    BorderSide side = BorderSide.none,
  }) {
    return SmoothRectangleBorder(
      smoothness: _smoothness,
      borderRadius: BorderRadius.circular(radius),
      side: side,
    );
  }

  /// ClipPath 용 — Container 안에서 gradient + smooth corner 조합 시
  static ShapeBorder smoothBorder(double radius) {
    return SmoothRectangleBorder(
      smoothness: _smoothness,
      borderRadius: BorderRadius.circular(radius),
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
  // 타입 스케일은 5단계뿐 — 강조 30 / 제목 24 / 본문 16 / 작은본문 12 / 캡션 10.
  // 위계는 크기로만 만든다(두께 임의 추가 금지) → 모든 토큰 단일 두께 w400.
  // 30pt 초과는 텍스트가 아닌 디스플레이 수치(타이머·통계 숫자·페이지)에만 허용.
  // 참고: wiki/analyses/타이포그래피-규칙.md
  static const FontWeight _w = FontWeight.w400;

  // 강조 30 / 제목 24 / 본문 16 / 작은본문 12 / 캡션 10 (semantic 별칭)
  static const TextStyle emphasis = TextStyle(
    fontSize: 30,
    fontWeight: _w,
    height: 1.2,
  );
  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: _w,
    height: 1.2,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: _w,
    height: 1.5,
  );

  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: _w,
    height: 1.2,
  );
  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: _w,
    height: 1.3,
  );
  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: _w,
    height: 1.3,
  );
  // 통계 hero 숫자 등 대형 디스플레이 수치 전용 (텍스트 아님, 스케일 예외)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: _w,
    height: 1.0,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 30,
    fontWeight: _w,
    height: 1.1,
  );
  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: _w,
    height: 1.1,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: _w,
    height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: _w,
    height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: _w,
    height: 1.4,
  );
  static const TextStyle captionLarge = TextStyle(
    fontSize: 12,
    fontWeight: _w,
    height: 1.4,
  );
  static const TextStyle captionSmall = TextStyle(
    fontSize: 10,
    fontWeight: _w,
    height: 1.3,
  );
  static const TextStyle labelStyle = TextStyle(
    fontSize: 10,
    fontWeight: _w,
    letterSpacing: 0.5,
  );

  // ─── 다크 테마 ───────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    fontFamily: fontFamily,
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: primaryLight,
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF1B5E20),
      onPrimaryContainer: primaryLight,
      secondary: accent,
      onSecondary: Colors.black,
      tertiary: fireflyColor,
      onTertiary: Colors.black,
      error: Color(0xFFCF6679),
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
      shape: smoothShape(
        radius: 10,
        side: const BorderSide(color: darkBorder, width: 1),
      ),
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
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
    ),
    dividerColor: Colors.transparent,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCardElevated,
      hintStyle: captionLarge.copyWith(color: textTertiary),
      labelStyle: captionLarge.copyWith(color: textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: primaryLight, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: Colors.black,
        textStyle: captionLarge.copyWith(fontWeight: FontWeight.w400),
        shape: smoothShape(radius: radiusMD),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryLight,
        textStyle: captionLarge.copyWith(fontWeight: FontWeight.w400),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkSurface,
      labelStyle: captionLarge.copyWith(color: textSecondary),
      shape: smoothShape(
        radius: radiusMD,
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkBorder,
      thickness: 1,
      space: 1,
    ),
  );

  // ─── 라이트 테마 ─────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    fontFamily: fontFamily,
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimaryAccent,
      onPrimary: Colors.white,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: Color(0xFF1B5E20),
      secondary: lightPrimaryAccent,
      onSecondary: Colors.white,
      tertiary: lightPrimaryAccent,
      onTertiary: Colors.white,
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
        radius: 10,
        side: const BorderSide(color: lightBorderColor, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightSurface,
      indicatorColor: Colors.transparent,
      height: 60,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return labelStyle.copyWith(color: lightPrimaryAccent);
        }
        return captionSmall.copyWith(color: lightTextTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: lightPrimaryAccent);
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
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: lightTextPrimary,
      ),
    ),
    dividerColor: lightDivider,
    dividerTheme: const DividerThemeData(
      color: lightDivider,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      hintStyle: captionLarge.copyWith(color: lightTextTertiary),
      labelStyle: captionLarge.copyWith(color: lightTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: lightBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: lightBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: lightPrimaryAccent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: lightPrimaryAccent,
        foregroundColor: Colors.white,
        textStyle: captionLarge.copyWith(fontWeight: FontWeight.w400),
        shape: smoothShape(radius: radiusMD),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lightPrimaryAccent,
        textStyle: captionLarge.copyWith(fontWeight: FontWeight.w400),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: lightCard,
      labelStyle: captionLarge.copyWith(color: lightTextSecondary),
      shape: smoothShape(radius: radiusMD),
    ),
  );
}
