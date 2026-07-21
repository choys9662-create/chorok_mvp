# Figma / 이미지 → Flutter 변환 규칙

- **Figma MCP:** Starter 플랜 월 6회 한도 — 호출 전 fileKey/nodeId 확인. `get_metadata`는 MCP 에러로 사용 불가 — `get_design_context`만 쓴다. 한도 초과 시 사용자에게 수동 복사(CSS 모든 레이어 + PNG) 요청.
- MCP 반환은 항상 React+Tailwind JSX — **중간 표현일 뿐이다.** 임의값 숫자(`left-[16px]`, `text-[14px]`)만 스펙으로 신뢰하고, 클래스·구조는 무시하고 Flutter 레이아웃으로 번역한다. React/HTML/CSS 코드 생성 금지.
- 구현 전: ① 프레임의 한국어 텍스트로 `lib/features/` grep — 이미 구현된 화면일 수 있다 ② 색상·크기는 design.md 규칙 + `AppTheme` 토큰으로 치환 ③ `shared/widgets` 재사용, 없을 때만 신설.
- 전체 화면을 `Stack`/`Positioned`로 짜지 않는다 (실제 겹침에만). 디바이스 고정 폭·높이 하드코딩 금지.
- `flutter analyze` 통과 ≠ 디자인 일치 — 색상 / 폰트 px / 정렬을 각각 따로 원본과 대조한다.
- 픽셀 매칭이 나쁜 Flutter 구조를 요구하면 트레이드오프를 설명하고 유지보수 가능한 쪽을 택한다.
