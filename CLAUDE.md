Flutter UI/UX 다중 에이전트 하네스 v2.2
Planner → Generator → Evaluator 3단계 파이프라인. 모든 에이전트는 DESIGN.md를 유일한 시각적·구현 기준으로 사용한다. DESIGN.md는 에이전트가 직접 갱신하는 살아있는 문서다. CLAUDE.md 자체는 수정 불가.

1. Planner (초기화)
작업 시작 전 DESIGN.md 전체(특히 §13 안티패턴, §14 변경 이력)를 읽는다.

feature_list.json 작성 — 기능을 항목별로 분해, 초기값 "passes": false
claude-progress.txt 생성 — Generator의 첫 작업 명시
새 UI/UX 규칙 파일을 임의로 만들지 않는다. 모든 규칙은 DESIGN.md에만 존재한다.

사용자가 디자인 변경을 요청하면 코드 수정 전에 먼저:

DESIGN.md 관련 섹션 수정
§14 변경 이력 추가
§15 버전 업


2. Generator (구현)

claude-progress.txt → feature_list.json → DESIGN.md(§13 포함) 순서로 읽는다.
"passes": false인 최우선 기능 하나만 구현한다.
구현 규칙:

하드코딩 금지 — 색상·수치는 반드시 ChorokColors / ChorokMetrics / ChorokTypography / ChorokShapes 경유
BorderRadius.circular() 직접 호출 금지 → ChorokShapes.smooth*() 사용
4단계 상태(로딩 Shimmer / 성공 / 빈 상태 / 에러)를 switch로 분기 (§10 참조)
버튼: 48×48px 터치 영역 + Semantics + HapticFeedback + ChorokAnimations.kAnimNormal
Presentation / Logic 계층 분리, 정적 위젯에 const 적용


완료 후 claude-progress.txt 업데이트.


3. Evaluator (검증)
위반 항목이 하나라도 있으면 즉시 반려 + 에러 리포트 작성. 통과 시 "passes": true.
검증 체크리스트:

 4의 배수가 아닌 하드코딩 패딩/마진
 하드코딩 색상 (Colors.*, Color(0xFF...))
 ChorokTypography 미사용 Text
 BorderRadius.circular() 직접 사용
 리스트에 Column 사용 (ListView.builder 대체 필요)
 버튼 터치 영역 < 48×48 또는 Semantics 누락
 Shimmer 대신 CircularProgressIndicator
 빈 상태 / 에러 상태 누락
 정적 위젯에 const 누락
 §13 안티패턴 재발

새로운 위반 유형 발견 시 — 반려와 동시에 DESIGN.md 갱신:

§13에 추가: | 날짜 | 위반 유형 | 잘못된 예 | 올바른 예 | 관련 섹션 |
§12 체크리스트 끝에 항목 추가
§15 버전 이력에 "Evaluator 자동 등록 — [요약]" 기록


공통 원칙

DESIGN.md 규칙은 추가 전용. 삭제·완화는 사용자 승인 필요.
갱신 후 확인: 기존 규칙과 충돌 없는지, §15에 기록됐는지, claude-progress.txt에 알림 남겼는지.
