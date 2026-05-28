# 세션 집중도·점수 산출 설계

날짜: 2026-05-28

## 배경

라이브 포레스트(독서 세션) 종료 후 리캡 화면은 **집중도**와 **점수**를 보여준다. 그러나:

- **집중도**: `seconds / (seconds + exitDurationSeconds)` 공식과 DB 컬럼(`exit_count`, `exit_duration_seconds`)은 이미 존재하지만, 세션 화면이 앱 이탈을 한 번도 측정하지 않아 `exitDurationSeconds`가 항상 0 → **집중도 항상 100%**.
- **점수**: `45 + 시간점수(≤40) + 문장점수(≤15)`로만 계산되어 집중도를 전혀 반영하지 않음.

향후 라이브 포레스트는 OS 레벨 기기 잠금(폰 디톡스)으로 동작할 예정이나, 현 단계에서는 **앱 백그라운드 이탈**을 신호로 삼아 구현한다. 잠금 구현 시 신호 소스만 교체하고 공식·UI는 재사용한다.

## 결정 사항

| 항목 | 결정 |
|------|------|
| 집중도 신호 | 앱 백그라운드 이탈 (이탈 횟수 + 누적 시간) |
| 앱 내 기능 | OCR/갤러리/녹음/문장작성 등으로 타이머가 `paused`일 때의 백그라운드 전환은 이탈에서 제외 |
| 점수 구성 | 시간 + 문장 + 집중도 가중합 (집중도는 곱셈 계수) |

## 설계

### 1. 이탈 측정 (집중도 입력값)

`reading_session_screen.dart`의 `didChangeAppLifecycleState`를 확장한다.

- 백그라운드 진입(`paused`/`inactive`/`hidden`/`detached`) 시점: 타이머가 `running`이면 이탈 시작 시각(`_exitStartedAt`)을 기록. 타이머가 이미 `paused`면(앱 내 기능 사용 중) **무시**.
- 복귀(`resumed`) 시점: `_exitStartedAt`이 있으면 `_exitCount++`, `_exitDurationSeconds += 경과초`, `_exitStartedAt = null`. 그 후 기존 `syncFromWallClock()` 유지.

타이머 상태(running vs paused)만으로 "진짜 이탈"과 "앱 내 기능"을 구분 → 별도 추측 로직 불필요.

이 두 값을 `_navigateToRecap`에서 `RecapData(exitCount:, exitDurationSeconds:)`로 전달한다(현재 전달 누락).

### 2. 점수 공식

```
기본점수 = 45 + 시간점수(≤40) + 문장점수(≤15)   // 0~100, 기존 그대로
집중도계수 = 0.6 + 0.4 × (집중도 / 100)          // 100%→1.0, 0%→0.6
최종점수 = (기본점수 × 집중도계수).round().clamp(0, 100)
```

근거:
- 디톡스 앱이므로 집중도가 점수에 실질 영향을 줘야 함.
- 하한 계수 0.6으로 "오래 읽었는데 점수 폭락" 좌절 방지(종인이 페르소나: 마찰·좌절 최소화).
- 곱셈 방식이라 "집중도"와 "점수"가 중복돼 보이지 않고, 점수는 종합 상위 지표가 됨.

검증 예시(이탈 없음, 1h21m, 0문장): 기본 85 × 1.0 = **85점** → 현재와 동일(회귀 없음).
중간 이탈로 집중도 70%: 85 × 0.88 = **75점**.

`_calcScore`는 집중도를 인자로 받도록 시그니처를 확장한다. 리캡 화면은 `_focusPercent`를 먼저 계산해 `_calcScore`에 전달한다.

### 3. 평가 문구

집중도가 낮을 때(예: < 70%) 폰을 내려놓도록 권하는 톤의 문구를 한 줄 더한다. 그 외에는 기존 `_evalText` 유지.

### 4. 환경 동기화

로직은 단일 코드 경로(`reading_session_screen` → `RecapData` → `session_recap_screen`)라 디자인 앱(USE_MOCK)·테스트 앱(실데이터) 양쪽에 자동 반영된다. UI는 변경 없음(기존 집중도/점수 칩 그대로). 양쪽에서 이탈 측정·점수 계산이 동일 동작하는지 확인한다.

## 영향 파일

- `lib/features/home/screen/reading_session_screen.dart` — 이탈 측정, RecapData 전달
- `lib/features/home/screen/session_recap_screen.dart` — `_calcScore` 시그니처, `_evalText`

DB/리포지토리/모델은 이미 `exit_count`/`exit_duration_seconds`를 지원하므로 변경 없음.
