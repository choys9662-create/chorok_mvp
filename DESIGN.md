# DESIGN.md — Chorok App (Airbnb-Inspired Design System)

> AI 에이전트용 디자인 시스템 문서. Flutter 코드 생성 시 이 파일을 반드시 참조하십시오.
> Airbnb의 핵심 원칙인 **따뜻함(Warmth)**, **명확성(Clarity)**, **소속감(Belonging)** 을 다크 테마 독서 앱에 적용합니다.

---

## 1. 디자인 철학 (Design Philosophy)

Airbnb 디자인의 4가지 핵심 원칙을 이 앱에 다음과 같이 번역합니다.

| Airbnb 원칙 | 이 앱에서의 표현 |
|---|---|
| **Unified** (일관된) | 모든 화면에서 동일한 토큰·컴포넌트 사용 |
| **Universal** (보편적) | 48×48px 최소 터치 영역, Semantics 필수 |
| **Iconic** (상징적) | 라임 그린(#00FF00)을 신뢰의 색으로 사용 |
| **Conversational** (대화하는) | 인터랙션마다 HapticFeedback + 애니메이션 |

---

## 2. 색상 시스템 (Color Tokens)

**절대 하드코딩 금지.** 모든 색상은 `AppTheme.*` 또는 `Theme.of(context).colorScheme.*` 을 통해서만 참조합니다.

### 브랜드 색상

```dart
// 핵심 브랜드 색 — Airbnb의 Rausch(산호색)에 대응하는 라임 그린
AppTheme.primaryLight   // #00FF00 — CTA 버튼, 선택 상태, 진행 인디케이터
AppTheme.accent         // #00CC6A — 보조 강조, 그라디언트 끝값
AppTheme.primary        // #1A3D2B — 깊은 숲 초록, 대형 배경 영역
```

### 배경 계층 (Airbnb의 표면 깊이 원칙 적용)

```
darkBg (#060B07)          ← 최하위 — 스캐폴드 배경
  └─ darkSurface (#0D1410)    ← 1단계 — 내비게이션 바, 앱바
       └─ darkCard (#131C16)      ← 2단계 — 일반 카드
            └─ darkCardElevated (#192319) ← 3단계 — 팝업, 바텀시트
```

```dart
AppTheme.darkBg             // 스캐폴드 배경
AppTheme.darkSurface        // 내비게이션, 앱바
AppTheme.darkCard           // 카드, 리스트 아이템
AppTheme.darkCardElevated   // 모달, 바텀시트 내부 요소
AppTheme.darkBorder         // 카드 테두리 (#1E3024)
```

### 텍스트 색상 (대비비 기준 준수)

```dart
AppTheme.textPrimary    // #E8F5EE — 제목, 본문 (대비비 ≥ 7:1)
AppTheme.textSecondary  // #9BC9A8 — 서브 텍스트 (대비비 ~4.6:1)
AppTheme.textTertiary   // #6A9E7A — 메타 정보, 플레이스홀더 (대비비 ~3.2:1)
```

### 상태 색상

```dart
AppTheme.warningColor   // #FF8C42 — 경고, 연속 독서 알림
Color(0xFFCF6679)       // 에러 상태
AppTheme.primaryLight   // 성공, 완료 상태
```

---

## 3. 타이포그래피 (Typography)

**서체:** `fontFamily: 'Pretendard'` 고정 (Airbnb Cereal의 인간적 가독성을 한글에서 구현)

**원칙:** 모든 `Text` 위젯에 `fontFamily: 'Pretendard'` 명시. `AppTheme.*` 스타일을 베이스로 `.copyWith()`로 변형.

### 타입 스케일

```dart
// Display — 숫자 통계, 히어로 헤드라인
AppTheme.displayLarge   // 48px Bold, height 1.0
AppTheme.displayMedium  // 28px Bold, height 1.1
AppTheme.displaySmall   // 22px Bold, height 1.1

// Heading — 섹션 제목
AppTheme.headingLarge   // 22px Bold,   height 1.2
AppTheme.headingMedium  // 18px Bold,   height 1.3
AppTheme.headingSmall   // 15px w600,   height 1.3

// Body — 본문
AppTheme.bodyLarge      // 15px Regular, height 1.5
AppTheme.bodyMedium     // 14px Regular, height 1.5
AppTheme.bodySmall      // 13px Regular, height 1.4

// Caption / Label
AppTheme.captionLarge   // 12px Regular, height 1.4
AppTheme.captionSmall   // 12px Regular, height 1.3
AppTheme.labelStyle     // 12px w600,    letterSpacing 0.5
```

### 타이포그래피 사용 예시

```dart
// 섹션 제목
Text(
  '지금 많이 기록된 문장',
  style: AppTheme.headingSmall.copyWith(
    fontFamily: 'Pretendard',
    color: AppTheme.textPrimary,
    fontWeight: FontWeight.w700,
  ),
)

// 메타 정보
Text(
  '채식주의자 · 한강',
  style: AppTheme.captionSmall.copyWith(
    fontFamily: 'Pretendard',
    color: AppTheme.textTertiary,
  ),
)
```

---

## 4. 스페이싱 시스템 (Spacing — 4px Grid)

Airbnb의 8px 그리드를 4px 배수로 세분화합니다. **4의 배수가 아닌 값(10, 15, 18 등) 사용 금지.**

```dart
AppTheme.spaceXS  =  4.0   // 아이콘–텍스트 간격, 배지 내부
AppTheme.spaceSM  =  8.0   // 관련 요소 간격
AppTheme.spaceMD  = 12.0   // 카드 내부 세부 간격
AppTheme.spaceLG  = 16.0   // 섹션 내 표준 간격
AppTheme.spaceXL  = 20.0   // 카드 패딩, 화면 여백
AppTheme.space2XL = 24.0   // 섹션 간 간격
AppTheme.space3XL = 32.0   // 대형 섹션 분리

AppTheme.screenPadding  = 20.0  // 좌우 화면 패딩 — 항상 이 값 사용
AppTheme.cardPaddingLG  = 20.0  // 히어로 카드 내부 패딩
AppTheme.cardPaddingMD  = 16.0  // 일반 카드 내부 패딩
AppTheme.sectionGap     =  8.0  // 동일 섹션 내 요소 간격
```

---

## 5. 형태 시스템 (Shape — Smooth Corners)

Airbnb의 부드럽고 친근한 모서리. `BorderRadius.circular()` 대신 **반드시 `AppTheme.smooth*()` 사용.**

```dart
// 반경 기준
AppTheme.radiusSM =  8   // 배지, 소형 태그
AppTheme.radiusMD = 12   // 칩, 버튼, 인풋
AppTheme.radiusLG = 16   // 카드 (기본값)
AppTheme.radiusXL = 20   // 히어로 카드, 대형 컨테이너

// 사용법
AppTheme.smoothBox(color: AppTheme.darkCard, radius: AppTheme.radiusLG)
AppTheme.smoothPill(color: AppTheme.primary) // 알약형
AppTheme.smoothShape(radius: AppTheme.radiusMD) // ShapeBorder 필요 시
```

---

## 6. 컴포넌트 패턴 (Component Patterns)

### 6-1. 카드 (Card)

Airbnb 리스팅 카드 원칙: **표면 깊이 + 미묘한 테두리 + 부드러운 모서리**.

```dart
Container(
  clipBehavior: Clip.antiAlias,
  decoration: AppTheme.smoothBox(
    color: AppTheme.darkCard,
    radius: AppTheme.radiusLG,
    side: BorderSide(color: AppTheme.darkBorder),
  ),
  child: ...,
)
```

- 그림자는 쓰지 않거나, 쓸 경우 `blurRadius ≥ 12`, `opacity ≤ 0.15`
- 카드 내부 패딩: `AppTheme.cardPaddingMD` (16) 또는 `AppTheme.cardPaddingLG` (20)
- 카드 간 간격: `AppTheme.spaceSM` (8) 또는 `AppTheme.spaceMD` (12)

### 6-2. 버튼 (Button)

```dart
// 주요 CTA — Airbnb의 Rausch 버튼에 대응
SizedBox(
  height: 52, // 최소 48px
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primaryLight,
      foregroundColor: Colors.black,
      shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
      textStyle: AppTheme.bodyMedium.copyWith(
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w600,
      ),
    ),
    onPressed: () {
      HapticFeedback.mediumImpact();
      // ...
    },
    child: const Text('시작하기'),
  ),
)

// 보조 버튼 — 아웃라인
OutlinedButton(
  style: OutlinedButton.styleFrom(
    side: BorderSide(color: AppTheme.darkBorder),
    shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
    foregroundColor: AppTheme.textPrimary,
  ),
  ...
)
```

### 6-3. 배지 / 태그 (Badge)

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: AppTheme.primaryLight.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
    border: Border.all(
      color: AppTheme.primaryLight.withValues(alpha: 0.2),
    ),
  ),
  child: Text(
    '라벨',
    style: AppTheme.captionSmall.copyWith(
      fontFamily: 'Pretendard',
      color: AppTheme.primaryLight,
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

### 6-4. 바텀시트 (Bottom Sheet)

Airbnb의 모달: 상단 핸들 + 부드러운 모서리 + 배경 블러 없음(성능).

```dart
showModalBottomSheet(
  context: context,
  backgroundColor: AppTheme.darkCardElevated,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(AppTheme.radiusXL),
    ),
  ),
  builder: (ctx) => Column(
    children: [
      const SizedBox(height: 12),
      // 핸들
      Container(
        width: 36, height: 4,
        decoration: BoxDecoration(
          color: AppTheme.darkBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(height: 20),
      // 콘텐츠
    ],
  ),
)
```

### 6-5. 리스트 아이템 (List Item)

반드시 `ListView.builder` 사용. 정적 Column 렌더링 금지.

```dart
ListView.builder(
  padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
  itemCount: items.length,
  itemBuilder: (context, index) => Padding(
    padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
    child: _ItemCard(item: items[index]),
  ),
)
```

### 6-6. 왼쪽 컬러 바 (Left Accent Bar)

문장 카드 등에서 책 색상을 표현할 때. **고정 height 사용 금지 — Row를 stretch로 설정.**

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.stretch, // ← 필수
  children: [
    Container(
      width: 4,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradColors,
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(child: ...),
  ],
)
```

---

## 7. 애니메이션 & 마이크로인터랙션

Airbnb의 원칙: **기능적이고 절제된 애니메이션** — 존재를 드러내지 않고 경험을 부드럽게 함.

### 기본 규칙

```dart
// 표준 진입/전환 — 200~300ms
const Duration kAnimFast   = Duration(milliseconds: 200);
const Duration kAnimNormal = Duration(milliseconds: 250);
const Duration kAnimSlow   = Duration(milliseconds: 300);

// 곡선 — 물리 기반 (선형 사용 금지)
Curves.easeOutCubic   // 등장 (감속)
Curves.easeInCubic    // 퇴장 (가속)
Curves.easeInOutCubic // 상태 전환
```

### Haptic 기준

```dart
HapticFeedback.selectionClick()  // 탭, 토글, 선택
HapticFeedback.mediumImpact()    // CTA 버튼 확인, 세션 시작
HapticFeedback.lightImpact()     // 스와이프, 드래그
HapticFeedback.heavyImpact()     // 완료, 달성, 중요 이벤트
```

### 로딩 상태 — Shimmer (스켈레톤)

빈 화면 또는 스피너 금지. 항상 내용 구조와 동일한 스켈레톤 사용.

```dart
AnimatedContainer(
  duration: kAnimNormal,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [AppTheme.darkCard, AppTheme.darkCardElevated, AppTheme.darkCard],
    ),
  ),
)
```

---

## 8. 접근성 (Accessibility)

Airbnb의 Universal 원칙: 모든 사람이 사용할 수 있는 UI.

```dart
// 모든 인터랙티브 요소에 필수
Semantics(
  label: '소년이 온다 책 상세 보기',
  button: true,
  child: GestureDetector(...),
)

// 최소 터치 영역 — 48×48px 보장
SizedBox(
  width: 48, height: 48,
  child: IconButton(icon: Icon(Icons.search), onPressed: ...),
)
```

---

## 9. 이미지 & 미디어

### 책 표지 그라디언트

이미지 없을 때 `AppTheme.coverGradients`에서 인덱스 기반으로 선택.

```dart
final gradColors = AppTheme.coverGradients[index % AppTheme.coverGradients.length];

Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradColors,
    ),
  ),
)
```

---

## 10. 상태 처리 (State Handling)

Airbnb의 모든 화면은 4가지 상태를 디자인합니다. **성공 상태만 구현하지 마십시오.**

| 상태 | 처리 방법 |
|---|---|
| **로딩** | Shimmer 스켈레톤 (스피너 금지) |
| **성공** | 데이터 표시 |
| **빈 상태** | 아이콘 + 안내 문구 + CTA 버튼 |
| **에러** | 에러 메시지 + 재시도 버튼 |

```dart
return switch (state) {
  Loading() => const _ShimmerSkeleton(),
  Success(:final data) => _DataView(data: data),
  Empty() => const _EmptyState(),
  Error(:final message) => _ErrorState(message: message),
};
```

---

## 11. 금지 사항 (Anti-Patterns)

Airbnb의 Unified 원칙 위반 목록.

```
❌ 하드코딩 색상 — Colors.red, Color(0xFF...) 직접 사용
❌ 4의 배수 아닌 스페이싱 — 10, 15, 18, 25 등
❌ fontFamily 누락 — Pretendard 명시 없는 Text 위젯
❌ 고정 height 왼쪽 바 — height: 80처럼 고정값 지정
❌ 정적 위젯에 const 누락
❌ BorderRadius.circular() 직접 사용 — AppTheme.smooth*() 대신
❌ 48px 미만 터치 영역
❌ Semantics 래핑 없는 버튼/인터랙티브 요소
❌ 로딩 상태 누락 (스피너 + 빈 화면)
❌ ListView 대신 Column + map() 으로 긴 리스트 렌더링
```

---

*이 파일은 `AppTheme` 클래스(`lib/core/theme/app_theme.dart`) 기반으로 작성되었습니다.*
*디자인 토큰 변경 시 이 파일도 함께 업데이트하십시오.*
