import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';

// ─── 테마 컨텍스트 확장 ─────────────────────────────────────────────
// 라이트 테마 색상은 추후 확정 예정 — 현재는 다크 고정(ThemeMode.dark).
extension AppThemeExt on BuildContext {
  Color get appBg => AppTheme.darkBg;
  Color get appSurface => AppTheme.darkSurface;
  Color get appCard => AppTheme.darkCard;
  Color get appCardElevated => AppTheme.darkCardElevated;
  Color get appBorder => AppTheme.darkBorder;
  Color get appDivider => AppTheme.darkDivider;
  Color get appTextPrimary => AppTheme.textPrimary;
  Color get appTextSecondary => AppTheme.textSecondary;
  Color get appTextTertiary => AppTheme.textTertiary;

  Color get appPrimaryAccent => AppTheme.primaryLight;
  Color get appAccentColor => AppTheme.accent;

  // 진행 바 트랙 색상 (비어 있는 구간 배경)
  Color get appProgressTrack => AppTheme.darkCardElevated;

  // 비활성 액션 버튼 fill
  Color get appActionBg => AppTheme.darkActionBg;

  // 비활성 컨트롤 테두리
  Color get appBorderSubtle => AppTheme.darkBorder;

  // 활성 버튼 배경 fill (네온그린 15%)
  Color get appActiveFill => AppTheme.primaryLight.withValues(alpha: 0.15);

  // pill 활성 보더 (네온그린 45%)
  Color get appPillBorderActive =>
      AppTheme.primaryLight.withValues(alpha: 0.45);

  // pill 뮤트 보더 — 일시정지 상태 (네온그린 25%)
  Color get appPillBorderMuted => AppTheme.primaryLight.withValues(alpha: 0.25);

  // 카드 내 컨트롤(칩·입력) 배경
  Color get appControlBg => AppTheme.darkCardElevated;

  Color primaryBg(double alpha) =>
      AppTheme.primaryLight.withValues(alpha: alpha);

  // 읽기 관련 진행 그라디언트 — 라이브 포레스트 키 컬러 기반
  Gradient get appReadingGradient => AppTheme.greenGradient;
}

/// 초록 앱 테마 정의
class AppTheme {
  static const String fontFamily = 'ChosunGu';

  // ─── 브랜드 색상 팔레트 ───────────────────────────────────────────
  static const Color primary = Color(0xFF000000); // 배경
  static const Color primaryLight = Color(0xFF8DFF54); // 다크 모드 브랜드 네온 그린
  static const Color accent = Color(0xFF8DFF54); // 메인 그린
  static const Color fireflyColor = Color(0xFF8DFF54); // 반딧불 이펙트 전용
  // TODO: 팔레트 위반, design.md §4
  static const Color warningColor = Color(0xFFFF8C42); // 경고/연속 독서
  // TODO: 팔레트 위반, design.md §4
  static const Color empathyColor = Color(0xFFFF6B6B); // 공감/좋아요 하트

  // ─── 그린 그라디언트 ─────────────────────────────────────────────
  /// 메인 그린 그라디언트
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryLight],
  );
  static const LinearGradient greenGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryLight, primaryLight],
  );

  /// 카드/배경에 쓸 박스 그라디언트
  static const LinearGradient greenCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkCard, darkCard],
  );

  // ─── 책 표지 그라디언트 팔레트 ──────────────────────────────────────
  /// home_screen / explore_screen 공용 — 책 표지 그라디언트
  // TODO: 팔레트 위반, design.md §4
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

  // ─── 다크 배경 — design.md §4의 여섯 색 팔레트만 사용 ────────────
  static const Color darkBg = primary;
  static const Color darkSurface = darkCard;
  static const Color darkCard = Color(0xFF141614);
  static const Color darkNested = Color(0xFF222422);
  static const Color darkCardElevated = darkNested;
  static const Color darkActionBg = darkNested; // 비활성 액션 버튼 fill (다크)
  static const Color darkBorder = darkNested;
  static const Color darkDivider = darkNested;
  static const Color darkPrimaryContainer = darkNested;
  static const Color primaryPaused = Color(0x408DFF54); // 메인 그린 25% opacity

  static const Color receiptBg = Color(0xFFF9F7F1); // 공유 카드/영수증 배경 (모드 무관)

  // ─── 텍스트 색상 토큰 ──────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1FFF2);
  static const Color textSecondary = Color(0xFF7B847C);
  static const Color textTertiary = Color(0xFF7B847C);

  // ─── Smooth Corner — 바깥 10 / 중첩 6, smoothing 0.6 ──────────────
  //   기존 토큰명은 호환을 위해 유지한다.
  static const double _smoothness = 0.6;

  /// 이 둘만 고치면 앱 전체 곡률이 바뀐다. 나머지는 전부 별칭이다.
  static const double radiusOuter = 10;
  static const double radiusInner = 6;

  static const double radiusSM = radiusInner;
  static const double radiusMD = radiusOuter;
  static const double radiusLG = radiusOuter;
  static const double radiusXL = radiusOuter;

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
  static const double spaceXL = 24.0;
  static const double space2XL = 24.0;
  static const double space3XL = 30.0;
  static const double screenPadding = 16.0;
  static const double sectionGap = 30.0;
  static const double recommendedBookGridGap = 6.0;

  /// 바깥 카드 안에 중첩된 inner 박스의 여백.
  static const double cardPaddingInner = 6.0;
  static const double cardPaddingLG = 16.0;
  static const double cardPaddingMD = 16.0;
  static const double touchTarget = 48.0;
  static const double iconMD = 20.0;

  /// 라이브 포레스트 반딧불 크기. 내 반딧불은 화면 폭에 비례해 이전 중앙
  /// 오브보다 조금 작게 시작하고, 독서 시간에 따라 기존 최대 크기까지 자란다.
  /// 중앙 '나' orb만 절대값(성장 전 기본 반경, px). 나머지는 전부 이 값의 비례.
  static const double orbSelfBaseRadius = 24.0;

  /// 나 대비 비율. 친구 = 나의 75%, 이웃(익명) = 나의 60%.
  /// 친구는 여기에 독서시간 성장배율(growthScale)이 더 곱해지고, 이웃은 성장 없음.
  static const double orbFriendRatio = 0.75;
  static const double orbNeighborRatio = 0.60;

  /// 책 정보 화면 히어로 표지. 접힌 헤더 안에서 크기와 위치를 보간한다.
  static const Size bookInfoCoverExpandedSize = Size(168, 244);
  static const Size bookInfoCoverPulledSize = Size(184, 268);
  static const Size bookInfoCoverCollapsedSize = Size(28, 40);
  static const double bookInfoCoverStretchDistance = 72;

  // ─── 타이포그래피 토큰 ───────────────────────────────────────────
  // 일반 타입 스케일은 30 / 18 / 16 / 14 / 12 / 10의 여섯 단계다.
  // 위계는 크기로만 만든다(두께 임의 추가 금지) → 모든 토큰 단일 두께 w400.
  // 30pt 초과는 텍스트가 아닌 디스플레이 수치(타이머·통계 숫자·페이지)에만 허용한다.
  // 참고: wiki/analyses/타이포그래피-규칙.md
  static const FontWeight _w = FontWeight.w400;
  // 자간: fontSize × -0.04 (각 TextStyle의 letterSpacing은 이 공식으로 산출)

  // 여섯 단계 크기 상수 — const TextStyle 안에서 크기 토큰을 참조할 때 사용한다.
  // (TextStyle.fontSize 게터는 const 컨텍스트에서 못 쓰므로 이 double 상수를 쓴다.)
  static const double fsScreenTitle = 30;
  static const double fsSectionTitle = 18;
  static const double fsRowText = 16;
  static const double fsBody = 14;
  static const double fsSupporting = 12;
  static const double fsCaption = 10;

  static const TextStyle screenTitle = TextStyle(
    fontSize: 30,
    fontWeight: _w,
    height: 1.2,
    letterSpacing: -1.2,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: _w,
    height: 1.3,
    letterSpacing: -0.72,
  );
  static const TextStyle rowText = TextStyle(
    fontSize: 16,
    fontWeight: _w,
    height: 1.3,
    letterSpacing: -0.64,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: _w,
    height: 1.5,
    letterSpacing: -0.56,
  );
  static const TextStyle supportingText = TextStyle(
    fontSize: 12,
    fontWeight: _w,
    height: 1.4,
    letterSpacing: -0.48,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: _w,
    height: 1.3,
    letterSpacing: -0.4,
  );

  // 기존 이름은 여섯 단계 토큰의 별칭으로 유지한다.
  static const TextStyle emphasis = screenTitle;
  static const TextStyle title = screenTitle;
  static const TextStyle headingLarge = screenTitle;
  static const TextStyle headingMedium = sectionTitle;
  static const TextStyle headingSmall = rowText;
  static const TextStyle displayLarge = screenTitle;
  static const TextStyle displayMedium = TextStyle(
    fontSize: 30,
    fontWeight: _w,
    height: 1.1,
    letterSpacing: -1.2,
  );
  static const TextStyle displaySmall = sectionTitle;
  static const TextStyle bodyLarge = rowText;
  static const TextStyle bodyMedium = body;
  static const TextStyle bodySmall = supportingText;
  static const TextStyle captionLarge = supportingText;
  static const TextStyle captionSmall = caption;
  static const TextStyle labelStyle = caption;

  // ─── 다크 테마 ───────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    fontFamily: fontFamily,
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: primaryLight,
      onPrimary: primary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: primaryLight,
      secondary: accent,
      onSecondary: primary,
      tertiary: fireflyColor,
      onTertiary: primary,
      error: warningColor,
      onError: primary,
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
        radius: radiusOuter,
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
    appBarTheme: AppBarTheme(
      backgroundColor: darkBg,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: sectionTitle.copyWith(color: textPrimary),
    ),
    dividerColor: darkDivider,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCardElevated,
      hintStyle: captionLarge.copyWith(color: textTertiary),
      labelStyle: captionLarge.copyWith(color: textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInner),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInner),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInner),
        borderSide: const BorderSide(color: primaryLight, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: primary,
        textStyle: captionLarge.copyWith(fontWeight: FontWeight.w400),
        shape: smoothShape(radius: radiusOuter),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryLight,
        textStyle: captionLarge.copyWith(fontWeight: FontWeight.w400),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkCardElevated,
      labelStyle: captionLarge.copyWith(color: textSecondary),
      shape: smoothShape(
        radius: radiusInner,
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkDivider,
      thickness: 1,
      space: 1,
    ),
  );
}
